#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 侦察专用代码 V6 - 万能触摸侦测
// =========================================================================

static BOOL hasLogged_V6 = NO;

// 日志生成和显示的核心函数
void showLoggingAlertForHierarchy_V6(UIView *tappedView) {
    if (hasLogged_V6) return;
    hasLogged_V6 = YES;

    NSMutableString *logMessage = [NSMutableString string];
    [logMessage appendString:@"--- 侦察日志 V6 (万能触摸侦测) ---\n\n"];
    
    // 从被点击的视图开始，向上遍历并记录整个视图层级
    UIView *currentView = tappedView;
    int depth = 0;
    while (currentView) {
        [logMessage appendFormat:@"--- Level %d ---\n", depth];
        [logMessage appendFormat:@"View: %@\n", currentView];
        [logMessage appendFormat:@"Class: %@\n\n", [currentView class]];
        
        // --- 探测当前视图的实例变量 ---
        [logMessage appendString:@"--- IVARS ---\n"];
        unsigned int ivarCount;
        Ivar *ivars = class_copyIvarList([currentView class], &ivarCount);
        if (ivarCount == 0) {
            [logMessage appendString:@"(No ivars found)\n"];
        }
        for (int i = 0; i < ivarCount; i++) {
            Ivar ivar = ivars[i];
            const char *ivarName_c = ivar_getName(ivar);
            if (ivarName_c) {
                NSString *ivarName = [NSString stringWithUTF8String:ivarName_c];
                id value = nil;
                @try {
                    value = object_getIvar(currentView, ivar);
                } @catch (NSException *exception) {
                    value = [NSString stringWithFormat:@"(Exception)"];
                }
                [logMessage appendFormat:@"ivar: %@ = %@\n", ivarName, value];
            }
        }
        free(ivars);
        [logMessage appendString:@"\n---------------------------------\n\n"];
        
        currentView = currentView.superview;
        depth++;
    }

    // --- 创建并显示弹窗 ---
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"侦察日志 V6" message:@"已捕获点击事件，请复制日志" preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"复制日志" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = logMessage;
        }];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleCancel handler:nil];

        [alert addAction:copyAction];
        [alert addAction:okAction];
        
        UIWindow *activeWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
                if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                    activeWindow = windowScene.windows.firstObject;
                    break;
                }
            }
        }
        if (!activeWindow) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            activeWindow = [[UIApplication sharedApplication] keyWindow];
            #pragma clang diagnostic pop
        }
        [activeWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}

// Hook UIWindow，这是所有触摸事件的根源
%hook UIWindow

- (void)sendEvent:(UIEvent *)event {
    %orig; // 必须先调用 %orig，让系统处理事件

    // 只关心触摸事件，并且只在触摸结束时触发
    if (event.type == UIEventTypeTouches) {
        UITouch *touch = [event.allTouches anyObject];
        if (touch.phase == UITouchPhaseEnded) {
            // 获取被点击的视图
            UIView *tappedView = touch.view;
            
            // 触发我们的万能日志记录器
            showLoggingAlertForHierarchy_V6(tappedView);
        }
    }
}

%end
