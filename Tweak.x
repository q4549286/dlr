// Filename: KeTiMultiExtractor_v1.0
// 终极版！提供UI按钮，可一键自动点击所有可见的“课体”单元，并批量提取详情。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =================================================================
// 1. 全局变量与辅助函数
// =================================================================

static BOOL g_isMultiExtracting = NO;               // 标记是否正在执行批量任务
static NSMutableArray *g_workQueue = nil;           // 待处理的任务队列 (存放每个单元的indexPath)
static NSMutableArray *g_resultsArray = nil;        // 存放每次提取到的结果
static UICollectionView *g_targetCollectionView = nil; // 目标CollectionView
static UITextView *g_logView = nil;                 // 日志窗口

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
        NSLog(@"[MultiExtractor] %@", message);
    });
}


// =================================================================
// 2. 核心的Hook与队列处理逻辑
// =================================================================

// 前向声明，因为presentViewController的hook需要调用它
static void processWorkQueue(void); 

// Hook：拦截弹窗事件
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    Class targetClass = NSClassFromString(@"六壬大占.課體概覽視圖");
    
    // 只在我们的批量任务执行时，才拦截目标窗口
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
            
            // 自动关闭弹窗，并在关闭后处理下一个任务
            [vcToPresent dismissViewControllerAnimated:NO completion:^{
                // 加一个短暂的延迟，防止操作过快
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

// 任务队列处理器
static void processWorkQueue() {
    // 如果队列处理完毕
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
        
        // 重置状态
        g_isMultiExtracting = NO;
        g_targetCollectionView = nil;
        g_workQueue = nil;
        g_resultsArray = nil;
        return;
    }
    
    // 从队列中取出一个任务
    NSIndexPath *indexPath = g_workQueue.firstObject;
    [g_workQueue removeObjectAtIndex:0];
    
    LogMessage(@"正在处理第 %lu/%lu 项...", (unsigned long)(g_resultsArray.count + 1), (unsigned long)(g_resultsArray.count + g_workQueue.count + 1));
    
    // 以编程方式点击该单元
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
    panel.layer.borderColor = [UIColor systemGreenColor].CGColor;
    panel.layer.borderWidth = 1.5;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 350, 20)];
    titleLabel.text = @"课体批量提取器 v1.0";
    titleLabel.textColor = [UIColor systemGreenColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:titleLabel];

    UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
    extractButton.frame = CGRectMake(20, 50, panel.bounds.size.width - 40, 44);
    [extractButton setTitle:@"一键提取全部课体" forState:UIControlStateNormal];
    [extractButton addTarget:self action:@selector(startMultiExtraction) forControlEvents:UIControlEventTouchUpInside];
    extractButton.backgroundColor = [UIColor systemGreenColor];
    [extractButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    extractButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    extractButton.layer.cornerRadius = 8;
    [panel addSubview:extractButton];

    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 110, panel.bounds.size.width - 20, panel.bounds.size.height - 120)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor systemGreenColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = NO;
    g_logView.layer.cornerRadius = 5;
    g_logView.text = @"点击上方按钮，开始批量自动提取所有可见的'课体'单元格。";
    [panel addSubview:g_logView];
    [keyWindow addSubview:panel];
}

%new
- (void)startMultiExtraction {
    if (g_isMultiExtracting) { LogMessage(@"错误：任务已在进行中。"); return; }
    
    LogMessage(@"--- 开始批量提取任务 ---");

    g_targetCollectionView = nil;
    Class keTiCellClass = NSClassFromString(@"六壬大占.課體視圖");
    if (!keTiCellClass) { LogMessage(@"错误: 找不到 '六壬大占.課體視圖' 类。"); return; }
    
    NSMutableArray<UICollectionView *> *allCVs = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], self.view, allCVs);
    
    for (UICollectionView *cv in allCVs) {
        for (UIView *cell in cv.visibleCells) {
            if ([cell isKindOfClass:keTiCellClass]) { g_targetCollectionView = cv; break; }
        }
        if (g_targetCollectionView) break;
    }

    if (!g_targetCollectionView) { LogMessage(@"错误: 找不到包含课体视图的UICollectionView。"); return; }
    
    g_isMultiExtracting = YES;
    g_workQueue = [NSMutableArray array];
    g_resultsArray = [NSMutableArray array];
    
    NSMutableArray *cellsToSort = [NSMutableArray array];
    for (UICollectionViewCell *cell in g_targetCollectionView.visibleCells) {
        if ([cell isKindOfClass:keTiCellClass]) { [cellsToSort addObject:cell]; }
    }
    
    // 按从左到右的顺序排序
    [cellsToSort sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
        return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)];
    }];

    for (UICollectionViewCell *cell in cellsToSort) {
        NSIndexPath *indexPath = [g_targetCollectionView indexPathForCell:cell];
        if (indexPath) { [g_workQueue addObject:indexPath]; }
    }

    if (g_workQueue.count == 0) {
        LogMessage(@"错误: 未找到任何可见的课体单元。");
        g_isMultiExtracting = NO;
        return;
    }

    LogMessage(@"发现 %lu 个课体单元，开始处理队列...", (unsigned long)g_workQueue.count);
    processWorkQueue(); // 启动队列处理器
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
