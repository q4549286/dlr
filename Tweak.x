#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 把辅助函数直接放在这里，不使用static
NSString* MyCreateIvarListString(id object, NSString *objectName) {
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
    // 1. 获取弹窗类名
    NSString *presentedVCClassName = NSStringFromClass([viewControllerToPresent class]);

    // 2. 判断是否是我们关心的弹窗
    if ([presentedVCClassName containsString:@"摘要"] || [presentedVCClassName containsString:@"Popover"]) {
        
        // 3. 获取状态字符串
        NSString *mainVCState = MyCreateIvarListString(self, @"主VC (self)");
        NSString *popupVCState = MyCreateIvarListString(viewControllerToPresent, @"弹窗VC");
        NSString *fullMessage = [NSString stringWithFormat:@"弹窗: %@\n\n%@%@", presentedVCClassName, mainVCState, popupVCState];

        // 4. 创建我们自己的Alert
        UIAlertController *myAlert = [UIAlertController alertControllerWithTitle:@"内部状态侦查" message:fullMessage preferredStyle:UIAlertControllerStyleActionSheet];
        [myAlert addAction:[UIAlertAction actionWithTitle:@"复制并关闭" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = fullMessage;
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        }]];
        
        // 5. 调用原始方法，让APP的弹窗先出现
        %orig(viewControllerToPresent, flag, ^{
            // 6. 在APP弹窗完成的回调里，再弹出我们自己的Alert
            if (completion) {
                completion();
            }
            // 找到顶层VC来呈现我们的Alert
            UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
            while (topController.presentedViewController) {
                topController = topController.presentedViewController;
            }
            [topController presentViewController:myAlert animated:YES completion:nil];
        });

    } else {
        // 7. 如果不是我们关心的弹窗，就直接调用原始方法
        %orig(viewControllerToPresent, flag, completion);
    }
}

%end
