#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 终极侦察代码 V2 - 已修复所有编译错误
// =========================================================================

// 全局变量，确保日志只显示一次
static BOOL hasLogged = NO;

// 一个辅助函数，用于获取一个对象的所有属性和变量详情
static NSString* getObjectDetails(id obj, NSString *objName) {
    if (!obj) return [NSString stringWithFormat:@"%@ is nil.\n", objName];

    NSMutableString *details = [NSMutableString stringWithFormat:@"--- Details for %@ (%@) ---\n", objName, [obj class]];
    
    // 打印属性
    unsigned int propCount;
    objc_property_t *properties = class_copyPropertyList([obj class], &propCount);
    [details appendString:@"\n--- PROPERTIES ---\n"];
    if (propCount == 0) { [details appendString:@"(No properties found)\n"]; }
    for (int i = 0; i < propCount; i++) {
        NSString *propName = [NSString stringWithUTF8String:property_getName(properties[i])];
        id value = nil;
        @try { value = [obj valueForKey:propName]; } @catch (NSException *e) { value = @"(Access Exception)"; }
        [details appendFormat:@"@property %@ = %@\n", propName, value];
    }
    free(properties);

    // 打印实例变量
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([obj class], &ivarCount);
    [details appendString:@"\n--- IVARS ---\n"];
    if (ivarCount == 0) { [details appendString:@"(No ivars found)\n"]; }
    for (int i = 0; i < ivarCount; i++) {
        NSString *ivarName = [NSString stringWithUTF8String:ivar_getName(ivars[i])];
        id value = nil;
        @try { value = [obj valueForKey:ivarName]; } @catch (NSException *e) { value = @"(Access Exception)"; }
        [details appendFormat:@"ivar %@ = %@\n", ivarName, value];
    }
    free(ivars);

    return details;
}


// 我们Hook "格局总览" 视图控制器，当它出现时，检查它和它的数据源
%hook 六壬大占_格局總覽視圖

// - (void)viewDidLoad { // viewDidLoad可能太早，数据还没加载
//     %orig;
// }

// viewDidAppear 是一个更晚、更可靠的时机
- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (hasLogged) return;
    hasLogged = YES;

    // 延迟一点点，确保万无一失
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSMutableString *fullLog = [NSMutableString string];
        
        // 1. 打印这个列表视图控制器自身的信息
        [fullLog appendString:getObjectDetails(self, @"格局總覽視圖 (self)")];
        
        // 2. 尝试获取并打印一个名为 "排盘" 的属性，这是最可疑的数据源
        if ([self respondsToSelector:@selector(排盘)]) {
            id paiPanObj = [self performSelector:@selector(排盘)];
            [fullLog appendString:@"\n\n====================\n\n"];
            [fullLog appendString:getObjectDetails(paiPanObj, @"排盘 Object")];
        }

        // 用弹窗显示所有日志
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"数据源侦察" message:fullLog preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            hasLogged = NO; // 关闭弹窗后可以再次触发，方便调试
        }]];
        
        [self presentViewController:alert animated:YES completion:nil];
    });
}

%end
