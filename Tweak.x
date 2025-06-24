#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 全局状态与辅助UI
// =========================================================================
static BOOL g_isListeningForWei = NO;
static NSMutableArray *g_capturedWeiValues = nil;

// 【【【语法修正】】】
// 将函数恢复为正常的多行格式，以修复编译错误。
static UIViewController* getTopmostViewController() {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
            }
        }
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [[UIApplication sharedApplication] keyWindow];
        #pragma clang diagnostic pop
    }
    UIViewController *topController = keyWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    return topController;
}


// =========================================================================
// 2. 核心捕获逻辑：回归王道，直击Action
// =========================================================================
@interface UIViewController (WeiHunterHook)
- (void)my_hooked_showSummary:(id)sender;
@end

@implementation UIViewController (WeiHunterHook)
- (void)my_hooked_showSummary:(id)sender {
    // 首先，让原始方法执行。
    [self my_hooked_showSummary:sender];

    if (g_isListeningForWei) {
        @try {
            if (sender && [sender respondsToSelector:@selector(valueForKey:)]) {
                id weiValue = [sender valueForKey:@"位"];
                if (weiValue) {
                    NSString *capturedDescription = [NSString stringWithFormat:@"%@", weiValue];
                    [g_capturedWeiValues addObject:capturedDescription];
                    
                    UILabel *feedbackLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 120, 40)];
                    feedbackLabel.center = getTopmostViewController().view.center;
                    feedbackLabel.text = @"'位' 已捕获!";
                    feedbackLabel.textColor = [UIColor whiteColor]; feedbackLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7]; feedbackLabel.textAlignment = NSTextAlignmentCenter; feedbackLabel.layer.cornerRadius = 10; feedbackLabel.clipsToBounds = YES;
                    [getTopmostViewController().view.window addSubview:feedbackLabel];
                    [UIView animateWithDuration:1.5 animations:^{ feedbackLabel.alpha = 0; } completion:^(BOOL f) { [feedbackLabel removeFromSuperview]; }];
                }
            }
        } @catch (NSException *exception) {
            // 静默失败
        }
    }
}
@end


// =========================================================================
// 3. UI注入与控制
// =========================================================================
@interface UIViewController (TheWeiHunter)
- (void)startWeiHunting;
- (void)finishWeiHunting;
@end

%hook UIViewController
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
%new - (void)startWeiHunting { g_isListeningForWei = YES; g_capturedWeiValues = [NSMutableArray array]; UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"捕获模式已开始" message:@"请像平时一样，点击课盘中的任何项目。" preferredStyle:UIAlertControllerStyleAlert]; [alert addAction:[UIAlertAction actionWithTitle:@"明白了" style:UIAlertActionStyleDefault handler:nil]]; [getTopmostViewController() presentViewController:alert animated:YES completion:nil]; }
%new - (void)finishWeiHunting { if (!g_isListeningForWei) { return; } g_isListeningForWei = NO; NSString *finalResult = [g_capturedWeiValues componentsJoinedByString:@"\n---\n"]; [UIPasteboard generalPasteboard].string = finalResult; NSString *message = (g_capturedWeiValues.count > 0) ? [NSString stringWithFormat:@"捕获完成！共 %ld 个'位'值已复制到剪贴板！", (unsigned long)g_capturedWeiValues.count] : @"没有捕获任何'位'值。"; UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"捕获完成" message:message preferredStyle:UIAlertControllerStyleAlert]; [alert addAction:[UIAlertAction actionWithTitle:@"胜利！" style:UIAlertActionStyleDefault handler:nil]]; [getTopmostViewController() presentViewController:alert animated:YES completion:nil]; }
%end

// =========================================================================
// 4. 手动方法交换：使用终极武器攻击正确目标
// =========================================================================
%ctor {
    %init;

    Class targetClass = [UIViewController class];
    
    SEL originalSelector = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    SEL newSelector = @selector(my_hooked_showSummary:);
    
    Method originalMethod = class_getInstanceMethod(targetClass, originalSelector);
    Method newMethod = class_getInstanceMethod(targetClass, newSelector);
    
    if (originalMethod && newMethod) {
        method_exchangeImplementations(originalMethod, newMethod);
    }
}
