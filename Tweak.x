// Filename: CombinedExtractor_v2.0
// 版本：v2.0
// 更新：
// 1. 将“课体”和“九宗门”提取分为“带详解”和“不带详解”两种模式。
// 2. 内置全新UI解析逻辑，完美提取弹窗的顶部概要和底部详解。
// 3. 重新设计UI，提供四个功能按钮。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =================================================================
// 1. 全局变量与辅助函数
// =================================================================

// --- 状态控制 ---
static BOOL g_isExtracting = NO;            // 总开关，标记是否正在提取
static NSString *g_currentTaskType = nil;   // 标记当前任务类型 ("KeTi" 或 "JiuZongMen")
static BOOL g_extractWithDetails = NO;      // 新增！标记是否提取详解内容

// --- “课体”批量提取专用变量 ---
static NSMutableArray *g_keTi_workQueue = nil;
static NSMutableArray *g_keTi_resultsArray = nil;
static UICollectionView *g_keTi_targetCV = nil;

// --- UI ---
static UITextView *g_logView = nil;

// 辅助函数：递归查找子视图
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
        NSLog(@"[CombinedExtractor] %@", message);
    });
}


// =================================================================
// 2. 核心的Hook与队列处理逻辑
// =================================================================

static void processKeTiWorkQueue(void); 

// Hook：拦截弹窗事件 (v2.0 全新版本)
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    Class targetClass = NSClassFromString(@"六壬大占.課體概覽視圖");
    
    // 只在我们的提取任务执行时，才拦截目标窗口
    if (g_isExtracting && targetClass && [vcToPresent isKindOfClass:targetClass]) {
        vcToPresent.view.alpha = 0.0f; animated = NO;
        
        void (^extractionCompletion)(void) = ^{
            if (completion) { completion(); }

            // --- v2.0 全新提取逻辑 (基于UI层级结构) ---
            UIView *contentView = vcToPresent.view;
            NSMutableString *finalExtractedString = [NSMutableString string];

            // Part 1: 提取顶部的概要信息 (所有模式都需要)
            Class tableViewClass = NSClassFromString(@"六壬大占.IntrinsicTableView");
            NSMutableArray *stackViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UIStackView class], contentView, stackViews);

            if (stackViews.count > 0) {
                UIStackView *mainStackView = stackViews.firstObject;
                for (UIView *subview in mainStackView.arrangedSubviews) {
                    if (tableViewClass && [subview isKindOfClass:tableViewClass]) { break; }
                    if ([subview isKindOfClass:[UILabel class]]) {
                        NSString *text = ((UILabel *)subview).text;
                        if (text && text.length > 0) { [finalExtractedString appendFormat:@"%@\n", text]; }
                    }
                }
            }

            // Part 2: 如果是“带详解版”，则继续提取底部的 "详解" 列表
            if (g_extractWithDetails) {
                 if (finalExtractedString.length > 0) { [finalExtractedString appendString:@"\n--------------------\n\n"]; }

                 Class cellClass = NSClassFromString(@"六壬大占.課體詳解單元");
                 if (tableViewClass && cellClass) {
                     NSMutableArray *tableViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(tableViewClass, contentView, tableViews);
                     if (tableViews.count > 0) {
                         UIView *theTableView = tableViews.firstObject;
                         NSMutableArray *detailCells = [NSMutableArray array]; FindSubviewsOfClassRecursive(cellClass, theTableView, detailCells);
                         [detailCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
                         
                         for (UIView *cell in detailCells) {
                             NSMutableArray *labelsInCell = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], cell, labelsInCell);
                             [labelsInCell sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) { if(roundf(l1.frame.origin.y)<roundf(l2.frame.origin.y)) return NSOrderedAscending; if(roundf(l1.frame.origin.y)>roundf(l2.frame.origin.y)) return NSOrderedDescending; return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)]; }];
                             
                             if (labelsInCell.count >= 2) {
                                 NSString *title = ((UILabel *)labelsInCell[0]).text ?: @"";
                                 NSString *content = ((UILabel *)labelsInCell[1]).text ?: @"";
                                 if ([title hasSuffix:@"："]) { title = [title substringToIndex:title.length - 1]; }
                                 [finalExtractedString appendFormat:@"%@→%@\n", [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                             }
                         }
                     }
                 }
            }
            
            NSString *extractedText = [finalExtractedString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            // --- 后续处理逻辑 ---
            if ([g_currentTaskType isEqualToString:@"KeTi"]) {
                [g_keTi_resultsArray addObject:extractedText];
                LogMessage(@"成功提取“课体”第 %lu 项...", (unsigned long)g_keTi_resultsArray.count);
                [vcToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        processKeTiWorkQueue();
                    });
                }];
            } else if ([g_currentTaskType isEqualToString:@"JiuZongMen"]) {
                LogMessage(@"成功提取“九宗门”详情！");
                [UIPasteboard generalPasteboard].string = extractedText;
                LogMessage(@"内容已复制到剪贴板！");
                g_isExtracting = NO; g_currentTaskType = nil; g_extractWithDetails = NO;
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
            [finalResult appendFormat:@"--- 课体第 %lu 项详情 ---\n", (unsigned long)i + 1];
            [finalResult appendString:g_keTi_resultsArray[i]];
            [finalResult appendString:@"\n\n"];
        }
        [UIPasteboard generalPasteboard].string = finalResult;
        LogMessage(@"“课体”批量提取完成，所有内容已合并并复制！");
        
        g_isExtracting = NO; g_currentTaskType = nil; g_extractWithDetails = NO;
        g_keTi_targetCV = nil; g_keTi_workQueue = nil; g_keTi_resultsArray = nil;
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
// 3. UI 和控制逻辑 (v2.0)
// =================================================================

@interface UIViewController (CombinedExtractor)
- (void)setupCombinedExtractorPanel;
- (void)startKeTiWithDetails;
- (void)startKeTiWithoutDetails;
- (void)startJiuZongMenWithDetails;
- (void)startJiuZongMenWithoutDetails;
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

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 350, 520)];
    panel.tag = 889900;
    panel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.92];
    panel.layer.cornerRadius = 12;
    panel.layer.borderColor = [UIColor systemRedColor].CGColor;
    panel.layer.borderWidth = 1.5;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 350, 20)];
    titleLabel.text = @"大六壬终极提取器 v2.0";
    titleLabel.textColor = [UIColor systemRedColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:titleLabel];

    // --- 创建四个按钮 ---
    CGFloat buttonY = 50.0;
    CGFloat buttonHeight = 44.0;
    CGFloat buttonSpacing = 10.0;

    // 按钮1：课体提取 (带详解)
    UIButton *keTiDetailButton = [UIButton buttonWithType:UIButtonTypeSystem];
    keTiDetailButton.frame = CGRectMake(20, buttonY, panel.bounds.size.width - 40, buttonHeight);
    [keTiDetailButton setTitle:@"提取全部课体 (带详解版)" forState:UIControlStateNormal];
    [keTiDetailButton addTarget:self action:@selector(startKeTiWithDetails) forControlEvents:UIControlEventTouchUpInside];
    keTiDetailButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.2 alpha:1.0]; // 深绿
    [panel addSubview:keTiDetailButton];
    buttonY += buttonHeight + buttonSpacing;

    // 按钮2：课体提取 (不带详解)
    UIButton *keTiSimpleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    keTiSimpleButton.frame = CGRectMake(20, buttonY, panel.bounds.size.width - 40, buttonHeight);
    [keTiSimpleButton setTitle:@"提取全部课体 (仅概要)" forState:UIControlStateNormal];
    [keTiSimpleButton addTarget:self action:@selector(startKeTiWithoutDetails) forControlEvents:UIControlEventTouchUpInside];
    keTiSimpleButton.backgroundColor = [UIColor colorWithRed:0.6 green:0.8 blue:0.6 alpha:1.0]; // 浅绿
    [panel addSubview:keTiSimpleButton];
    buttonY += buttonHeight + buttonSpacing + 15; // 增加一组间距

    // 按钮3：九宗门提取 (带详解)
    UIButton *jzmDetailButton = [UIButton buttonWithType:UIButtonTypeSystem];
    jzmDetailButton.frame = CGRectMake(20, buttonY, panel.bounds.size.width - 40, buttonHeight);
    [jzmDetailButton setTitle:@"提取九宗门 (带详解版)" forState:UIControlStateNormal];
    [jzmDetailButton addTarget:self action:@selector(startJiuZongMenWithDetails) forControlEvents:UIControlEventTouchUpInside];
    jzmDetailButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.4 blue:0.7 alpha:1.0]; // 深蓝
    [panel addSubview:jzmDetailButton];
    buttonY += buttonHeight + buttonSpacing;

    // 按钮4：九宗门提取 (不带详解)
    UIButton *jzmSimpleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    jzmSimpleButton.frame = CGRectMake(20, buttonY, panel.bounds.size.width - 40, buttonHeight);
    [jzmSimpleButton setTitle:@"提取九宗门 (仅概要)" forState:UIControlStateNormal];
    [jzmSimpleButton addTarget:self action:@selector(startJiuZongMenWithoutDetails) forControlEvents:UIControlEventTouchUpInside];
    jzmSimpleButton.backgroundColor = [UIColor colorWithRed:0.5 green:0.7 blue:0.9 alpha:1.0]; // 浅蓝
    [panel addSubview:jzmSimpleButton];
    buttonY += buttonHeight + buttonSpacing;

    // 统一设置按钮样式
    for (UIButton *btn in @[keTiDetailButton, keTiSimpleButton, jzmDetailButton, jzmSimpleButton]) {
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        btn.layer.cornerRadius = 8;
    }

    // --- 日志视图 ---
    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, buttonY, panel.bounds.size.width - 20, panel.bounds.size.height - buttonY - 10)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor whiteColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = NO;
    g_logView.layer.cornerRadius = 5;
    g_logView.text = @"终极提取器 v2.0 已就绪。";
    [panel addSubview:g_logView];
    
    // --- 拖动手势 ---
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [panel addGestureRecognizer:pan];

    [keyWindow addSubview:panel];
}

// --- 四个按钮的实现 ---
%new
- (void)startKeTiWithDetails {
    [self startKeTiExtractionIsDetailed:YES];
}

%new
- (void)startKeTiWithoutDetails {
    [self startKeTiExtractionIsDetailed:NO];
}

// 内部函数，处理课体提取
%new
- (void)startKeTiExtractionIsDetailed:(BOOL)isDetailed {
    if (g_isExtracting) { LogMessage(@"错误：已有任务在进行中。"); return; }
    
    LogMessage(@"--- 开始“课体”批量提取 (%@) ---", isDetailed ? @"带详解" : @"仅概要");

    UIWindow *keyWindow = self.view.window; if (!keyWindow) { LogMessage(@"错误: 找不到主窗口。"); return; }
    
    g_keTi_targetCV = nil;
    Class keTiCellClass = NSClassFromString(@"六壬大占.課體單元");
    if (!keTiCellClass) { LogMessage(@"错误: 找不到 '六壬大占.課體單元' 类。"); return; }
    
    NSMutableArray<UICollectionView *> *allCVs = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], keyWindow, allCVs);
    for (UICollectionView *cv in allCVs) {
        if ([cv.visibleCells.firstObject isKindOfClass:keTiCellClass]) {
            g_keTi_targetCV = cv; break;
        }
    }

    if (!g_keTi_targetCV) { LogMessage(@"错误: 找不到包含“课体”的UICollectionView。"); return; }
    
    g_isExtracting = YES;
    g_currentTaskType = @"KeTi";
    g_extractWithDetails = isDetailed;
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
}

%new
- (void)startJiuZongMenWithDetails {
    [self startJiuZongMenExtractionIsDetailed:YES];
}

%new
- (void)startJiuZongMenWithoutDetails {
    [self startJiuZongMenExtractionIsDetailed:NO];
}

// 内部函数，处理九宗门提取
%new
- (void)startJiuZongMenExtractionIsDetailed:(BOOL)isDetailed {
    if (g_isExtracting) { LogMessage(@"错误：已有任务在进行中。"); return; }

    LogMessage(@"--- 开始“九宗门”提取任务 (%@) ---", isDetailed ? @"带详解" : @"仅概要");
    g_isExtracting = YES;
    g_currentTaskType = @"JiuZongMen";
    g_extractWithDetails = isDetailed;

    SEL selector = NSSelectorFromString(@"顯示九宗門概覽");
    if ([self respondsToSelector:selector]) {
        LogMessage(@"正在调用方法: 顯示九宗門概覽");
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:selector];
        #pragma clang diagnostic pop
    } else {
        LogMessage(@"错误: 当前ViewController没有'顯示九宗門概覽'方法。");
        g_isExtracting = NO; g_currentTaskType = nil; g_extractWithDetails = NO;
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
        Class vcClass = [UIViewController class]; // Hook a more general class to be safe
        if (vcClass) {
            MSHookMessageEx(vcClass, @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
            NSLog(@"[CombinedExtractor] 终极提取器 v2.0 已准备就绪。");
        }
    }
}

