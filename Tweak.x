#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量、常量与辅助函数
// =========================================================================
#pragma mark - Globals & Constants
static const NSInteger kEchoExtractorButtonTag = 777888;
static BOOL g_isExtractingTianDiPanDetails = NO;
static NSMutableArray *g_tianDiPanWorkQueue = nil;
static NSMutableDictionary *g_tianDiPanResults = nil;
static void (^g_tianDiPanCompletionHandler)(NSDictionary *) = nil;
static CGPoint g_mockTouchLocation; // 用于存储伪造的点击位置

#pragma mark - Helper Functions
// GetIvarValueSafely 和 GetStringFromLayer 保持不变
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) { /* ... 保持原样 ... */ }
static NSString *GetStringFromLayer(id layer) { /* ... 保持原样 ... */ }

// Fake Gesture Recognizer and Swizzling
@interface MockTapGestureRecognizer : UITapGestureRecognizer @end
@implementation MockTapGestureRecognizer
// 我们将要 swizzle 这个方法
- (CGPoint)locationInView:(UIView *)view {
    return g_mockTouchLocation;
}
@end

// =========================================================================
// 2. 核心 Hook (presentViewController)
// =========================================================================
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));

static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    if (g_isExtractingTianDiPanDetails) {
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
        // 根据你之前的经验，弹窗的类名可能是 "課傳摘要視圖" 或类似的
        if ([vcClassName containsString:@"摘要視圖"]) {
            NSLog(@"[Extractor] 成功拦截到天地盘详情弹窗: %@", vcClassName);
            
            // 延迟执行以确保视图加载完成
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                // --- 在这里添加你的弹窗内容提取逻辑 ---
                // 复用你之前写好的课传流注提取逻辑
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                NSMutableArray *labels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], vcToPresent.view, labels);
                for (UILabel *label in labels) {
                    if (label.text.length > 0) {
                        [textParts addObject:label.text];
                    }
                }
                NSString *extractedText = [textParts componentsJoinedByString:@"\n"];
                // --- 提取逻辑结束 ---

                if (g_tianDiPanWorkQueue.count > 0) {
                    NSString *currentTaskKey = g_tianDiPanWorkQueue.firstObject[@"key"];
                    g_tianDiPanResults[currentTaskKey] = extractedText;
                    NSLog(@"[Extractor] 任务 '%@' 数据提取成功。", currentTaskKey);
                }

                // 立即关闭弹窗，并继续下一个任务
                [vcToPresent dismissViewControllerAnimated:NO completion:^{
                    if ([self respondsToSelector:@selector(processTianDiPanQueue)]) {
                        [self performSelector:@selector(processTianDiPanQueue)];
                    }
                }];
            });
            // 阻止原始的 present 调用，避免动画
            return;
        }
    }
    // 如果不是我们想要的弹窗，就执行原始逻辑
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}


// =========================================================================
// 3. UIViewController 扩展
// =========================================================================
@interface UIViewController (EchoExtractor)
- (void)startTianDiPanExtraction;
- (void)processTianDiPanQueue;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([self.view.window viewWithTag:kEchoExtractorButtonTag]) return;
            UIButton *extractorButton = [UIButton buttonWithType:UIButtonTypeSystem];
            extractorButton.frame = CGRectMake(10, 45, 160, 36);
            extractorButton.tag = kEchoExtractorButtonTag;
            [extractorButton setTitle:@"提取天地盘详情" forState:UIControlStateNormal];
            extractorButton.backgroundColor = [UIColor systemGreenColor];
            [extractorButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            extractorButton.layer.cornerRadius = 18;
            [extractorButton addTarget:self action:@selector(startTianDiPanExtraction) forControlEvents:UIControlEventTouchUpInside];
            [self.view.window addSubview:extractorButton];
        });
    }
}

%new
- (void)startTianDiPanExtraction {
    if (g_isExtractingTianDiPanDetails) {
        NSLog(@"[Extractor] 提取任务已在进行中。");
        return;
    }
    
    g_isExtractingTianDiPanDetails = YES;
    g_tianDiPanWorkQueue = [NSMutableArray array];
    g_tianDiPanResults = [NSMutableDictionary dictionary];
    g_tianDiPanCompletionHandler = ^(NSDictionary *results){
        // 在这里处理最终的所有结果
        NSMutableString *finalReport = [NSMutableString string];
        [finalReport appendString:@"// ====== 天地盘宫位详情 ======\n\n"];
        for (NSString *key in [results.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            [finalReport appendFormat:@"--- %@ ---\n%@\n\n", key, results[key]];
        }
        
        // 复制到剪贴板
        [UIPasteboard generalPasteboard].string = finalReport;
        NSLog(@"[Extractor] 全部完成！结果已复制到剪贴板。");
        
        // 清理状态
        g_isExtractingTianDiPanDetails = NO;
        g_tianDiPanWorkQueue = nil;
        g_tianDiPanResults = nil;
        g_tianDiPanCompletionHandler = nil;
    };

    NSLog(@"[Extractor] 开始提取天地盘详情...");

    // 1. 定位天地盘视图
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    __block UIView *plateView = nil;
    // ... (此处省略和诊断脚本里一样的视图查找逻辑)
    // 假设已经找到了 plateView
    
    // 2. 读取包含 CALayer 的字典
    NSDictionary *diGongDict = GetIvarValueSafely(plateView, @"地宮宮名列");
    NSDictionary *tianShenDict = GetIvarValueSafely(plateView, @"天神宮名列");
    NSDictionary *tianJiangDict = GetIvarValueSafely(plateView, @"天將宮名列");
    
    if (!diGongDict || !tianShenDict || !tianJiangDict) {
        NSLog(@"[Extractor] CRITICAL: 无法读取核心数据字典。");
        g_isExtractingTianDiPanDetails = NO;
        return;
    }

    // 3. 构建任务队列
    // 我们假设这三个字典的 key 是相同的 (例如地支名)
    for (NSString *key in diGongDict.allKeys) {
        CALayer *diGongLayer = diGongDict[key];
        CALayer *tianShenLayer = tianShenDict[key];
        CALayer *tianJiangLayer = tianJiangDict[key];

        // 我们需要点击天神 (天盘地支)
        if (tianShenLayer) {
            // 计算 layer 在其父视图中的中心点
            CGPoint centerPoint = CGPointMake(CGRectGetMidX(tianShenLayer.frame), CGRectGetMidY(tianShenLayer.frame));
            
            NSString *taskKey = [NSString stringWithFormat:@"%@宫-%@(%@)", GetStringFromLayer(diGongLayer), GetStringFromLayer(tianShenLayer), GetStringFromLayer(tianJiangLayer)];

            [g_tianDiPanWorkQueue addObject:@{
                @"key": taskKey,
                @"location": [NSValue valueWithCGPoint:centerPoint]
            }];
        }
    }
    
    NSLog(@"[Extractor] 任务队列构建完成，共 %lu 项。", (unsigned long)g_tianDiPanWorkQueue.count);

    // 4. 开始处理队列
    [self processTianDiPanQueue];
}

%new
- (void)processTianDiPanQueue {
    if (!g_isExtractingTianDiPanDetails || g_tianDiPanWorkQueue.count == 0) {
        if (g_tianDiPanCompletionHandler) {
            g_tianDiPanCompletionHandler(g_tianDiPanResults);
        }
        return;
    }

    NSDictionary *task = g_tianDiPanWorkQueue.firstObject;
    // [g_tianDiPanWorkQueue removeObjectAtIndex:0]; // 暂时不移除，等成功后再移除

    NSLog(@"[Extractor] 正在处理任务: %@", task[@"key"]);

    // 1. 找到天地盘视图实例
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    // ... (再次执行视图查找逻辑)
    // 假设已找到 plateView

    if (!plateView) {
        NSLog(@"[Extractor] CRITICAL: 在处理队列时找不到天地盘视图。");
        g_isExtractingTianDiPanDetails = NO;
        return;
    }

    // 2. 准备伪造手势
    SEL actionSelector = NSSelectorFromString(@"處理點擊WithSender:");
    if (![plateView respondsToSelector:actionSelector]) {
        NSLog(@"[Extractor] CRITICAL: 视图不响应 '處理點擊WithSender:' 方法。");
        g_isExtractingTianDiPanDetails = NO;
        return;
    }

    g_mockTouchLocation = [task[@"location"] CGPointValue];
    
    // 3. 创建并执行
    // 注意：这里我们直接创建一个 MockTapGestureRecognizer 的实例
    MockTapGestureRecognizer *mockGesture = [[MockTapGestureRecognizer alloc] init];

    // 因为 locationInView: 已经被我们重写，所以 App 调用它时会得到我们设置的 g_mockTouchLocation
    
    // 【核心】调用方法
    // 使用 NSInvocation 来安全地调用，避免编译器警告
    NSMethodSignature *signature = [plateView methodSignatureForSelector:actionSelector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:plateView];
    [invocation setSelector:actionSelector];
    [invocation setArgument:&mockGesture atIndex:2]; // 参数从 index 2 开始
    [invocation invoke];
    
    // 从队列中移除已处理的任务
    [g_tianDiPanWorkQueue removeObjectAtIndex:0];
}

%end

// =========================================================================
// 4. 初始化
// =========================================================================
%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[EchoTianDiPanExtractor] 天地盘详情提取器已加载。");
    }
}
