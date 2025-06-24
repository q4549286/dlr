#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// --- 辅助函数：生成一个包含对象所有实例变量及其值的字符串 ---
static NSString* CreateIvarListString(id object, NSString *objectName) {
    if (!object) {
        return [NSString stringWithFormat:@"对象 '%@' 为 nil。", objectName];
    }
    
    NSMutableString *logStr = [NSMutableString stringWithFormat:@"\n\n--- %@ (%@) 的内部状态 ---\n", objectName, NSStringFromClass([object class])];
    
    Class currentClass = [object class];
    while (currentClass && currentClass != [NSObject class]) {
        [logStr appendFormat:@"\n  --- 属于类: %@ ---\n", NSStringFromClass(currentClass)];
        unsigned int ivarCount;
        Ivar *ivars = class_copyIvarList(currentClass, &ivarCount);
        if (ivarCount == 0) {
            [logStr appendString:@"  (无自定义ivar)\n"];
        }
        for (unsigned int i = 0; i < ivarCount; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            id value = nil;
            NSString *valueDescription = @"[无法获取值]";
            @try {
                const char *type = ivar_getTypeEncoding(ivar);
                if (type[0] == '@') { // 是一个OC对象
                    value = object_getIvar(object, ivar);
                    valueDescription = [NSString stringWithFormat:@"%@", value];
                } else {
                    valueDescription = [NSString stringWithFormat:@"[非对象类型: %s]", type];
                }
            } @catch (NSException *exception) {
                valueDescription = [NSString stringWithFormat:@"[获取时异常: %@]", exception.reason];
            }
            [logStr appendFormat:@"  ? %s = %@\n", name, valueDescription];
        }
        free(ivars);
        currentClass = class_getSuperclass(currentClass);
    }
     [logStr appendString:@"\n===========================\n\n"];
    return logStr;
}


// --- 核心Hook ---
%hook 六壬大占.ViewController

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    NSString *presentedVCClassName = NSStringFromClass([viewControllerToPresent class]);

    if ([presentedVCClassName containsString:@"摘要"] || [presentedVCClassName containsString:@"Popover"]) {
        
        NSString *mainVCState = CreateIvarListString(self, @"主VC (self)");
        NSString *popupVCState = CreateIvarListString(viewControllerToPresent, @"弹窗VC");
        NSString *fullMessage = [NSString stringWithFormat:@"侦测到弹窗: %@\n\n%@%@", presentedVCClassName, mainVCState, popupVCState];

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"内部状态侦查"
                                                                         message:fullMessage
                                                                  preferredStyle:UIAlertControllerStyleActionSheet]; // 使用ActionSheet以防万一

        [alert addAction:[UIAlertAction actionWithTitle:@"复制并关闭" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = fullMessage;
            // 我们手动dismiss我们自己的alert
             [alert dismissViewControllerAnimated:YES completion:nil];
             // 同时也尝试dismiss原来的弹窗
             [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        }]];

        [alert addAction:[UIAlertAction actionWithTitle:@"直接关闭" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action){
            // 同样，关闭所有
            [alert dismissViewControllerAnimated:YES completion:nil];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        }]];
        
        // 【关键修正】我们不在这里调用%orig，因为我们想完全控制流程
        // 我们在下面呈现我们自己的Alert
        
        // 找到最顶层的VC来呈现这个Alert
        UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topController.presentedViewController) {
            topController = topController.presentedViewController;
        }
        // 先dismiss掉原来的弹窗，再显示我们的
        [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
             [topController presentViewController:alert animated:YES completion:nil];
        }];

        // 因为我们完全接管了流程，所以不调用 %orig
        return;
    }

    // 如果不是我们关心的弹窗，就正常执行
    %orig(viewControllerToPresent, flag, completion);
}

%end
