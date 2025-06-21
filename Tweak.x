#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 侦察专用代码 V2 - 在更可靠的时机触发
// =========================================================================

// 全局变量，确保日志只显示一次
static BOOL hasLogged = NO;

// 声明一个方法，我们将在多个地方调用它
void showLoggingAlertForViewController(UIViewController *vc);

// 日志生成和显示的核心函数
void showLoggingAlertForViewController(UIViewController *vc) {
    // 防止重复触发
    if (hasLogged) return;
    hasLogged = YES;

    NSMutableString *logMessage = [NSMutableString string];
    [logMessage appendString:@"--- Logging ViewController Details ---\n\n"];
    [logMessage appendFormat:@"Triggered by: %@\n", [vc class]];
    [logMessage appendFormat:@"ViewController Instance: %@\n\n", vc];

    id targetObject = vc;

    // --- 打印属性 (Properties) ---
    [logMessage appendString:@"--- PROPERTIES ---\n"];
    unsigned int propCount;
    objc_property_t *properties = class_copyPropertyList([targetObject class], &propCount);
    if (propCount == 0) { [logMessage appendString:@"(No properties found)\n"]; }
    for (int i = 0; i < propCount; i++) {
        objc_property_t property = properties[i];
        const char *propName = property_getName(property);
        if (propName) {
            NSString *propertyName = [NSString stringWithUTF8String:propName];
            id value = nil;
            @try { value = [targetObject valueForKey:propertyName]; } @catch (NSException *exception) { value = @"(Access Exception)"; }
            [logMessage appendFormat:@"@property: %@ = %@\n", propertyName, value];
        }
    }
    free(properties);
    [logMessage appendString:@"\n"];

    // --- 打印实例变量 (Ivars) ---
    [logMessage appendString:@"--- IVARS ---\n"];
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([targetObject class], &ivarCount);
    if (ivarCount == 0) { [logMessage appendString:@"(No ivars found)\n"]; }
    for (int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *ivarName = ivar_getName(ivar);
        if (ivarName) {
            NSString *ivarNameStr = [NSString stringWithUTF8String:ivarName];
            id value = nil;
            @try { value = [targetObject valueForKey:ivarNameStr]; } @catch (NSException *exception) { value = @"(Access Exception)"; }
            [logMessage appendFormat:@"ivar: %@ = %@\n", ivarNameStr, value];
        }
    }
    free(ivars);

    // --- 创建并显示弹窗 ---
    // 确保在主线程上显示UI
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"侦察日志 V2" message:logMessage preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:okAction];
        
        // 找到最顶层的VC来呈现弹窗
        UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
        UIViewController *rootVC = keyWindow.rootViewController;
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}


// 我们Hook一个很晚才会出现的视图的 `didMoveToWindow` 方法
// “三传视图” (`六壬大占.傳視圖`) 是一个很好的目标
%hook UIView 

- (void)didMoveToWindow {
    %orig;
    
    // 当这个视图是“三传视图”时
    if ([self isKindOfClass:NSClassFromString(@"六壬大占.傳視圖")]) {
        // 向上遍历视图层级，找到它所属的 ViewController
        UIResponder *responder = self;
        while ((responder = [responder nextResponder])) {
            if ([responder isKindOfClass:[UIViewController class]]) {
                // 找到了！触发日志弹窗
                showLoggingAlertForViewController((UIViewController *)responder);
                break;
            }
        }
    }
}

%end
