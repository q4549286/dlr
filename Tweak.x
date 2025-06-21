#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 终极侦察代码：Hook列表视图控制器，直接看它的数据源
// =========================================================================

// 一个辅助函数，用于获取一个对象的所有属性和变量详情
static NSString* getObjectDetails(id obj, NSString *objName) {
    if (!obj) return [NSString stringWithFormat:@"%@ is nil.\n", objName];

    NSMutableString *details = [NSMutableString stringWithFormat:@"--- Details for %@ (%@) ---\n", objName, [obj class]];
    
    // 打印属性
    unsigned int propCount;
    objc_property_t *properties = class_copyPropertyList([obj class], &propCount);
    [details appendString:@"\n--- PROPERTIES ---\n"];
    for (int i = 0; i < propCount; i++) {
        NSString *propName = [NSString stringWithUTF8String:property_getName(properties[i])];
        id value = nil;
        @try { value = [obj valueForKey:propName]; } @catch (NSException *e) { value = @"(Access Exception)"; }
        [details appendFormat:@"%@ = %@\n", propName, value];
    }
    free(properties);

    // 打印实例变量
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([obj class], &ivarCount);
    [details appendString:@"\n--- IVARS ---\n"];
    for (int i = 0; i < ivarCount; i++) {
        NSString *ivarName = [NSString stringWithUTF8String:ivar_getName(ivars[i])];
        id value = nil;
        @try { value = [obj valueForKey:ivarName]; } @catch (NSException *e) { value = @"(Access Exception)"; }
        [details appendFormat:@"%@ = %@\n", ivarName, value];
    }
    free(ivars);

    return details;
}


// Hook "格局总览" 视图控制器
%hook 六壬大占_格局總覽視圖

// 当这个列表视图控制器被创建时 (init)，我们就检查它的数据
- (id)initWithCoder:(NSCoder *)coder {
    id instance = %orig; // 先让它完成初始化

    // 延迟执行，确保数据已经被设置
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSMutableString *fullLog = [NSMutableString string];
        
        // 打印这个列表视图控制器自身的信息
        [fullLog appendString:getObjectDetails(instance, @"格局總覽視圖 (self)")];
        
        // 额外尝试：检查是否存在一个叫 '排盘' 的属性
        if ([instance respondsToSelector:@selector(排盘)]) {
             id paiPanObj = [instance performSelector:@selector(排盘)];
             [fullLog appendString:@"\n\n"];
             [fullLog appendString:getObjectDetails(paiPanObj, @"排盘 Object")];
        }

        // 用弹窗显示所有日志
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"数据源侦察" message:fullLog preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    keyWindow = scene.windows.firstObject;
                    break;
                }
            }
        } else {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            keyWindow = UIApplication.sharedApplication.keyWindow;
            #pragma clang diagnostic pop
        }
        [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    });
    
    return instance;
}

%end


// Hook "七政信息" 视图控制器 (逻辑同上)
%hook 六壬大占_七政信息視圖

- (id)initWithCoder:(NSCoder *)coder {
    id instance = %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *log = getObjectDetails(instance, @"七政信息視圖 (self)");
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"数据源侦察" message:log preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        // ... (显示弹窗的代码，同上)
    });
    return instance;
}

%end
