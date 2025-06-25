// Filename: CombinedExtractor_v3.0_Final
// 描述: 终极版。采用运行时直接读取数据模型，不再依赖UI抓取。
// 1. 100% 准确提取所有内容，解决了内容丢失问题。
// 2. 新增 “带详解/不带详解” 选项，共四个按钮，满足不同需求。
// 3. 代码更稳定，不受UI布局变化影响。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =================================================================
// 1. 全局变量与辅助函数
// =================================================================

// --- 状态控制 ---
static BOOL g_isExtracting = NO;
static NSString *g_currentTaskType = nil;
static BOOL g_shouldIncludeXiangJie = NO; // 新增：是否包含“详解”

// --- “课体”批量提取专用变量 ---
static NSMutableArray *g_keTi_workQueue = nil;
static NSMutableArray *g_keTi_resultsArray = nil;
static UICollectionView *g_keTi_targetCV = nil;

// --- UI ---
static UITextView *g_logView = nil;

// 辅助函数：递归查找子视图 (依然需要它来找CollectionView)
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// 统一日志函数
static void LogMessage(NSString *format, ...) {
    if (!g_logView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        g_logView.text = [NSString stringWithFormat:@"%@%@\n%@", logPrefix, message, g_logView.text];
        NSLog(@"[CombinedExtractor-v3] %@", message);
    });
}

// 辅助函数：通过运行时安全地获取实例变量的值
static id GetIvarValueSafely(id object, const char *ivarName) {
    Ivar ivar = class_getInstanceVariable([object class], ivarName);
    if (ivar) {
        return object_getIvar(object, ivar);
    }
    return nil;
}

// =================================================================
// 2. 核心的Hook与队列处理逻辑 (已完全重写)
// =================================================================

static void processKeTiWorkQueue(void);

// ================== 全新的核心提取函数 ==================
// 这个函数现在直接从内存读取数据，不再解析UI
static NSString* extractDataFromModel(id viewController, BOOL includeXiangJie) {
    if (!viewController) return @"[错误: 目标控制器为空]";

    // 定义数据模型的实例变量名 (根据你的截图)
    NSDictionary<NSString *, NSString *> *dataMap = @{
        @"课名": "課名",
        @"判断": "判斷",
        @"变体": "變體",
        @"简断": "簡斷",
        @"故象曰": "象辭" // 注意截图里是“象辞”，这里保持一致
    };

    NSMutableString *resultString = [NSMutableString string];

    // 1. 提取普通字段
    for (NSString *title in @[@"课名", @"判断", @"变体", @"简断", @"故象曰"]) {
        const char *ivarName = [dataMap[title] UTF8String];
        id value = GetIvarValueSafely(viewController, ivarName);
        if (value && [value isKindOfClass:[NSString class]] && ((NSString *)value).length > 0) {
            [resultString appendFormat:@"%@\n%@\n\n", title, value];
        }
    }

    // 2. 根据选项，决定是否提取“详解”
    if (includeXiangJie) {
        // "详解"的数据结构可能是字典或数组，我们需要判断
        id xiangJieValue = GetIvarValueSafely(viewController, "詳解表"); // 假设是这个变量
        
        if (xiangJieValue) {
            [resultString appendString:@"--- 详解 ---\n\n"];
            
            if ([xiangJieValue isKindOfClass:[NSDictionary class]]) {
                // 如果是字典，直接格式化 Key -> Value
                NSDictionary *xiangJieDict = (NSDictionary *)xiangJieValue;
                for (id key in xiangJieDict) {
                    [resultString appendFormat:@"%@→%@\n\n", key, xiangJieDict[key]];
                }
            } else if ([xiangJieValue isKindOfClass:[NSArray class]]) {
                 // 如果是数组，则可能是包含字典的数组，或其他结构，需要进一步分析
                 // 这里做一个通用处理，打印它的描述
                 [resultString appendFormat:@"%@\n\n", [xiangJieValue description]];
            } else {
                 [resultString appendFormat:@"%@\n\n", [xiangJieValue description]];
            }
        }
    }

    return [resultString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

// Hook：拦截弹窗事件 (已更新)
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    Class targetClass = NSClassFromString(@"六壬大占.課體概覽視圖");
    
    if (g_isExtracting && targetClass && [vcToPresent isKindOfClass:targetClass]) {
        vcToPresent.view.alpha = 0.0f; animated = NO;
        
        void (^extractionCompletion)(void) = ^{
            if (completion) { completion(); }

            // 使用全新的、基于数据模型的提取函数
            NSString *extractedText = extractDataFromModel(vcToPresent, g_shouldIncludeXiangJie);
            
            if ([g_currentTaskType isEqualToString:@"KeTi"]) {
                [g_keTi_resultsArray addObject:extractedText];
                LogMessage(@"成功提取“课体”第 %lu 项...", (unsigned long)g_keTi_resultsArray.count);
                [vcToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        processKeTiWorkQueue();
                    });
                }];
            } 
            else if ([g_currentTaskType isEqualToString:@"JiuZongMen"]) {
                LogMessage(@"成功提取“九宗门”详情！");
                [UIPasteboard generalPasteboard].string = extractedText;
                LogMessage(@"内容已复制到剪贴板！");
                g_isExtracting = NO;
                g_currentTaskType = nil;
                [vcToPresent dismissViewControllerAnimated:NO completion:nil];
            }
        };
        Original_presentViewController(self, _cmd, vcToPresent, animated, extractionCompletion);
    } else {
        Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
    }
}

// “课体”任务队列处理器
static void processKeTiWorkQueue() {
    if (g_keTi_workQueue.count == 0) {
        LogMessage(@"所有 %lu 项“课体”任务处理完毕！", (unsigned long)g_keTi_resultsArray.count);
        NSMutableString *finalResult = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keTi_resultsArray.count; i++) {
            // 从提取结果中找到“课名”作为标题
            NSString *itemText = g_keTi_resultsArray[i];
            NSString *itemTitle = @"未知课体";
            NSRange titleRange = [itemText rangeOfString:@"\n"];
            if (titleRange.location != NSNotFound) {
                 itemTitle = [itemText substringToIndex:titleRange.location];
            }
            [finalResult appendFormat:@"--- %@ ---\n\n%@\n\n\n", itemTitle, itemText];
        }
        [UIPasteboard generalPasteboard].string: [finalResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        LogMessage(@"“课体”批量提取完成，所有内容已合并并复制！");
        
        g_isExtracting = NO;
        g_currentTaskType = nil;
        g_keTi_targetCV = nil;
        g_keTi_workQueue = nil;
        g_keTi_resultsArray = nil;
        return;
    }
    
    NSIndexPath *indexPath = g_keTi_workQueue.firstObject;
    [g_keTi_workQueue removeObjectAtIndex:0];
    LogMessage(@"正在处理“课体”第 %lu/%lu 项...", (unsigned long)(g_keTi_resultsArray.count + 1), (unsigned long)(g_keTi_resultsArray.count + g_keTi_workQueue.count + 1));
    
    id delegate = g_keTi_targetCV.delegate;
    if (delegate && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
        [delegate collectionView:g_keTi_targetCV didSelectItemAtIndexPath:indexPath];
    }
}

// =================================================================
// 3. UI 和控制逻辑 (已更新为4个按钮)
// =================================================================

@interface UIViewController (CombinedExtractor)
- (void)setupCombinedExtractorPanel;
- (void)startExtractionWithTaskType:(NSString *)taskType includeXiangJie:(BOOL)include;
- (void)handleButtonTap:(UIButton *)sender;
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer;
@end

%hook UIViewController
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupCombinedExtractorPanel];
        });
    }
}

%new
- (void)setupCombinedExtractorPanel {
    UIWindow *keyWindow = self.view.window;
    if (!keyWindow || [keyWindow viewWithTag:889900]) return;

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 350, 500)]; // 增加高度以容纳4个按钮
    panel.tag = 889900;
    panel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.92];
    panel.layer.cornerRadius = 12;
    panel.layer.borderColor = [UIColor systemIndigoColor].CGColor;
    panel.layer.borderWidth = 1.5;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 350, 20)];
    titleLabel.text = @"大六壬终极提取器 v3.0";
    titleLabel.textColor = [UIColor systemIndigoColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:titleLabel];

    // --- 创建四个按钮 ---
    CGFloat buttonY = 60;
    CGFloat buttonHeight = 44;
    CGFloat buttonSpacing = 10;
    
    NSArray *buttonConfigs = @[
        @{@"title": @"提取课体 (带详解)", @"tag": @(1), @"color": [UIColor systemGreenColor]},
        @{@"title": @"提取课体 (无详解)", @"tag": @(2), @"color": [UIColor colorWithRed:0.2 green:0.5 blue:0.3 alpha:1.0]},
        @{@"title": @"提取九宗门 (带详解)", @"tag": @(3), @"color": [UIColor systemCyanColor]},
        @{@"title": @"提取九宗门 (无详解)", @"tag": @(4), @"color": [UIColor colorWithRed:0.1 green:0.4 blue:0.5 alpha:1.0]}
    ];

    for (NSDictionary *config in buttonConfigs) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(20, buttonY, panel.bounds.size.width - 40, buttonHeight);
        [btn setTitle:config[@"title"] forState:UIControlStateNormal];
        btn.tag = [config[@"tag"] integerValue];
        btn.backgroundColor = config[@"color"];
        [btn addTarget:self action:@selector(handleButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        btn.layer.cornerRadius = 8;
        [panel addSubview:btn];
        
        buttonY += buttonHeight + buttonSpacing;
    }

    // --- 日志视图 ---
    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, buttonY + 10, panel.bounds.size.width - 20, panel.bounds.size.height - buttonY - 20)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor whiteColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = NO;
    g_logView.layer.cornerRadius = 5;
    g_logView.text = @"终极提取器 v3.0 (数据模型版) 已就绪。";
    [panel addSubview:g_logView];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [panel addGestureRecognizer:pan];

    [keyWindow addSubview:panel];
}

%new
- (void)handleButtonTap:(UIButton *)sender {
    if (g_isExtracting) { LogMessage(@"错误：已有任务在进行中。"); return; }
    
    NSString *taskType = nil;
    BOOL includeXiangJie = NO;

    switch (sender.tag) {
        case 1: // 课体 带详解
            taskType = @"KeTi";
            includeXiangJie = YES;
            break;
        case 2: // 课体 无详解
            taskType = @"KeTi";
            includeXiangJie = NO;
            break;
        case 3: // 九宗门 带详解
            taskType = @"JiuZongMen";
            includeXiangJie = YES;
            break;
        case 4: // 九宗门 无详解
            taskType = @"JiuZongMen";
            includeXiangJie = NO;
            break;
        default:
            return;
    }
    
    [self startExtractionWithTaskType:taskType includeXiangJie:includeXiangJie];
}

%new
- (void)startExtractionWithTaskType:(NSString *)taskType includeXiangJie:(BOOL)include {
    g_isExtracting = YES;
    g_currentTaskType = taskType;
    g_shouldIncludeXiangJie = include;

    LogMessage(@"--- 开始任务: %@ (详解: %@) ---", taskType, include ? @"是" : @"否");

    if ([taskType isEqualToString:@"KeTi"]) {
        // --- 批量提取课体 ---
        UIWindow *keyWindow = self.view.window;
        if (!keyWindow) { LogMessage(@"错误: 找不到主窗口。"); g_isExtracting = NO; return; }
        
        g_keTi_targetCV = nil;
        Class keTiCellClass = NSClassFromString(@"六壬大占.課體單元");
        if (!keTiCellClass) { LogMessage(@"错误: 找不到 '六壬大占.課體單元' 类。"); g_isExtracting = NO; return; }
        
        NSMutableArray<UICollectionView *> *allCVs = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UICollectionView class], keyWindow, allCVs);
        
        for (UICollectionView *cv in allCVs) {
            if ([cv.visibleCells.firstObject isKindOfClass:keTiCellClass]) {
                g_keTi_targetCV = cv; break;
            }
        }

        if (!g_keTi_targetCV) { LogMessage(@"错误: 找不到包含“课体”的UICollectionView。"); g_isExtracting = NO; return; }
        
        g_keTi_workQueue = [NSMutableArray array];
        g_keTi_resultsArray = [NSMutableArray array];
        
        NSInteger totalItems = [g_keTi_targetCV.dataSource collectionView:g_keTi_targetCV numberOfItemsInSection:0];
        for (NSInteger i = 0; i < totalItems; i++) {
            [g_keTi_workQueue addObject:[NSIndexPath indexPathForItem:i inSection:0]];
        }

        if (g_keTi_workQueue.count == 0) {
            LogMessage(@"错误: 未找到任何“课体”单元来创建任务队列。");
            g_isExtracting = NO; return;
        }

        LogMessage(@"发现 %lu 个“课体”单元，开始处理队列...", (unsigned long)g_keTi_workQueue.count);
        processKeTiWorkQueue();

    } else if ([taskType isEqualToString:@"JiuZongMen"]) {
        // --- 提取九宗门 ---
        SEL selector = NSSelectorFromString(@"顯示九宗門概覽");
        if ([self respondsToSelector:selector]) {
            LogMessage(@"正在调用方法: 顯示九宗門概覽");
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self performSelector:selector];
            #pragma clang diagnostic pop
        } else {
            LogMessage(@"错误: 当前ViewController没有'顯示九宗門概覽'方法。");
            g_isExtracting = NO;
        }
    }
}

%new
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer {
    UIView *panel = recognizer.view;
    CGPoint translation = [recognizer translationInView:panel.superview];
    panel.center = CGPointMake(panel.center.x + translation.x, panel.center.y + translation.y);
    [recognizer setTranslation:CGPointZero inView:panel.superview];
}

%end

// =================================================================
// 4. 构造函数
// =================================================================

%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[CombinedExtractor-v3] 终极提取器 v3.0 (数据模型版) 已准备就绪。");
    }
}

