#import <UIKit/UIKit.h>
#import <objc/runtime.h>

%hook UIViewController

// --- 注入一个侦察按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = self.view.window; if (!window) return;
            NSInteger buttonTag = 777777;
            [[window viewWithTag:buttonTag] removeFromSuperview];
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(10, 50, 180, 40);
            button.tag = buttonTag;
            [button setTitle:@"侦察手势属性" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:15];
            button.backgroundColor = [UIColor blueColor];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [button addTarget:self action:@selector(inspectGestureProperties) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:button];
        });
    }
}

%new
// --- 按钮的动作：侦察并显示属性 ---
- (void)inspectGestureProperties {
    Class gestureClass = NSClassFromString(@"_TtCC12六壬大占14ViewController18課傳觸摸手勢");
    if (!gestureClass) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"失败" message:@"无法找到手势类。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    __block UIGestureRecognizer *foundGesture = nil;
    
    // 【【【最终编译错误修复】】】
    // 使用 #pragma 来忽略本次无害的循环引用警告
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-retain-cycles"
    
    __block void (^findBlock)(UIView *);
    findBlock = ^(UIView *view) {
        if (foundGesture) return;
        for (UIGestureRecognizer *g in view.gestureRecognizers) {
            if ([g isKindOfClass:gestureClass]) {
                foundGesture = g;
                return;
            }
        }
        for (UIView *subview in view.subviews) {
            findBlock(subview);
        }
    };
    
    #pragma clang diagnostic pop

    findBlock(self.view);

    if (!foundGesture) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"失败" message:@"未找到任何手势对象实例。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    unsigned int count;
    objc_property_t *properties = class_copyPropertyList(gestureClass, &count);
    NSMutableString *resultString = [NSMutableString stringWithString:@"侦察到一个手势对象，其属性如下：\n\n"];
    for (unsigned int i = 0; i < count; i++) {
        objc_property_t property = properties[i];
        const char *name = property_getName(property);
        NSString *propertyName = [NSString stringWithUTF8String:name];
        @try {
            id value = [foundGesture valueForKey:propertyName];
            NSString *valueClass = value ? NSStringFromClass([value class]) : @"(null)";
            [resultString appendFormat:@"属性名: %@\n值: %@\n类型: %@\n\n", propertyName, value, valueClass];
        } @catch (NSException *exception) {
            [resultString appendFormat:@"属性名: %@\n值: (无法读取: %@)\n\n", propertyName, exception.reason];
        }
    }
    free(properties);

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"侦察报告" message:resultString preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"复制并关闭" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [UIPasteboard generalPasteboard].string = resultString;
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
%end
