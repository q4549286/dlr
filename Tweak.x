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
        // ... 错误处理 ...
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"失败" message:@"无法找到手势类。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // 在整个视图中递归找到第一个该类型的UIGestureRecognizer
    __block UIGestureRecognizer *foundGesture = nil;
    
    // 【【【编译错误修复】】】
    // 声明一个 __block 类型的 block 变量
    __block void (^findBlock)(UIView *);
    // 定义 block 的实现
    findBlock = ^(UIView *view) {
        if (foundGesture) return; // 如果已经找到，就快速退出
        for (UIGestureRecognizer *g in view.gestureRecognizers) {
            if ([g isKindOfClass:gestureClass]) {
                foundGesture = g;
                return;
            }
        }
        for (UIView *subview in view.subviews) {
            // 在 block 内部安全地调用自身
            findBlock(subview);
        }
    };
    
    // 开始递归查找
    findBlock(self.view);

    if (!foundGesture) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"失败" message:@"未找到任何手势对象实例。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // 获取所有属性
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

    // 显示结果
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"侦察报告" message:resultString preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"复制并关闭" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [UIPasteboard generalPasteboard].string = resultString;
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
%end
