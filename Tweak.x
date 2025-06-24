#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 全局状态与辅助UI（这部分完全不变，工作得很好）
// =========================================================================
static BOOL g_isListeningForWei = NO;
static NSMutableArray *g_capturedWeiValues = nil;

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
// 2. 核心捕获逻辑：我们为UIView创建一个分类来存放我们的新方法
// =========================================================================
@interface UIView (WeiHunterHook)
- (void)my_hooked_touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
@end

@implementation UIView (WeiHunterHook)
- (void)my_hooked_touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // 首先，让App的原始功能正常执行。因为方法已交换，所以调用自己就是调用原始实现。
    [self my_hooked_touchesEnded:touches withEvent:event];

    // 然后，执行我们的捕获逻辑。
    if (g_isListeningForWei) {
        @try {
            id weiValue = [self valueForKey:@"位"];
            NSString *capturedDescription = weiValue ? [NSString stringWithFormat:@"%@", weiValue] : @"[捕获失败: '位' 为 nil]";
            [g_capturedWeiValues addObject:capturedDescription];
            
            UILabel *feedbackLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 120, 40)];
            feedbackLabel.center = getTopmostViewController().view.center;
            feedbackLabel.text = @"'位' 已捕获!";
            feedbackLabel.textColor = [UIColor whiteColor]; feedbackLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7]; feedbackLabel.textAlignment = NSTextAlignmentCenter; feedbackLabel.layer.cornerRadius = 10; feedbackLabel.clipsToBounds = YES;
            [getTopmostViewController().view.window addSubview:feedbackLabel];
            [UIView animateWithDuration:1.5 animations:^{ feedbackLabel.alpha = 0; } completion:^(BOOL f) { [feedbackLabel removeFromSuperview]; }];
        } @catch (NSException *exception) {
            [g_capturedWeiValues addObject:[NSString stringWithFormat:@"[捕获异常: %@]", exception.reason]];
        }
    }
}
@end

// =========================================================================
// 3. UI注入与控制（这部分完全不变，工作得很好）
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

%new - (void)startWeiHunting {
    g_isListeningForWei = YES;
    g_capturedWeiValues = [NSMutableArray array];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"捕获模式已开始" message:@"请像平时一样，点击课盘中的“初传”、“中传”、“末传”等项目。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"明白了" style:UIAlertActionStyleDefault handler:nil]];
    [getTopmostViewController() presentViewController:alert animated:YES completion:nil];
}

%new - (void)finishWeiHunting {
    if (!g_isListeningForWei) { return; }
    g_isListeningForWei = NO;
    NSString *finalResult = [g_capturedWeiValues componentsJoinedByString:@"\n---\n"];
    [UIPasteboard generalPasteboard].string = finalResult;
    NSString *message = (g_capturedWeiValues.count > 0) ? [NSString stringWithFormat:@"捕获完成！共 %ld 个'位'值已复制到剪贴板！", (unsigned long)g_capturedWeiValues.count] : @"没有捕获任何'位'值。请确认在捕获模式下点击了“三传”区域。";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"捕获完成" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"胜利！" style:UIAlertActionStyleDefault handler:nil]];
    [getTopmostViewController() presentViewController:alert animated:YES completion:nil];
}

%end


// =========================================================================
// 4. 手动方法交换
// =========================================================================
%ctor {
    // 初始化我们的UIViewController Hook (用于添加按钮)
    %init; 

    // 手动交换 "六壬大占.三傳視圖" 的方法
    Class targetClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (targetClass) {
        SEL originalSelector = @selector(touchesEnded:withEvent:);
        SEL newSelector = @selector(my_hooked_touchesEnded:withEvent:);
        
        Method originalMethod = class_getInstanceMethod(targetClass, originalSelector);
        // 我们的新方法是在UIView的分类里，所以从UIView获取
        Method newMethod = class_getInstanceMethod([UIView class], newSelector);
        
        if (originalMethod && newMethod) {
            method_exchangeImplementations(originalMethod, newMethod);
        }
    }
}
