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
                value = object_getIvar(object, ivar);
                // 对于非对象类型，object_getIvar返回的是指针或值的拷贝，直接打印可能无意义或崩溃
                // 我们只尝试打印看起来像对象的东西
                const char *type = ivar_getTypeEncoding(ivar);
                if (type[0] == '@') { // 是一个OC对象
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

    // 我们只关心与课传摘要相关的弹窗
    if ([presentedVCClassName containsString:@"摘要"] || [presentedVCClassName containsString:@"Popover"]) {
        
        // 1. 获取主VC (self) 的状态字符串
        NSString *mainVCState = CreateIvarListString(self, @"主VC (self)");
        
        // 2. 获取弹窗VC的状态字符串
        NSString *popupVCState = CreateIvarListString(viewControllerToPresent, @"弹窗VC");

        // 3. 组合成一个巨大的消息体
        NSString *fullMessage = [NSString stringWithFormat:@"侦测到弹窗: %@\n\n%@%@", presentedVCClassName, mainVCState, popupVCState];

        // 4. 创建并显示一个可滚动的Alert
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"内部状态侦查"
                                                                         message:fullMessage
                                                                  preferredStyle:UIAlertControllerStyleAlert];

        // 添加一个“复制并关闭”按钮
        [alert addAction:[UIAlertAction actionWithTitle:@"复制并关闭" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = fullMessage;
        }]];

        // 添加一个“关闭”按钮
        [alert addAction:[UIAlertAction actionWithTitle:@"直接关闭" style:UIAlertActionStyleCancel handler:nil]];

        // 找到最顶层的VC来呈现这个Alert，防止它被弹窗覆盖
        UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topController.presentedViewController) {
            topController = topController.presentedViewController;
        }
        [topController presentViewController:alert animated:YES completion:nil];

        // 注意：我们依然要调用原始的present方法，让原来的弹窗出现
        // 但我们的Alert会覆盖在它上面
    }

    // 调用原始方法
    %orig(viewControllerToPresent, flag, completion);
}

%end
