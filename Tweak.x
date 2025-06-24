#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 全局状态
// =========================================================================
static BOOL g_isListeningForWei = NO;
static NSMutableArray *g_capturedWeiValues = nil;

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

// =========================================================================
// 3. 主功能实现
// =========================================================================
@interface UIViewController (TheWeiHunter)
- (void)startWeiHunting;
- (void)finishWeiHunting;
@end

// 我们将Hook代码放在一个单独的 %group 中，以便于手动交换
%group TheosBypassHook
%hook UIViewController

// 新的、用于交换的方法
- (void)my_hooked_showSummary:(id)sender {
    if (g_isListeningForWei && sender) {
        @try {
            id weiValue = [sender valueForKey:@"位"];
            NSString *capturedDescription = weiValue ? [NSString stringWithFormat:@"%@", weiValue] : @"[捕获失败: '位' 为 nil]";
            [g_capturedWeiValues addObject:capturedDescription];
            
            UILabel *feedbackLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 120, 40)];
            feedbackLabel.center = self.view.center;
            feedbackLabel.text = @"'位' 已捕获!";
            feedbackLabel.textColor = [UIColor whiteColor]; feedbackLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7]; feedbackLabel.textAlignment = NSTextAlignmentCenter; feedbackLabel.layer.cornerRadius = 10; feedbackLabel.clipsToBounds = YES;
            [self.view.window addSubview:feedbackLabel];
            [UIView animateWithDuration:1.5 animations:^{ feedbackLabel.alpha = 0; } completion:^(BOOL f) { [feedbackLabel removeFromSuperview]; }];
        } @catch (NSException *exception) {
            [g_capturedWeiValues addObject:[NSString stringWithFormat:@"[捕获异常: %@]", exception.reason]];
        }
    }
    // 调用原始实现 (因为方法已交换，所以调用自己就是调用原始)
    [self my_hooked_showSummary:sender];
}

%end


%hook UIViewController

// --- 注入最终的“猎人”工具栏 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = self.view.window; if (!window) return;
            [[window viewWithTag:202701] removeFromSuperview]; [[window viewWithTag:202702] removeFromSuperview];
            
            UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
            startButton.frame = CGRectMake(self.view.frame.size.width - 230, 50, 100, 44); startButton.tag = 202701;
            [startButton setTitle:@"捕获'位'" forState:UIControlStateNormal]; startButton.titleLabel.font = [UIFont boldSystemFontOfSize:16]; startButton.backgroundColor = [UIColor systemIndigoColor]; [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; startButton.layer.cornerRadius = 22;
            [startButton addTarget:self action:@selector(startWeiHunting) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:startButton];
            
            UIButton *finishButton = [UIButton buttonWithType:UIButtonTypeSystem];
            finishButton.frame = CGRectMake(self.view.frame.size.width - 120, 50, 110, 44); finishButton.tag = 202702;
            [finishButton setTitle:@"完成并复制" forState:UIControlStateNormal]; finishButton.titleLabel.font = [UIFont boldSystemFontOfSize:16]; finishButton.backgroundColor = [UIColor systemOrangeColor]; [finishButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; finishButton.layer.cornerRadius = 22;
            [finishButton addTarget:self action:@selector(finishWeiHunting) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:finishButton];
        });
    }
}

%new
- (void)startWeiHunting {
    g_isListeningForWei = YES;
    g_capturedWeiValues = [NSMutableArray array];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"捕获模式已开始" message:@"请像平时一样，用手指点击您想记录'位'的课盘内容。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"明白了" style:UIAlertActionStyleDefault handler:nil]];
    [getTopmostViewController() presentViewController:alert animated:YES completion:nil];
}

%new
- (void)finishWeiHunting {
    if (!g_isListeningForWei) { return; }
    g_isListeningForWei = NO;
    NSString *finalResult = [g_capturedWeiValues componentsJoinedByString:@"\n"];
    [UIPasteboard generalPasteboard].string = finalResult;
    NSString *message = (g_capturedWeiValues.count > 0) ? [NSString stringWithFormat:@"捕获完成！共 %ld 个'位'值已复制到剪贴板！", (unsigned long)g_capturedWeiValues.count] : @"没有捕获任何'位'值。";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"捕获完成" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"胜利！" style:UIAlertActionStyleDefault handler:nil]];
    [getTopmostViewController() presentViewController:alert animated:YES completion:nil];
}

%end


// --- 手动方法交换 ---
%ctor {
    %init(TheosBypassHook); // 初始化我们定义了Hook方法的group

    Class vcClass = [UIViewController class];
    
    // 获取原始方法和新方法的选择器
    SEL originalSelector = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    SEL newSelector = @selector(my_hooked_showSummary:);
    
    Method originalMethod = class_getInstanceMethod(vcClass, originalSelector);
    Method newMethod = class_getInstanceMethod(vcClass, newSelector);
    
    // 只有当原始方法存在时才进行交换，以增加健壮性
    if (originalMethod && newMethod) {
        method_exchangeImplementations(originalMethod, newMethod);
    }
}
