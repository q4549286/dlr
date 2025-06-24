#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog(@"[KeChuan-Detective] " format, ##__VA_ARGS__)

static NSInteger const DetectiveButtonTag = 556699;

// --- 辅助函数 ---
static id GetIvarFromObject(id object, const char *ivarName) { Ivar ivar = class_getInstanceVariable([object class], ivarName); if (ivar) { return object_getIvar(object, ivar); } return nil; }

@interface UIViewController (EchoAIDetective)
- (void)runDetectiveWork;
@end

%hook UIViewController
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            [[keyWindow viewWithTag:DetectiveButtonTag] removeFromSuperview];
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(keyWindow.bounds.size.width - 160, 45 + 120, 150, 36);
            button.tag = DetectiveButtonTag;
            [button setTitle:@"执行侦查" forState:UIControlStateNormal];
            button.backgroundColor = [UIColor systemRedColor];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.layer.cornerRadius = 8;
            [button addTarget:self action:@selector(runDetectiveWork) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:button];
        });
    }
}

%new
- (void)runDetectiveWork {
    EchoLog(@"--- 开始执行最终侦查 ---");
    id mainVC = self;
    
    const char *ivarName = "課傳";
    id keChuanModel = GetIvarFromObject(mainVC, ivarName);

    if (keChuanModel) {
        // 【关键步骤】
        // 1. 打印这个对象的类名
        NSString *className = NSStringFromClass([keChuanModel class]);
        EchoLog(@"成功获取 '課傳' 对象！它的类名是: %@", className);

        // 2. 尝试打印它的所有属性和实例变量
        unsigned int propCount;
        objc_property_t *properties = class_copyPropertyList([keChuanModel class], &propCount);
        NSMutableString *propLog = [NSMutableString stringWithString:@"\n--- 它的属性 (Properties) ---\n"];
        for (unsigned int i = 0; i < propCount; i++) {
            objc_property_t property = properties[i];
            const char *name = property_getName(property);
            [propLog appendFormat:@"? %s\n", name];
        }
        free(properties);
        EchoLog(@"%@", propLog);

        unsigned int ivarCount;
        Ivar *ivars = class_copyIvarList([keChuanModel class], &ivarCount);
        NSMutableString *ivarLog = [NSMutableString stringWithString:@"\n--- 它的实例变量 (Ivars) ---\n"];
        for (unsigned int i = 0; i < ivarCount; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            [ivarLog appendFormat:@"? %s\n", name];
        }
        free(ivars);
        EchoLog(@"%@", ivarLog);
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"侦查完成" message:[NSString stringWithFormat:@"'課傳' 对象的类名是: %@\n\n请查看Xcode日志获取详细信息。", className] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

    } else {
        EchoLog(@"错误: 未能从主VC获取 '課傳' 对象。");
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"侦查失败" message:@"未能获取 '課傳' 对象。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}
%end
