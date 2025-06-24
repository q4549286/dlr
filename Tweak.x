#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 宏定义、全局变量与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog(@"[KeChuan-Test-Truth-V4-DirectCall] " format, ##__VA_ARGS__)

static NSInteger const TestButtonTag = 556690;
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_keChuanWorkQueue = nil;
static NSMutableArray *g_keChuanTitleQueue = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 自定义“假手势”类，用于精确控制点击位置
// =========================================================================
@interface FakeTapGestureRecognizer : UITapGestureRecognizer
@property (nonatomic, assign) CGPoint fakeLocation;
@property (nonatomic, weak) UIView *targetView;
@end

@implementation FakeTapGestureRecognizer
- (CGPoint)locationInView:(UIView *)view {
    // 无论外部调用者是谁，我们都返回相对于我们目标视图的预设位置
    // 这确保了目标方法能正确计算出点击落点
    if (self.targetView) {
        return [self.targetView convertPoint:self.fakeLocation fromView:nil];
    }
    return self.fakeLocation;
}
@end


// =========================================================================
// 3. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)performKeChuanDetailExtractionTest_Truth;
- (void)processKeChuanQueue_Truth;
@end

%hook UIViewController

// --- viewDidLoad 保持不变 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            if ([keyWindow viewWithTag:TestButtonTag]) { [[keyWindow viewWithTag:TestButtonTag] removeFromSuperview]; }
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"测试课传(终极版)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemGreenColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// --- presentViewController: 保持稳定版本 ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            viewControllerToPresent.view.alpha = 0.0f;
            flag = NO;
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) { [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; }
                }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    [self processKeChuanQueue_Truth];
                }];
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

// --- 【核心重构】performKeChuan... 现在存储 ChuanView 实例和点击位置 ---
%new
- (void)performKeChuanDetailExtractionTest_Truth {
    EchoLog(@"开始执行 [课传详情] 终极版测试");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
    
    UIWindow *keyWindow = self.view.window;
    if (!keyWindow) {
        EchoLog(@"错误：无法获取到 keyWindow，测试中止。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }

    // --- Part A: 三传解析（核心变更） ---
    Class chuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (chuanViewClass) {
        NSMutableArray *allChuanViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(chuanViewClass, self.view, allChuanViews);
        [allChuanViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
            return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)];
        }];
        
        NSArray *rowTitles = @[@"初传", @"中传", @"末传"];
        for (NSUInteger i = 0; i < allChuanViews.count; i++) {
            if (i >= rowTitles.count) break;
            
            UIView *chuanView = allChuanViews[i]; // 这是我们要直接操作的对象
            
            NSMutableArray *labels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
            [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
            }];
            
            if (labels.count >= 2) {
                UILabel *dizhiLabel = labels[labels.count - 2];
                UILabel *tianjiangLabel = labels[labels.count - 1];
                
                // 【新策略】我们存储 ChuanView 实例和 Label 的中心点（相对于 ChuanView）
                CGPoint dizhiPointInChuanView = dizhiLabel.center;
                CGPoint tianjiangPointInChuanView = tianjiangLabel.center;

                // 我们不再需要全局坐标，只需要 ChuanView 实例和它内部的相对坐标
                [g_keChuanWorkQueue addObject:@{
                    @"targetView": chuanView,
                    @"point": [NSValue valueWithCGPoint:dizhiPointInChuanView],
                    @"type": @"dizhi" // 保留类型用于日志
                }];
                [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                
                [g_keChuanWorkQueue addObject:@{
                    @"targetView": chuanView,
                    @"point": [NSValue valueWithCGPoint:tianjiangPointInChuanView],
                    @"type": @"tianjiang"
                }];
                [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
            }
        }
    } else {
        EchoLog(@"警告: 找不到 '六壬大占.傳視圖' 类");
    }

    // --- Part B: 四课解析逻辑 (这个逻辑之前是稳定的，暂时保持原样) ---
    // 为了简化，我们可以先只测试三传。如果三传成功，再把四课也改成新模式。
    // 如果需要，这里也应该改成直接操作 `四課視圖` 的模式。
    
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"测试失败: 未找到任何可点击的三传项目。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    
    [self processKeChuanQueue_Truth];
}

%new
// --- 【核心重构】队列处理器现在直接调用目标视图的方法 ---
- (void)processKeChuanQueue_Truth {
    if (g_keChuanWorkQueue.count == 0) {
        // ... (结束逻辑保持不变)
        EchoLog(@"[课传详情] 测试处理完毕");
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"终极版测试完成" message:@"所有详情已提取并复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
        g_isExtractingKeChuanDetail = NO;
        g_keChuanWorkQueue = nil; g_capturedKeChuanDetailArray = nil; g_keChuanTitleQueue = nil;
        return;
    }

    NSDictionary *task = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    UIView *targetView = task[@"targetView"];
    CGPoint pointInTargetView = [task[@"point"] CGPointValue];
    NSString *taskType = task[@"type"];

    // 尝试找到目标视图上的手势识别器并触发它
    // 常见的方法名有 tap, handleTap, viewTapped, didTapView 等
    SEL actionToPerform = NSSelectorFromString(@"tapped:"); // 这是一个常见的名字，需要猜测或通过反编译确认
    if (![targetView respondsToSelector:actionToPerform]) {
         actionToPerform = NSSelectorFromString(@"handleTap:"); // 另一个猜测
    }
     if (![targetView respondsToSelector:actionToPerform]) {
         actionToPerform = NSSelectorFromString(@"didTap:"); // 另一个猜测
    }
    // ... 可以继续添加猜测

    if ([targetView respondsToSelector:actionToPerform]) {
        EchoLog(@"正在对 %@ (%@) 执行直接调用: %@", NSStringFromClass([targetView class]), g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count], NSStringFromSelector(actionToPerform));
        
        // 创建一个“假手势”
        FakeTapGestureRecognizer *fakeTap = [[FakeTapGestureRecognizer alloc] init];
        fakeTap.targetView = targetView;
        // 把全局坐标转换成相对于目标视图的坐标
        UIWindow *keyWindow = self.view.window;
        CGPoint globalPoint = [targetView.superview convertPoint:targetView.frame.origin toView:keyWindow];
        globalPoint.x += pointInTargetView.x;
        globalPoint.y += pointInTargetView.y;
        fakeTap.fakeLocation = globalPoint;


        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [targetView performSelector:actionToPerform withObject:fakeTap];
        #pragma clang diagnostic pop

    } else {
        EchoLog(@"!!! 致命错误: 在 %@ 上找不到任何已知的手势处理方法。任务类型: %@", NSStringFromClass([targetView class]), taskType);
        // 即使失败，也要继续队列，防止卡住
        [self processKeChuanQueue_Truth];
    }
}
%end
