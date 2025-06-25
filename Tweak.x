// CombinedExtractor_v2.0
// 终极版 v2.0！集成了“课体”和“九宗门”的四种提取模式。
// 新增智能行内文本配对逻辑，旨在解决内容错位问题。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =================================================================
// 1. 全局变量与辅助函数
// =================================================================

// --- 状态控制 ---
static BOOL g_isExtracting = NO;              // 总开关，标记是否正在提取
static NSString *g_currentTaskType = nil;     // 标记当前任务类型, e.g., "KeTi_WithDetails"

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
        NSLog(@"[CombinedExtractor_v2] %@", message);
    });
}


// =================================================================
// 2. 核心的Hook与队列处理逻辑
// =================================================================

static void processKeTiWorkQueue(void);

// 核心提取逻辑：对找到的UILabel进行智能配对
static NSString *extractPairedTextFromLabels(NSArray<UILabel *> *allLabels, BOOL withDetails) {
    if (allLabels.count == 0) return @"";

    // 1. 按纵坐标(y)为主，横坐标(x)为辅进行排序
    NSArray<UILabel *> *sortedLabels = [allLabels sortedArrayUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
        CGFloat y1 = roundf(o1.frame.origin.y);
        CGFloat y2 = roundf(o2.frame.origin.y);
        if (y1 < y2) return NSOrderedAscending;
        if (y1 > y2) return NSOrderedDescending;
        return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
    }];

    // 2. 将y坐标相近的Label分组，视为“同一行”
    NSMutableArray<NSMutableArray<UILabel *> *> *lines = [NSMutableArray array];
    if (sortedLabels.count > 0) {
        NSMutableArray<UILabel *> *currentLine = [NSMutableArray arrayWithObject:sortedLabels.firstObject];
        [lines addObject:currentLine];
        for (NSUInteger i = 1; i < sortedLabels.count; i++) {
            UILabel *prevLabel = sortedLabels[i-1];
            UILabel *currentLabel = sortedLabels[i];
            // y坐标差距小于5，就认为是同一行
            if (fabs(currentLabel.frame.origin.y - prevLabel.frame.origin.y) < 5.0) {
                [currentLine addObject:currentLabel];
            } else {
                currentLine = [NSMutableArray arrayWithObject:currentLabel];
                [lines addObject:currentLine];
            }
        }
    }

    // 3. 根据模式（带/不带详解）拼接最终结果
    NSMutableArray<NSString *> *textParts = [NSMutableArray array];
    for (NSMutableArray<UILabel *> *line in lines) {
        if (line.count == 0) continue;

        if (withDetails) {
            // 带详解模式：用 → 连接同一行的所有文本
            NSMutableArray *lineTexts = [NSMutableArray array];
            for (UILabel *label in line) {
                if (label.text.length > 0) [lineTexts addObject:label.text];
            }
            if (lineTexts.count > 0) {
                [textParts addObject:[lineTexts componentsJoinedByString:@" → "]];
            }
        } else {
            // 仅标题模式：只取每一行的第一个文本
            UILabel *firstLabel = line.firstObject;
            if (firstLabel.text.length > 0) {
                [textParts addObject:firstLabel.text];
            }
        }
    }
    
    return [textParts componentsJoinedByString:@"\n"];
}


// Hook：拦截弹窗事件
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    Class targetClass = NSClassFromString(@"六壬大占.課體概覽視圖");
    
    // 只在我们的提取任务执行时，才拦截目标窗口
    if (g_isExtracting && targetClass && [vcToPresent isKindOfClass:targetClass]) {
        vcToPresent.view.alpha = 0.0f; animated = NO;
        
        void (^extractionCompletion)(void) = ^{
            if (completion) { completion(); }

            // --- 提取逻辑 ---
            UIView *contentView = vcToPresent.view;
            NSMutableArray *allLabels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);

            BOOL withDetails = [g_currentTaskType containsString:@"WithDetails"];
            NSString *extractedText = extractPairedTextFromLabels(allLabels, withDetails);
            
            // --- 根据任务类型，决定如何处理提取到的文本 ---
            if ([g_currentTaskType hasPrefix:@"KeTi"]) {
                [g_keTi_resultsArray addObject:extractedText];
                LogMessage(@"成功提取“课体”第 %lu 项...", (unsigned long)g_keTi_resultsArray.count);
                [vcToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        processKeTiWorkQueue(); // 处理下一个课体
                    });
                }];
            } else if ([g_currentTaskType hasPrefix:@"JiuZongMen"]) {
                LogMessage(@"成功提取“九宗门”详情！");
                [UIPasteboard generalPasteboard].string = extractedText;
                LogMessage(@"内容已复制到剪贴板！");
                g_isExtracting = NO; // 单次任务完成，重置总开关
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
            [finalResult appendFormat:@"--- 课体第 %lu 项详情 ---\n", (unsigned long)i + 1];
            [finalResult appendString:g_keTi_resultsArray[i]];
            [finalResult appendString:@"\n\n"];
        }
        [UIPasteboard generalPasteboard].string = finalResult;
        LogMessage(@"“课体”批量提取完成，所有内容已合并并复制！");
        
        g_isExtracting = NO; // 整个批量任务完成
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
// 3. UI 和控制逻辑
// =================================================================

@interface UIViewController (CombinedExtractor)
- (void)setupCombinedExtractorPanel;
- (void)startExtraction:(UIButton *)sender;
- (void)startKeTiBatchExtraction;
- (void)startJiuZongMenSingleExtraction;
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

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 350, 480)];
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

    // --- 创建四个功能按钮 ---
    CGFloat buttonWidth = (panel.bounds.size.width - 60) / 2;
    CGFloat buttonHeight = 44;

    // 课体 (带详解)
    UIButton *b1 = [UIButton buttonWithType:UIButtonTypeSystem];
    b1.frame = CGRectMake(20, 60, buttonWidth, buttonHeight);
    [b1 setTitle:@"课体(带详解)" forState:UIControlStateNormal];
    b1.tag = 1; // KeTi_WithDetails
    b1.backgroundColor = [UIColor systemGreenColor];

    // 课体 (仅标题)
    UIButton *b2 = [UIButton buttonWithType:UIButtonTypeSystem];
    b2.frame = CGRectMake(20 + buttonWidth + 20, 60, buttonWidth, buttonHeight);
    [b2 setTitle:@"课体(仅标题)" forState:UIControlStateNormal];
    b2.tag = 2; // KeTi_NoDetails
    b2.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.2 alpha:1.0];
    
    // 九宗门 (带详解)
    UIButton *b3 = [UIButton buttonWithType:UIButtonTypeSystem];
    b3.frame = CGRectMake(20, 60 + buttonHeight + 15, buttonWidth, buttonHeight);
    [b3 setTitle:@"九宗门(带详解)" forState:UIControlStateNormal];
    b3.tag = 3; // JiuZongMen_WithDetails
    b3.backgroundColor = [UIColor systemCyanColor];

    // 九宗门 (仅标题)
    UIButton *b4 = [UIButton buttonWithType:UIButtonTypeSystem];
    b4.frame = CGRectMake(20 + buttonWidth + 20, 60 + buttonHeight + 15, buttonWidth, buttonHeight);
    [b4 setTitle:@"九宗门(仅标题)" forState:UIControlStateNormal];
    b4.tag = 4; // JiuZongMen_NoDetails
    b4.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.6 alpha:1.0];

    for (UIButton *btn in @[b1, b2, b3, b4]) {
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        btn.layer.cornerRadius = 8;
        [btn addTarget:self action:@selector(startExtraction:) forControlEvents:UIControlEventTouchUpInside];
        [panel addSubview:btn];
    }
    
    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 60 + buttonHeight * 2 + 30, panel.bounds.size.width - 20, panel.bounds.size.height - (60 + buttonHeight * 2 + 40))];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor whiteColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = NO;
    g_logView.layer.cornerRadius = 5;
    g_logView.text = @"v2.0 已就绪。请选择提取模式。";
    [panel addSubview:g_logView];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [panel addGestureRecognizer:pan];

    [keyWindow addSubview:panel];
}

%new
- (void)startExtraction:(UIButton *)sender {
    if (g_isExtracting) { LogMessage(@"错误：已有任务在进行中。"); return; }
    
    // 根据按钮的tag来设置任务类型
    switch (sender.tag) {
        case 1: g_currentTaskType = @"KeTi_WithDetails"; break;
        case 2: g_currentTaskType = @"KeTi_NoDetails"; break;
        case 3: g_currentTaskType = @"JiuZongMen_WithDetails"; break;
        case 4: g_currentTaskType = @"JiuZongMen_NoDetails"; break;
        default: return;
    }

    if ([g_currentTaskType hasPrefix:@"KeTi"]) {
        [self startKeTiBatchExtraction];
    } else if ([g_currentTaskType hasPrefix:@"JiuZongMen"]) {
        [self startJiuZongMenSingleExtraction];
    }
}

%new
- (void)startKeTiBatchExtraction {
    LogMessage(@"--- 开始“课体”批量提取 (%@) ---", [g_currentTaskType containsString:@"WithDetails"] ? @"带详解" : @"仅标题");

    UIWindow *keyWindow = self.view.window;
    if (!keyWindow) { LogMessage(@"错误: 找不到主窗口。"); return; }
    
    g_keTi_targetCV = nil;
    Class keTiCellClass = NSClassFromString(@"六壬大占.課體單元");
    if (!keTiCellClass) { LogMessage(@"错误: 找不到 '六壬大占.課體單元' 类。"); return; }
    
    NSMutableArray<UICollectionView *> *allCVs = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], keyWindow, allCVs);
    
    for (UICollectionView *cv in allCVs) {
        // 通过检查可见单元格来确认这是我们要找的列表
        for (UICollectionViewCell *cell in cv.visibleCells) {
             if ([cell isKindOfClass:keTiCellClass]) {
                 g_keTi_targetCV = cv; break;
             }
        }
        if (g_keTi_targetCV) { break; }
    }

    if (!g_keTi_targetCV) { LogMessage(@"错误: 找不到包含“课体”的UICollectionView。"); return; }
    
    g_isExtracting = YES;
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
- (void)startJiuZongMenSingleExtraction {
    LogMessage(@"--- 开始“九宗门”提取 (%@) ---", [g_currentTaskType containsString:@"WithDetails"] ? @"带详解" : @"仅标题");
    g_isExtracting = YES;

    SEL selector = NSSelectorFromString(@"顯示九宗門概覽");
    if ([self respondsToSelector:selector]) {
        LogMessage(@"正在调用方法: 顯示九宗門概覽");
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:selector];
        #pragma clang diagnostic pop
    } else {
        LogMessage(@"错误: 当前VC没有'顯示九宗門概覽'方法。");
        g_isExtracting = NO;
        g_currentTaskType = nil;
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
        Class vcClass = NSClassFromString(@"UIViewController"); // Hook a more general class
        if (vcClass) {
            MSHookMessageEx(vcClass, @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
            NSLog(@"[CombinedExtractor_v2] 终极提取器 v2.0 已准备就绪。");
        }
    }
}
