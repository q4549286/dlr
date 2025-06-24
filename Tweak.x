#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// [全局状态与辅助UI代码与上一版相同，保持不变]
static BOOL g_isListeningForWei = NO;
static NSMutableArray *g_capturedWeiValues = nil;
static UIViewController* getTopmostViewController() { UIWindow *keyWindow = nil; if (@available(iOS 13.0, *)) { for (UIWindowScene *scene in [[UIApplication sharedApplication] connectedScenes]) { if (scene.activationState == UISceneActivationStateForegroundActive) { for (UIWindow *window in scene.windows) { if (window.isKeyWindow) { keyWindow = window; break; } } } } } else { #pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
keyWindow = [[UIApplication sharedApplication] keyWindow]; #pragma clang diagnostic pop
} UIViewController *topController = keyWindow.rootViewController; while (topController.presentedViewController) { topController = topController.presentedViewController; } return topController; }

// =========================================================================
// 2. 核心捕获逻辑：修复闪退并扩大适用范围
// =========================================================================
@interface UIView (WeiHunterHook)
- (void)my_hooked_touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
@end

@implementation UIView (WeiHunterHook)
- (void)my_hooked_touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // 首先，让原始方法执行。
    [self my_hooked_touchesEnded:touches withEvent:event];

    // 只有在捕获模式下才继续
    if (!g_isListeningForWei) {
        return;
    }
    
    // 我们检查self是否是我们关心的那几个类之一。
    // 这样做比在%ctor里分别hook更灵活。
    NSArray *targetClassNames = @[@"六壬大占.傳視圖", @"六壬大占.三傳視圖", @"六壬大占.課傳視圖"];
    BOOL isTarget = NO;
    for (NSString *className in targetClassNames) {
        Class targetClass = NSClassFromString(className);
        if (targetClass && [self isKindOfClass:targetClass]) {
            isTarget = YES;
            break;
        }
    }

    if (isTarget) {
        @try {
            // 【【【最终的、修复闪退的修正】】】
            // 我们先尝试获取'位'属性。
            id weiValue = [self valueForKey:@"位"];
            
            // 只有当'位'属性真实存在(不为nil)时，我们才记录它。
            // 这可以防止因点击空白区域而导致的闪退或记录无效数据。
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
        } @catch (NSException *exception) {
            // 保留catch以防万一，但上面的if(weiValue)应该能处理绝大多数情况。
            // 这里可以什么都不做，静默失败，防止弹窗干扰。
        }
    }
}
@end


// [UI注入与控制代码与上一版相同，保持不变]
@interface UIViewController (TheWeiHunter)
- (void)startWeiHunting;
- (void)finishWeiHunting;
@end
%hook UIViewController
- (void)viewDidLoad { %orig; Class targetClass = NSClassFromString(@"六壬大占.ViewController"); if (targetClass && [self isKindOfClass:targetClass]) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ UIWindow *window = self.view.window; if (!window) return; [[window viewWithTag:202701] removeFromSuperview]; [[window viewWithTag:202702] removeFromSuperview]; UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem]; startButton.frame = CGRectMake(self.view.frame.size.width - 230, 50, 100, 44); startButton.tag = 202701; [startButton setTitle:@"捕获'位'" forState:UIControlStateNormal]; startButton.titleLabel.font = [UIFont boldSystemFontOfSize:16]; startButton.backgroundColor = [UIColor systemIndigoColor]; [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; startButton.layer.cornerRadius = 22; [startButton addTarget:self action:@selector(startWeiHunting) forControlEvents:UIControlEventTouchUpInside]; [window addSubview:startButton]; UIButton *finishButton = [UIButton buttonWithType:UIButtonTypeSystem]; finishButton.frame = CGRectMake(self.view.frame.size.width - 120, 50, 110, 44); finishButton.tag = 202702; [finishButton setTitle:@"完成并复制" forState:UIControlStateNormal]; finishButton.titleLabel.font = [UIFont boldSystemFontOfSize:16]; finishButton.backgroundColor = [UIColor systemOrangeColor]; [finishButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; finishButton.layer.cornerRadius = 22; [finishButton addTarget:self action:@selector(finishWeiHunting) forControlEvents:UIControlEventTouchUpInside]; [window addSubview:finishButton]; }); } }
%new - (void)startWeiHunting { g_isListeningForWei = YES; g_capturedWeiValues = [NSMutableArray array]; UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"捕获模式已开始" message:@"请像平时一样，点击课盘中的任何项目。" preferredStyle:UIAlertControllerStyleAlert]; [alert addAction:[UIAlertAction actionWithTitle:@"明白了" style:UIAlertActionStyleDefault handler:nil]]; [getTopmostViewController() presentViewController:alert animated:YES completion:nil]; }
%new - (void)finishWeiHunting { if (!g_isListeningForWei) { return; } g_isListeningForWei = NO; NSString *finalResult = [g_capturedWeiValues componentsJoinedByString:@"\n---\n"]; [UIPasteboard generalPasteboard].string = finalResult; NSString *message = (g_capturedWeiValues.count > 0) ? [NSString stringWithFormat:@"捕获完成！共 %ld 个'位'值已复制到剪贴板！", (unsigned long)g_capturedWeiValues.count] : @"没有捕获任何'位'值。"; UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"捕获完成" message:message preferredStyle:UIAlertControllerStyleAlert]; [alert addAction:[UIAlertAction actionWithTitle:@"胜利！" style:UIAlertActionStyleDefault handler:nil]]; [getTopmostViewController() presentViewController:alert animated:YES completion:nil]; }
%end

// =========================================================================
// 4. 手动方法交换：扩大围剿范围
// =========================================================================
%ctor {
    %init;

    // 【【【最终的、扩大围剿范围的修正】】】
    // 我们将对所有可疑的视图类，应用同一个Hook。
    NSArray *targetClassNames = @[@"六壬大占.傳視圖", @"六壬大占.三傳視圖", @"六壬大占.課傳視圖"];
    
    SEL originalSelector = @selector(touchesEnded:withEvent:);
    SEL newSelector = @selector(my_hooked_touchesEnded:withEvent:);
    Method newMethod = class_getInstanceMethod([UIView class], newSelector);

    for (NSString *className in targetClassNames) {
        Class targetClass = NSClassFromString(className);
        if (targetClass) {
            Method originalMethod = class_getInstanceMethod(targetClass, originalSelector);
            if (originalMethod && newMethod) {
                // 我们使用method_exchangeImplementations是安全的，因为我们只对这几个特定类操作。
                method_exchangeImplementations(originalMethod, newMethod);
            }
        }
    }
}
