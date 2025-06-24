#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 全局状态与辅助UI
// =========================================================================
static BOOL g_isListeningForWei = NO;
static NSMutableArray *g_capturedWeiValues = nil;

static UIViewController* getTopmostViewController() {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) { keyWindow = window; break; }
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
// 2. 核心捕获逻辑：基于您亲手验证的真相
// =========================================================================
@interface NSObject (TheFinalTruth)
- (void)my_hooked_showKeChuanSummary:(id)sender;
@end

@implementation NSObject (TheFinalTruth)
- (void)my_hooked_showKeChuanSummary:(id)sender {
    // 首先，调用原始方法，确保App正常显示摘要
    [self my_hooked_showKeChuanSummary:sender];

    // 然后，执行我们的捕获逻辑
    if (g_isListeningForWei) {
        @try {
            if (sender && [sender respondsToSelector:@selector(valueForKey:)]) {
                id weiValue = [sender valueForKey:@"位"];
                if (weiValue) {
                    NSString *capturedDescription = [NSString stringWithFormat:@"%@", weiValue];
                    [g_capturedWeiValues addObject:capturedDescription];
                    
                    // 移除旧的反馈标签，以防万一
                    [[getTopmostViewController().view.window viewWithTag:202703] removeFromSuperview];

                    UILabel *feedbackLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 120, 40)];
                    feedbackLabel.center = getTopmostViewController().view.center;
                    feedbackLabel.text = @"'位' 已捕获!";
                    feedbackLabel.tag = 202703; // 给标签一个唯一的tag
                    feedbackLabel.textColor = [UIColor whiteColor]; feedbackLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7]; feedbackLabel.textAlignment = NSTextAlignmentCenter; feedbackLabel.layer.cornerRadius = 10; feedbackLabel.clipsToBounds = YES;
                    [getTopmostViewController().view.window addSubview:feedbackLabel];
                    
                    // 短暂显示后消失
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [UIView animateWithDuration:0.3 animations:^{
                            feedbackLabel.alpha = 0;
                        } completion:^(BOOL finished) {
                            [feedbackLabel removeFromSuperview];
                        }];
                    });
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
            UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem]; startButton.frame = CGRectMake(self.view.frame.size.width - 230, 50, 100, 44); startButton.tag = 202701; [startButton setTitle:@"捕获'位'" forState:UIControlStateNormal]; startButton.titleLabel.font = [UIFont boldSystemFontOfSize:16]; startButton.backgroundColor = [UIColor systemIndigoColor]; [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; startButton.layer.cornerRadius = 22; [startButton addTarget:self action:@selector(startWeiHunting) forControlEvents:UIControlEventTouchUpInside]; [window addSubview:startButton];
            UIButton *finishButton = [UIButton buttonWithType:UIButtonTypeSystem]; finishButton.frame = CGRectMake(self.view.frame.size.width - 120, 50, 110, 44); finishButton.tag = 202702; [finishButton setTitle:@"完成并复制" forState:UIControlStateNormal]; finishButton.titleLabel.font = [UIFont boldSystemFontOfSize:16]; finishButton.backgroundColor = [UIColor systemOrangeColor]; [finishButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; finishButton.layer.cornerRadius = 22; [finishButton addTarget:self action:@selector(finishWeiHunting) forControlEvents:UIControlEventTouchUpInside]; [window addSubview:finishButton];
        });
    }
}
%new - (void)startWeiHunting { g_isListeningForWei = YES; g_capturedWeiValues = [NSMutableArray array]; UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"捕获模式已开始" message:@"请像平时一样，点击课盘中的任何项目。\n\n我们将用这些数据，来分析'初传循环'的问题。" preferredStyle:UIAlertControllerStyleAlert]; [alert addAction:[UIAlertAction actionWithTitle:@"明白了" style:UIAlertActionStyleDefault handler:nil]]; [getTopmostViewController() presentViewController:alert animated:YES completion:nil]; }
%new - (void)finishWeiHunting { if (!g_isListeningForWei) { return; } g_isListeningForWei = NO; NSString *finalResult = [g_capturedWeiValues componentsJoinedByString:@"\n---\n"]; [UIPasteboard generalPasteboard].string = finalResult; NSString *message = (g_capturedWeiValues.count > 0) ? [NSString stringWithFormat:@"捕获完成！共 %ld 个'位'值已复制到剪贴板！\n\n请将剪贴板内容发给我，以分析循环问题。", (unsigned long)g_capturedWeiValues.count] : @"没有捕获任何'位'值。\n\n请先开启捕获模式，并点击地支等项目。"; UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"捕获完成" message:message preferredStyle:UIAlertControllerStyleAlert]; [alert addAction:[UIAlertAction actionWithTitle:@"胜利！" style:UIAlertActionStyleDefault handler:nil]]; [getTop-mostViewController() presentViewController:alert animated:YES completion:nil]; }
%end

// =========================================================================
// 4. 方法交换：用您亲手验证的真相，执行最终的、正确的操作
// =========================================================================
%ctor {
    %init;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass) {
        SEL originalSelector = NSSelectorFromString(@"顯示課傳摘要WithSender:");
        SEL newSelector = @selector(my_hooked_showKeChuanSummary:);
        Method originalMethod = class_getInstanceMethod(targetClass, originalSelector);
        Method newMethod = class_getInstanceMethod([NSObject class], newSelector);
        if (originalMethod && newMethod) {
            method_exchangeImplementations(originalMethod, newMethod);
        }
    }
}
