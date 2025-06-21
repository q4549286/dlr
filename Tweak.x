#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 侦察专用代码 V4 - 探测“右列”视图内部
// =========================================================================

static BOOL hasLogged_V4 = NO;

// 日志生成和显示的核心函数
void showLoggingAlertForObject_V4(id targetObject, NSString *objectName) {
    if (hasLogged_V4) return;
    hasLogged_V4 = YES;

    NSMutableString *logMessage = [NSMutableString string];
    [logMessage appendFormat:@"--- 侦察日志 V4 (探测 %@) ---\n\n", objectName];
    [logMessage appendFormat:@"Instance: %@\n\n", targetObject];

    // --- 使用 object_getIvar 精准探测实例变量 ---
    [logMessage appendString:@"--- IVARS (Direct Read) ---\n"];
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([targetObject class], &ivarCount);
    if (ivarCount == 0) {
        [logMessage appendString:@"(No ivars found)\n"];
    }
    for (int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *ivarName_c = ivar_getName(ivar);
        const char *ivarType_c = ivar_getTypeEncoding(ivar);
        if (ivarName_c) {
            NSString *ivarName = [NSString stringWithUTF8String:ivarName_c];
            NSString *ivarType = [NSString stringWithUTF8String:ivarType_c];
            id value = nil;
            @try {
                value = object_getIvar(targetObject, ivar);
            } @catch (NSException *exception) {
                value = [NSString stringWithFormat:@"(Exception on direct access: %@)", exception.reason];
            }
            [logMessage appendFormat:@"ivar: %@ (type: %@) = %@\n", ivarName, ivarType, value];
        }
    }
    free(ivars);

    // --- 创建并显示弹窗 ---
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"侦察日志 V4 (探测 %@)", objectName] message:logMessage preferredStyle:UIAlertControllerStyleAlert];
        
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


// Hook UIView，等待“右列”视图出现
%hook UIView 
- (void)didMoveToWindow {
    %orig;

    // 获取“右列”视图的类名
    // 根据之前的日志，乱码是 Âè≥ÂàóË¶ñÂúñ
    // 我们需要找到它真正的名字。如果找不到，就用乱码尝试。
    // 一个常见的技巧是，先找到它的父视图（ViewController），再从父视图里找到它。
    
    UIResponder *responder = self;
    while ((responder = [responder nextResponder])) {
        if ([responder isKindOfClass:NSClassFromString(@"六壬大占.ViewController")]) {
            UIViewController *vc = (UIViewController *)responder;
            
            // 从ViewController中，尝试获取名为“右列”的实例变量
            id youLieView = nil;
            @try {
                 youLieView = [vc valueForKey:@"右列"];
            } @catch (NSException *e) {
                // pass
            }

            if (youLieView && self == youLieView) {
                // 确认当前这个 self 就是我们要找的“右列”视图
                showLoggingAlertForObject_V4(youLieView, @"右列视图");
            }
            break;
        }
    }
}
%end
