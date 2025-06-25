// Filename: KeTiMultiExtractor_v1.5
// 增加了窗口拖动功能，方便测试。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =================================================================
// 1. 全局变量与辅助函数
// =================================================================

static BOOL g_isMultiExtracting = NO;
static NSMutableArray *g_workQueue = nil;
static NSMutableArray *g_resultsArray = nil;
static UICollectionView *g_targetCollectionView = nil;
static UITextView *g_logView = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

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
        NSLog(@"[MultiExtractor] %@", message);
    });
}


// =================================================================
// 2. 核心的Hook与队列处理逻辑
// =================================================================

static void processWorkQueue(void); 

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    Class targetClass = NSClassFromString(@"六壬大占.課體概覽視圖");
    
    if (g_isMultiExtracting && targetClass && [vcToPresent isKindOfClass:targetClass]) {
        vcToPresent.view.alpha = 0.0f; animated = NO;
        
        void (^extractionCompletion)(void) = ^{
            if (completion) { completion(); }

            UIView *contentView = vcToPresent.view;
            NSMutableArray *allLabels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
            [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                if (roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                if (roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
            }];
            
            NSMutableArray<NSString *> *textParts = [NSMutableArray array];
            for (UILabel *label in allLabels) {
                if (label.text && label.text.length > 0) { [textParts addObject:label.text]; }
            }
            [g_resultsArray addObject:[textParts componentsJoinedByString:@"\n"]];
            LogMessage(@"成功提取第 %lu 项...", (unsigned long)g_resultsArray.count);
            
            [vcToPresent dismissViewControllerAnimated:NO completion:^{
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    processWorkQueue();
                });
            }];
        };
        Original_presentViewController(self, _cmd, vcToPresent, animated, extractionCompletion);
    } else {
        Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
    }
}

static void processWorkQueue() {
    if (g_workQueue.count == 0) {
        LogMessage(@"所有 %lu 项任务处理完毕！", (unsigned long)g_resultsArray.count);
        NSMutableString *finalResult = [NSMutableString string];
        for (NSUInteger i = 0; i < g_resultsArray.count; i++) {
            [finalResult appendFormat:@"--- 第 %lu 项详情 ---\n", (unsigned long)i + 1];
            [finalResult appendString:g_resultsArray[i]];
            [finalResult appendString:@"\n\n"];
        }
        [UIPasteboard generalPasteboard].string = finalResult;
        LogMessage(@"批量提取完成，所有内容已合并并复制到剪贴板！");
        
        g_isMultiExtracting = NO;
        g_targetCollectionView = nil;
        g_workQueue = nil;
        g_resultsArray = nil;
        return;
    }
    
    NSIndexPath *indexPath = g_workQueue.firstObject;
    [g_workQueue removeObjectAtIndex:0];
    LogMessage(@"正在处理第 %lu/%lu 项 (indexPath: %ld-%ld)...", (unsigned long)(g_resultsArray.count + 1), (unsigned long)(g_resultsArray.count + g_workQueue.count + 1), (long)indexPath.section, (long)indexPath.item);
    
    id delegate = g_targetCollectionView.delegate;
    if (delegate && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
        [delegate collectionView:g_targetCollectionView didSelectItemAtIndexPath:indexPath];
    }
}

// =================================================================
// 3. UI 和控制逻辑
// =================================================================

@interface UIViewController (MultiExtractor)
- (void)setupMultiExtractorPanel;
- (void)startMultiExtraction;
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer; // 新增拖动方法声明
@end

%hook UIViewController
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupMultiExtractorPanel];
        });
    }
}

%new
- (void)setupMultiExtractorPanel {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) { keyWindow = scene.windows.firstObject; break; }
        }
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [[UIApplication sharedApplication] keyWindow];
        #pragma clang diagnostic pop
    }
    if (!keyWindow || [keyWindow viewWithTag:789002]) return;

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 350, 400)];
    panel.tag = 789002;
    panel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.92];
    panel.layer.cornerRadius = 12;
    panel.layer.borderColor = [UIColor systemYellowColor].CGColor; // 活动版用黄色
    panel.layer.borderWidth = 1.5;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 350, 20)];
    titleLabel.text = @"课体批量提取器 v1.5";
    titleLabel.textColor = [UIColor systemYellowColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:titleLabel];

    UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
    extractButton.frame = CGRectMake(20, 50, panel.bounds.size.width - 40, 44);
    [extractButton setTitle:@"一键提取全部课体" forState:UIControlStateNormal];
    [extractButton addTarget:self action:@selector(startMultiExtraction) forControlEvents:UIControlEventTouchUpInside];
    extractButton.backgroundColor = [UIColor systemYellowColor];
    [extractButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    extractButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    extractButton.layer.cornerRadius = 8;
    [panel addSubview:extractButton];

    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 110, panel.bounds.size.width - 20, panel.bounds.size.height - 120)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor systemYellowColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = NO;
    g_logView.layer.cornerRadius = 5;
    g_logView.text = @"v1.5: 窗口已可拖动，请继续测试。";
    [panel addSubview:g_logView];

    // --- 新增：为面板增加拖动手势 ---
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [panel addGestureRecognizer:pan];

    [keyWindow addSubview:panel];
}

%new
- (void)startMultiExtraction {
    if (g_isMultiExtracting) { LogMessage(@"错误：任务已在进行中。"); return; }
    
    LogMessage(@"--- 开始批量提取任务 ---");

    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) { keyWindow = scene.windows.firstObject; break; }
        }
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [[UIApplication sharedApplication] keyWindow];
        #pragma clang diagnostic pop
    }
    if (!keyWindow) { LogMessage(@"错误: 找不到主窗口。"); return; }
    
    g_targetCollectionView = nil;
    
    Class keTiCellClass = NSClassFromString(@"六壬大占.課體單元");
    if (!keTiCellClass) { LogMessage(@"错误: 找不到 '六壬大占.課體單元' 类。"); return; }
    
    NSMutableArray<UICollectionView *> *allCVs = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], keyWindow, allCVs);
    LogMessage(@"在窗口中找到 %lu 个 UICollectionView。", (unsigned long)allCVs.count);
    
    for (UICollectionView *cv in allCVs) {
        LogMessage(@"正在检查位于 (%.0f, %.0f) 的 CollectionView...", cv.frame.origin.x, cv.frame.origin.y);
        for (UICollectionViewCell *cell in cv.visibleCells) {
             LogMessage(@"--> 检查可见单元格，类型: %@", NSStringFromClass([cell class]));
             if ([cell isKindOfClass:keTiCellClass]) {
                LogMessage(@"成功匹配! 目标确定!");
                g_targetCollectionView = cv;
                break;
             }
        }
        if (g_targetCollectionView) {
            break;
        }
    }

    if (!g_targetCollectionView) { LogMessage(@"错误: 在整个窗口中都找不到包含课体视图的UICollectionView。"); return; }
    
    g_isMultiExtracting = YES;
    g_workQueue = [NSMutableArray array];
    g_resultsArray = [NSMutableArray array];
    
    NSInteger totalItems = 0;
    if ([g_targetCollectionView.dataSource respondsToSelector:@selector(collectionView:numberOfItemsInSection:)]) {
        totalItems = [g_targetCollectionView.dataSource collectionView:g_targetCollectionView numberOfItemsInSection:0];
    }
    
    if (totalItems == 0) {
        LogMessage(@"警告：目标列表的数据源报告有0个单元格。");
    }

    for (NSInteger i = 0; i < totalItems; i++) {
        [g_workQueue addObject:[NSIndexPath indexPathForItem:i inSection:0]];
    }

    if (g_workQueue.count == 0) {
        LogMessage(@"错误: 未找到任何课体单元来创建任务队列。");
        g_isMultiExtracting = NO;
        return;
    }

    LogMessage(@"发现 %lu 个课体单元，开始处理队列...", (unsigned long)g_workQueue.count);
    processWorkQueue();
}

// --- 新增：处理拖动手势的方法 ---
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
        Class vcClass = NSClassFromString(@"六壬大占.ViewController");
        if (vcClass) {
            MSHookMessageEx(vcClass, @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
            NSLog(@"[MultiExtractor] 课体批量自动提取器已准备就绪。");
        }
    }
}
