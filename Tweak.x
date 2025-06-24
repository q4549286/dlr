#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 全局状态
// =========================================================================
static BOOL g_isListening = NO;
static NSMutableString *g_accumulatedResult = nil;
static NSInteger g_recordCount = 0;

// =========================================================================
// 2. 辅助函数
// =========================================================================
static UIViewController* getTopmostViewController() {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) { if (window.isKeyWindow) { keyWindow = window; break; } }
            }
        }
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [[UIApplication sharedApplication] keyWindow];
        #pragma clang diagnostic pop
    }
    UIViewController *topController = keyWindow.rootViewController;
    while (topController.presentedViewController) { topController = topController.presentedViewController; }
    return topController;
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 3. 主功能实现
// =========================================================================
@interface UIViewController (TheUltimateScribe)
- (void)startScribeMode;
- (void)finishScribeMode;
@end

%hook UIViewController

// --- 注入最终的“书记员”工具栏 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = self.view.window; if (!window) return;
            [[window viewWithTag:202501] removeFromSuperview]; [[window viewWithTag:202502] removeFromSuperview];
            
            UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
            startButton.frame = CGRectMake(self.view.frame.size.width - 230, 50, 100, 44); startButton.tag = 202501;
            [startButton setTitle:@"开始记录" forState:UIControlStateNormal]; startButton.titleLabel.font = [UIFont boldSystemFontOfSize:16]; startButton.backgroundColor = [UIColor systemGreenColor]; [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; startButton.layer.cornerRadius = 22;
            [startButton addTarget:self action:@selector(startScribeMode) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:startButton];
            
            UIButton *finishButton = [UIButton buttonWithType:UIButtonTypeSystem];
            finishButton.frame = CGRectMake(self.view.frame.size.width - 120, 50, 110, 44); finishButton.tag = 202502;
            [finishButton setTitle:@"完成并复制" forState:UIControlStateNormal]; finishButton.titleLabel.font = [UIFont boldSystemFontOfSize:16]; finishButton.backgroundColor = [UIColor systemRedColor]; [finishButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; finishButton.layer.cornerRadius = 22;
            [finishButton addTarget:self action:@selector(finishScribeMode) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:finishButton];
        });
    }
}

// --- 核心拦截器：被动监听，并用智能重试机制解决时机问题 ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isListening) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            void (^originalCompletion)(void) = completion;
            void (^scribeCompletion)(void) = ^{
                if (originalCompletion) { originalCompletion(); }
                
                __block int retryCount = 0;
                
                // 【【【编译错误修正】】】
                // 1. 使用 __block 声明
                // 2. 将声明与定义分开
                // 3. 使用 pragma 压制任何潜在的循环引用警告
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-retain-cycles"
                __block void (^tryExtract)(void);
                tryExtract = ^{
                    NSMutableArray *labels = [NSMutableArray array];
                    FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, labels);
                    
                    BOOL hasText = NO;
                    for (UILabel *label in labels) { if (label.text.length > 0) { hasText = YES; break; } }
                    
                    if (hasText || retryCount >= 10) {
                        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                            CGFloat y1 = roundf(o1.frame.origin.y), y2 = roundf(o2.frame.origin.y);
                            if (y1 < y2) return NSOrderedAscending; if (y1 > y2) return NSOrderedDescending;
                            return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                        }];
                        
                        NSMutableArray<NSString *> *texts = [NSMutableArray array];
                        for (UILabel *label in labels) { if (label.text.length > 0) { [texts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; } }
                        
                        NSString *capturedDetail = texts.count > 0 ? [texts componentsJoinedByString:@" | "] : @"[无文本信息]";
                        [g_accumulatedResult appendFormat:@"--- (记录 #%ld) ---\n%@\n\n", (long)++g_recordCount, capturedDetail];

                        UILabel *feedbackLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 40)];
                        feedbackLabel.center = CGPointMake(viewControllerToPresent.view.bounds.size.width / 2, viewControllerToPresent.view.bounds.size.height / 2);
                        feedbackLabel.text = @"已记录"; feedbackLabel.textColor = [UIColor whiteColor]; feedbackLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7]; feedbackLabel.textAlignment = NSTextAlignmentCenter; feedbackLabel.layer.cornerRadius = 10; feedbackLabel.clipsToBounds = YES;
                        [viewControllerToPresent.view addSubview:feedbackLabel];
                        [UIView animateWithDuration:1.0 animations:^{ feedbackLabel.alpha = 0; } completion:^(BOOL f){ [feedbackLabel removeFromSuperview]; }];
                        
                    } else {
                        retryCount++;
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            tryExtract();
                        });
                    }
                };
                #pragma clang diagnostic pop
                
                tryExtract();
            };
            
            %orig(viewControllerToPresent, flag, scribeCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)startScribeMode {
    g_isListening = YES;
    g_accumulatedResult = [NSMutableString string];
    g_recordCount = 0;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"记录模式已开始" message:@"请像平时一样，用手指点击您想提取的课盘内容。所有弹窗详情将被自动记录。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"明白了" style:UIAlertActionStyleDefault handler:nil]];
    
    [getTopmostViewController() presentViewController:alert animated:YES completion:nil];
}

%new
- (void)finishScribeMode {
    if (!g_isListening) { return; }
    
    g_isListening = NO;
    [UIPasteboard generalPasteboard].string = g_accumulatedResult;
    
    NSString *message = (g_recordCount > 0) ? [NSString stringWithFormat:@"记录完成！共 %ld 项内容已合并并复制到剪贴板！", (long)g_recordCount] : @"没有记录任何内容。";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"记录完成" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"胜利！" style:UIAlertActionStyleDefault handler:nil]];
    
    [getTopmostViewController() presentViewController:alert animated:YES completion:nil];
}

%end
