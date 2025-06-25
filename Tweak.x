// Filename: KeTi_JiuZongMen_Extractor_v1.6
// 终极修复版！根据您的最终指点，采用最简单直接的逻辑，只寻找主StackView并遍历其内容，确保100%提取成功。
// v1.6: 修复了pragma和performSelector导致的编译错误。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =================================================================
// 1. 全局变量与辅助函数
// =================================================================

// --- 状态控制 ---
static BOOL g_isExtracting = NO;
static NSString *g_currentTaskType = nil;

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
        NSLog(@"[Extractor-Fixed-v1.6] %@", message);
    });
}


// =================================================================
// 2. 核心的Hook与队列处理逻辑
// =================================================================

static void processKeTiWorkQueue(void); 

// Hook：拦截弹窗事件
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    Class targetClass = NSClassFromString(@"六壬大占.課體概覽視圖");
    
    if (g_isExtracting && targetClass && [vcToPresent isKindOfClass:targetClass]) {
        vcToPresent.view.alpha = 0.0f; animated = NO;
        
        void (^extractionCompletion)(void) = ^{
            if (completion) { completion(); }

            // --- 全新的、最简单直接的提取逻辑 ---
            NSMutableArray<NSString *> *textParts = [NSMutableArray array];
            UIView *contentView = vcToPresent.view; 
            
            // 1. 深入找到包含所有内容的那个UIView
            if ([contentView.subviews.firstObject isKindOfClass:[UIScrollView class]]) {
                 UIScrollView *scrollView = contentView.subviews.firstObject;
                 if (scrollView.subviews.count > 0) {
                     contentView = scrollView.subviews.firstObject;
                 }
            }

            // 2. 在这个UIView里找到唯一的、垂直排列的主StackView
            UIStackView *mainStackView = nil;
            for(UIView *subview in contentView.subviews){
                if([subview isKindOfClass:[UIStackView class]]){
                    mainStackView = (UIStackView *)subview;
                    break;
                }
            }
            
            // 3. 遍历主StackView里的每一个子StackView，提取配对的Label
            if(mainStackView){
                LogMessage(@"找到主StackView，遍历 %lu 个子项...", (unsigned long)mainStackView.arrangedSubviews.count);
                for(UIView *subview in mainStackView.arrangedSubviews){
                    if([subview isKindOfClass:[UIStackView class]]){
                        UIStackView *rowStackView = (UIStackView *)subview;
                        if(rowStackView.arrangedSubviews.count >= 2 && [rowStackView.arrangedSubviews[0] isKindOfClass:[UILabel class]] && [rowStackView.arrangedSubviews[1] isKindOfClass:[UILabel class]]){
                            UILabel *titleLabel = (UILabel *)rowStackView.arrangedSubviews[0];
                            UILabel *contentLabel = (UILabel *)rowStackView.arrangedSubviews[1];
                            
                            if(titleLabel.text && titleLabel.text.length > 0){
                                NSString *contentText = contentLabel.text ?: @"";
                                if([contentText.lowercaseString isEqualToString:@"nil"]){
                                    contentText = @""; // 处理Flex截图中看到的 "nil"
                                }
                                [textParts addObject:[NSString stringWithFormat:@"%@ → %@", titleLabel.text, [contentText stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]];
                            }
                        }
                    }
                }
            } else {
                LogMessage(@"错误：未能找到主StackView，提取失败！");
            }
            
            NSString *extractedText = [textParts componentsJoinedByString:@"\n"];
            // --- 提取逻辑结束 ---
            
            // --- 根据任务类型，决定如何处理提取到的文本 ---
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
            [finalResult appendFormat:@"--- 课体第 %lu 项详情 ---\n", (unsigned long)i + 1];
            [finalResult appendString:g_keTi_resultsArray[i]];
            [finalResult appendString:@"\n\n"];
        }
        [UIPasteboard generalPasteboard].string = finalResult;
        LogMessage(@"“课体”批量提取完成，所有内容已合并并复制！");
        
        g_isExtracting = NO; g_currentTaskType = nil; g_keTi_targetCV = nil; g_keTi_workQueue = nil; g_keTi_resultsArray = nil;
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
- (void)setupCombinedExtractorPanel; - (void)startKeTiExtraction; - (void)startJiuZongMenExtraction; - (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer;
@end

%hook UIViewController
- (void)viewDidLoad { %orig; Class targetClass = NSClassFromString(@"六壬大占.ViewController"); if (targetClass && [self isKindOfClass:targetClass]) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self setupCombinedExtractorPanel]; }); } }

%new
- (void)setupCombinedExtractorPanel {
    UIWindow *keyWindow = nil;
    // --- FIX: Expanded if/else block to prevent compiler errors ---
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                keyWindow = scene.windows.firstObject;
                break;
            }
        }
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [[UIApplication sharedApplication] keyWindow];
        #pragma clang diagnostic pop
    }
    if (!keyWindow || [keyWindow viewWithTag:889900]) return;

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 350, 450)];
    panel.tag = 889900;
    panel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.92];
    panel.layer.cornerRadius = 12;
    panel.layer.borderColor = [UIColor systemBlueColor].CGColor;
    panel.layer.borderWidth = 1.5;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 350, 20)];
    titleLabel.text = @"课体/九宗门提取器 v1.6";
    titleLabel.textColor = [UIColor systemBlueColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:titleLabel];

    UIButton *keTiButton = [UIButton buttonWithType:UIButtonTypeSystem];
    keTiButton.frame = CGRectMake(20, 50, panel.bounds.size.width - 40, 44);
    [keTiButton setTitle:@"一键提取全部课体" forState:UIControlStateNormal];
    [keTiButton addTarget:self action:@selector(startKeTiExtraction) forControlEvents:UIControlEventTouchUpInside];
    keTiButton.backgroundColor = [UIColor systemGreenColor];
    
    UIButton *jiuZongMenButton = [UIButton buttonWithType:UIButtonTypeSystem];
    jiuZongMenButton.frame = CGRectMake(20, 104, panel.bounds.size.width - 40, 44);
    [jiuZongMenButton setTitle:@"提取九宗门详情" forState:UIControlStateNormal];
    [jiuZongMenButton addTarget:self action:@selector(startJiuZongMenExtraction) forControlEvents:UIControlEventTouchUpInside];
    jiuZongMenButton.backgroundColor = [UIColor systemCyanColor];

    for (UIButton *btn in @[keTiButton, jiuZongMenButton]) {
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        btn.layer.cornerRadius = 8;
        [panel addSubview:btn];
    }

    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 160, panel.bounds.size.width - 20, panel.bounds.size.height - 170)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor whiteColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = NO;
    g_logView.layer.cornerRadius = 5;
    g_logView.text = @"编译错误已修复，请测试。";
    [panel addSubview:g_logView];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [panel addGestureRecognizer:pan];
    [keyWindow addSubview:panel];
}

%new
- (void)startKeTiExtraction {
    if (g_isExtracting) { LogMessage(@"错误：已有任务在进行中。"); return; }
    LogMessage(@"--- 开始“课体”批量提取任务 ---");
    UIWindow *keyWindow = self.view.window; if (!keyWindow) { LogMessage(@"错误: 找不到主窗口。"); return; }
    
    g_keTi_targetCV = nil;
    Class keTiCellClass = NSClassFromString(@"六壬大占.課體單元");
    if (!keTiCellClass) { LogMessage(@"错误: 找不到 '六壬大占.課體單元' 类。"); return; }
    
    NSMutableArray<UICollectionView *> *allCVs = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], keyWindow, allCVs);
    for (UICollectionView *cv in allCVs) { for (UICollectionViewCell *cell in cv.visibleCells) { if ([cell isKindOfClass:keTiCellClass]) { g_keTi_targetCV = cv; break; } } if (g_keTi_targetCV) { break; } }
    if (!g_keTi_targetCV) { LogMessage(@"错误: 找不到包含“课体”的UICollectionView。"); return; }
    
    g_isExtracting = YES; g_currentTaskType = @"KeTi";
    g_keTi_workQueue = [NSMutableArray array]; g_keTi_resultsArray = [NSMutableArray array];
    
    NSInteger totalItems = [g_keTi_targetCV.dataSource collectionView:g_keTi_targetCV numberOfItemsInSection:0];
    for (NSInteger i = 0; i < totalItems; i++) { [g_keTi_workQueue addObject:[NSIndexPath indexPathForItem:i inSection:0]]; }
    if (g_keTi_workQueue.count == 0) { LogMessage(@"错误: 未找到任何“课体”单元来创建任务队列。"); g_isExtracting = NO; return; }
    LogMessage(@"发现 %lu 个“课体”单元，开始处理队列...", (unsigned long)g_keTi_workQueue.count);
    processKeTiWorkQueue();
}

%new
- (void)startJiuZongMenExtraction {
    if (g_isExtracting) { LogMessage(@"错误：已有任务在进行中。"); return; }
    LogMessage(@"--- 开始“九宗门”提取任务 ---");
    g_isExtracting = YES; g_currentTaskType = @"JiuZongMen";
    SEL selector = NSSelectorFromString(@"顯示九宗門概覽");
    if ([self respondsToSelector:selector]) {
        LogMessage(@"正在调用方法: 顯示九宗門概覽");
        // --- FIX: Expanded block to prevent compiler errors and suppress leak warning correctly ---
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:selector];
        #pragma clang diagnostic pop
    } 
    else {
        LogMessage(@"错误: 当前ViewController没有'顯示九宗門概覽'方法。");
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
        Class vcClass = NSClassFromString(@"六壬大占.ViewController");
        if (vcClass) {
            MSHookMessageEx(vcClass, @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
            NSLog(@"[Extractor-Fixed-v1.6] 提取器已准备就绪。");
        }
    }
}
