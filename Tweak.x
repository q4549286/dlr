#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数 (无变化)
// =========================================================================
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray<NSDictionary *> *g_keChuanWorkQueue = nil;
static NSMutableArray<NSString *> *g_keChuanTitleQueue = nil;

static UITextView *g_logTextView = nil;
static UIView *g_controlPanelView = nil;

static void LogMessage(NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss.SSS"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSString *fullMessage = [logPrefix stringByAppendingString:message];
        g_logTextView.text = [NSString stringWithFormat:@"%@\n%@", fullMessage, g_logTextView.text];
        NSLog(@"[KeChuanExtractor] %@", message);
    });
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)startExtraction_Truth;
- (void)processKeChuanQueue_Truth;
- (void)createOrShowControlPanel_Truth;
- (void)copyAndClose_Truth;
// 【新】为课体添加独立测试方法
- (void)startKeTiExtraction_Test;
- (void)processKeTiQueue_Test;
@end

%hook UIViewController

// --- viewDidLoad ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger controlButtonTag = 556691;
            if ([keyWindow viewWithTag:controlButtonTag]) { [[keyWindow viewWithTag:controlButtonTag] removeFromSuperview]; }
            
            UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
            controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            controlButton.tag = controlButtonTag;
            [controlButton setTitle:@"提取面板" forState:UIControlStateNormal];
            controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            controlButton.backgroundColor = [UIColor purpleColor];
            [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            controlButton.layer.cornerRadius = 8;
            [controlButton addTarget:self action:@selector(createOrShowControlPanel_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:controlButton];
        });
    }
}

// --- presentViewController (无变化, 依然可以捕获所有弹窗) ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        // 【新】增加对课体弹窗的类名捕获 (如果它有特殊类名的话)
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"] || [vcClassName containsString:@"課體摘要視圖"]) {
            LogMessage(@"捕获到弹窗: %@", vcClassName);
            viewControllerToPresent.view.alpha = 0.0f; flag = NO;
            
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) {
                        [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                LogMessage(@"成功提取内容 (共 %lu 条)", (unsigned long)g_capturedKeChuanDetailArray.count);
                
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    const double kDelayInSeconds = 0.2; 
                    LogMessage(@"弹窗已关闭，延迟 %.1f 秒后处理下一个...", kDelayInSeconds);
                    // 【新】根据调用的测试类型，决定回调哪个处理函数
                    if (g_keChuanWorkQueue.count > 0 && [g_keChuanWorkQueue.firstObject[@"taskType"] isEqualToString:@"keTi"]) {
                        [self processKeTiQueue_Test];
                    } else {
                        [self processKeChuanQueue_Truth];
                    }
                }];
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
        LogMessage(@"出现未知弹窗，已忽略: %@", vcClassName);
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)createOrShowControlPanel_Truth {
    UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
    NSInteger panelTag = 556692;
    if (g_controlPanelView && g_controlPanelView.superview) {
        [g_controlPanelView removeFromSuperview]; g_controlPanelView = nil; g_logTextView = nil; return;
    }
    g_controlPanelView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, keyWindow.bounds.size.width - 20, keyWindow.bounds.size.height - 200)];
    g_controlPanelView.tag = panelTag;
    g_controlPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
    g_controlPanelView.layer.cornerRadius = 12; g_controlPanelView.clipsToBounds = YES;
    
    // 主功能按钮
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    startButton.frame = CGRectMake(10, 10, 150, 40);
    [startButton setTitle:@"提取三传+四课" forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(startExtraction_Truth) forControlEvents:UIControlEventTouchUpInside];
    startButton.backgroundColor = [UIColor systemGreenColor]; [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; startButton.layer.cornerRadius = 8;
    
    // 【新】课体测试按钮
    UIButton *ketiTestButton = [UIButton buttonWithType:UIButtonTypeSystem];
    ketiTestButton.frame = CGRectMake(170, 10, 150, 40);
    [ketiTestButton setTitle:@"测试提取课体" forState:UIControlStateNormal];
    [ketiTestButton addTarget:self action:@selector(startKeTiExtraction_Test) forControlEvents:UIControlEventTouchUpInside];
    ketiTestButton.backgroundColor = [UIColor systemBlueColor]; [ketiTestButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; ketiTestButton.layer.cornerRadius = 8;
    
    // 复制按钮
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(10, 60, 150, 40);
    [copyButton setTitle:@"复制结果并关闭" forState:UIControlStateNormal];
    [copyButton addTarget:self action:@selector(copyAndClose_Truth) forControlEvents:UIControlEventTouchUpInside];
    copyButton.backgroundColor = [UIColor systemOrangeColor]; [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; copyButton.layer.cornerRadius = 8;
    
    // 日志窗口
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 110, g_controlPanelView.bounds.size.width - 20, g_controlPanelView.bounds.size.height - 120)];
    g_logTextView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0]; g_logTextView.textColor = [UIColor systemGreenColor]; g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12]; g_logTextView.editable = NO; g_logTextView.layer.cornerRadius = 8; g_logTextView.text = @"日志控制台已准备就绪。\n";
    
    [g_controlPanelView addSubview:startButton];
    [g_controlPanelView addSubview:ketiTestButton];
    [g_controlPanelView addSubview:copyButton];
    [g_controlPanelView addSubview:g_logTextView];
    [keyWindow addSubview:g_controlPanelView];
}

%new
- (void)copyAndClose_Truth {
    if (g_capturedKeChuanDetailArray && g_keChuanTitleQueue && g_capturedKeChuanDetailArray.count == g_keChuanTitleQueue.count) {
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = g_capturedKeChuanDetailArray[i];
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        LogMessage(@"结果已复制到剪贴板！");
    } else { 
        LogMessage(@"没有可复制的内容或队列数量不匹配。标题: %lu, 内容: %lu", (unsigned long)g_keChuanTitleQueue.count, (unsigned long)g_capturedKeChuanDetailArray.count);
    }
    
    if (g_controlPanelView) {
        [g_controlPanelView removeFromSuperview]; g_controlPanelView = nil; g_logTextView = nil;
    }
}

// ---- 原有功能，保持不变 ----
%new
- (void)startExtraction_Truth { /* ... 原有代码保持不变 ... */ }
%new
- (void)processKeChuanQueue_Truth { /* ... 原有代码保持不变 ... */ }


// =========================================================================
// 【【【【【 新增的独立测试模块 】】】】】
// =========================================================================
%new
- (void)startKeTiExtraction_Test {
    if (g_isExtractingKeChuanDetail) { LogMessage(@"错误：提取任务已在进行中。"); return; }
    
    LogMessage(@"--- 开始【课体】独立提取测试 ---");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
  
    Class ketiViewClass = NSClassFromString(@"六壬大占.課體視圖");
    if (!ketiViewClass) {
        LogMessage(@"【课体测试】错误：找不到 課體視圖 类。");
        g_isExtractingKeChuanDetail = NO; return;
    }

    NSMutableArray *ketiViews = [NSMutableArray array];
    // 课体视图可能在 '課傳' 容器内，也可能直接在主视图上，我们都在self.view里找最保险
    FindSubviewsOfClassRecursive(ketiViewClass, self.view, ketiViews);

    if (ketiViews.count == 0) {
        LogMessage(@"【课体测试】错误：在视图层级中找不到 課體視圖 的实例。");
        g_isExtractingKeChuanDetail = NO; return;
    }
    
    UIView *ketiView = ketiViews.firstObject;
    LogMessage(@"【课体测试】成功找到 課體視圖 实例: %@", ketiView);

    BOOL foundGesture = NO;
    for (UIGestureRecognizer *gesture in ketiView.gestureRecognizers) {
        // 我们需要找到那个点击手势
        if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
            LogMessage(@"【课体测试】在 課體視圖 上找到一个点击手势: %@", gesture);
            // 假设整个课体视图共享一个弹窗
            [g_keChuanWorkQueue addObject:@{@"gesture": gesture, @"contextView": ketiView, @"taskType": @"keTi"}];
            [g_keChuanTitleQueue addObject:@"课体"];
            foundGesture = YES;
            break; // 假设只有一个，找到就跳出
        }
    }

    if (!foundGesture) {
        LogMessage(@"【课体测试】警告：在 課體視圖 上未找到任何点击手势(UITapGestureRecognizer)。");
    }

    if (g_keChuanWorkQueue.count == 0) {
        LogMessage(@"【课体测试】队列为空，未找到任何可提取项。测试结束。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    
    LogMessage(@"【课体测试】任务队列构建完成，总计 %lu 项。", (unsigned long)g_keChuanWorkQueue.count);
    [self processKeTiQueue_Test];
}

%new
- (void)processKeTiQueue_Test {
    if (!g_isExtractingKeChuanDetail || g_keChuanWorkQueue.count == 0) {
        if (g_isExtractingKeChuanDetail) {
            LogMessage(@"---【课体】独立测试处理完毕！---");
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"课体测试完成" message:@"详情已提取，请检查日志和剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
        g_isExtractingKeChuanDetail = NO;
        return;
    }
  
    NSDictionary *task = g_keChuanWorkQueue.firstObject; 
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    NSString *title = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];
    UIGestureRecognizer *gestureToTrigger = task[@"gesture"];
    UIView *contextView = task[@"contextView"]; // 应该是那个課體視圖
    
    LogMessage(@"【课体测试】正在处理: %@", title);
    
    // 第零步：设置内部状态变量。这里我们不确定课体是否需要设置 '課傳'，但为了保险起见，我们设置它。
    Ivar keChuanIvar = class_getInstanceVariable([self class], "課傳");
    if (keChuanIvar) {
        object_setIvar(self, keChuanIvar, contextView);
        LogMessage(@"【课体测试】第0步: 尝试设置 '課傳' ivar -> %@", contextView);
    }
    
    // 第一步：调用我们从日志中发现的方法
    SEL actionToPerform = NSSelectorFromString(@"點擊課體:");
    
    if ([self respondsToSelector:actionToPerform]) {
        LogMessage(@"【课体测试】第1步: 调用方法 %@, 传递手势: %@", NSStringFromSelector(actionToPerform), gestureToTrigger);
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:gestureToTrigger];
        #pragma clang diagnostic pop
    } else {
        LogMessage(@"【课体测试】第1步: 致命错误！ViewController 上不存在方法 %@。", NSStringFromSelector(actionToPerform));
        [g_capturedKeChuanDetailArray addObject:@"[课体提取失败: 方法不存在]"];
        [self processKeTiQueue_Test]; // 即使失败也继续处理，以防万一
    }
}


%end
