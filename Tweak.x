#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 侦察专用代码 V5 - 点击按钮反向侦察
// =========================================================================

static BOOL hasLogged_V5 = NO;

// 日志生成和显示的核心函数
void showLoggingAlertForObject_V5(id targetObject, NSString *objectName) {
    if (hasLogged_V5) return;
    hasLogged_V5 = YES;

    NSMutableString *logMessage = [NSMutableString string];
    [logMessage appendFormat:@"--- 侦察日志 V5 (探测 %@) ---\n\n", objectName];
    [logMessage appendFormat:@"Instance: %@\n", targetObject];
    [logMessage appendFormat:@"Class: %@\n\n", [targetObject class]];

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
        if (ivarName_c) {
            NSString *ivarName = [NSString stringWithUTF8String:ivarName_c];
            id value = nil;
            @try {
                value = object_getIvar(targetObject, ivar);
            } @catch (NSException *exception) {
                value = [NSString stringWithFormat:@"(Exception on direct access)"];
            }
            [logMessage appendFormat:@"ivar: %@ = %@\n", ivarName, value];
        }
    }
    free(ivars);

    // --- 创建并显示弹窗 ---
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"侦察日志 V5 (探测 %@)", objectName] message:logMessage preferredStyle:UIAlertControllerStyleAlert];
        
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


// Hook UIButton 的点击事件
%hook UIButton

- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    %orig; // 先执行原始的点击事件，确保App正常响应

    // 获取按钮的标题
    NSString *buttonTitle = self.titleLabel.text;

    // 如果点击的是“格局”或“法诀”(毕法)按钮
    if ([buttonTitle isEqualToString:@"格局"] || [buttonTitle isEqualToString:@"法诀"] || [buttonTitle isEqualToString:@"毕法"]) {
        
        // --- 开始向上查找“右列”视图 ---
        UIView *currentView = self;
        while (currentView.superview) {
            currentView = currentView.superview;
            
            // 我们根据FLEX截图里的乱码类名来猜测它真正的类名
            // `Âè≥ÂàóË¶ñÂúñ` -> `右列视图`
            // 我们直接检查类名中是否包含“右列”这两个字，这是一个更稳妥的方法
            NSString *className = NSStringFromClass([currentView class]);
            if ([className containsString:@"右列"]) {
                // 找到了！这个 currentView 就是我们要的“右列”视图对象
                // 对它进行精准探测
                showLoggingAlertForObject_V5(currentView, @"右列视图");
                return; // 找到后就停止查找
            }
        }
    }
}

%end
