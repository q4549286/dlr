#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// --- 辅助函数：生成一个包含对象所有实例变量及其值的字符串 ---
static NSString* CreateIvarListString(id object, NSString *objectName) {
    if (!object) { return [NSString stringWithFormat:@"对象 '%@' 为 nil。", objectName]; }
    NSMutableString *logStr = [NSMutableString stringWithFormat:@"\n\n--- %@ (%@) 的状态 ---\n", objectName, NSStringFromClass([object class])];
    Class currentClass = [object class];
    while (currentClass && currentClass != [NSObject class]) {
        [logStr appendFormat:@"\n  (类: %@)\n", NSStringFromClass(currentClass)];
        unsigned int ivarCount;
        Ivar *ivars = class_copyIvarList(currentClass, &ivarCount);
        for (unsigned int i = 0; i < ivarCount; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            NSString *valueDescription = @"[非对象或无法获取]";
            if (ivar_getTypeEncoding(ivar)[0] == '@') {
                @try { valueDescription = [NSString stringWithFormat:@"%@", object_getIvar(object, ivar)]; }
                @catch (NSException *exception) { valueDescription = @"[获取时异常]"; }
            }
            [logStr appendFormat:@"  ? %s = %@\n", name, valueDescription];
        }
        free(ivars);
        currentClass = class_getSuperclass(currentClass);
    }
    return logStr;
}

// --- 核心Hook ---
%hook 六壬大占.ViewController

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // 【唯一逻辑】先调用原始方法，确保一切正常进行
    %orig(viewControllerToPresent, flag, completion);

    NSString *presentedVCClassName = NSStringFromClass([viewControllerToPresent class]);

    // 我们只在弹窗出现 *之后* 再做事
    if ([presentedVCClassName containsString:@"摘要"] || [presentedVCClassName containsString:@"Popover"]) {
        
        // 使用 dispatch_after 确保弹窗已完全呈现
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            NSString *mainVCState = CreateIvarListString(self, @"主VC (self)");
            NSString *popupVCState = CreateIvarListString(viewControllerToPresent, @"弹窗VC");
            NSString *fullMessage = [NSString stringWithFormat:@"侦测到弹窗: %@\n\n%@%@", presentedVCClassName, mainVCState, popupVCState];

            // 创建并显示Alert
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"内部状态侦查"
                                                                             message:fullMessage
                                                                      preferredStyle:UIAlertControllerStyleAlert];

            [alert addAction:[UIAlertAction actionWithTitle:@"复制并关闭" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                [UIPasteboard generalPasteboard].string = fullMessage;
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            }]];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"直接关闭" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            }]];
            
            // 用弹窗VC自己来呈现我们的侦查Alert
            [viewControllerToPresent presentViewController:alert animated:YES completion:nil];
        });
    }
}

%end
