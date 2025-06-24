#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 辅助函数：递归查找手势
static void FindGesturesOfTypeRecursive(Class gestureClass, UIView *view, NSMutableArray *storage) {
    for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
        if ([gesture isKindOfClass:gestureClass]) {
            [storage addObject:gesture];
        }
    }
    for (UIView *subview in view.subviews) {
        FindGesturesOfTypeRecursive(gestureClass, subview, storage);
    }
}

%hook UIViewController

// --- 注入最终的诊断按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = self.view.window; if (!window) return;
            NSInteger buttonTag = 777;
            [[window viewWithTag:buttonTag] removeFromSuperview];
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(self.view.center.x - 120, 50, 240, 44);
            button.tag = buttonTag;
            [button setTitle:@"运行'位'属性最终诊断" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            button.backgroundColor = [UIColor systemIndigoColor];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.layer.cornerRadius = 22;
            [button addTarget:self action:@selector(runFinalTypeDiagnostics) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:button];
        });
    }
}

%new
- (void)runFinalTypeDiagnostics {
    NSMutableString *report = [NSMutableString string];
    [report appendString:@"'位' 属性 - 终极类型诊断报告\n==========================\n\n"];

    Class gestureClass = NSClassFromString(@"_TtCC12六壬大占14ViewController18課傳觸摸手勢");
    if (!gestureClass) {
        [report appendString:@"错误：找不到手势类 _TtCC...課傳觸摸手勢"];
    } else {
        // 1. 获取 '位' 这个实例变量的定义 (Ivar)
        Ivar weiIvar = class_getInstanceVariable(gestureClass, "位");
        
        if (!weiIvar) {
            [report appendString:@"错误：在手势类中找不到 '位' 实例变量。\n"];
        } else {
            // 2. 获取 '位' 的类型编码
            const char *typeEncoding = ivar_getTypeEncoding(weiIvar);
            [report appendFormat:@"'位' 的类型编码 (Type Encoding):\n%s\n\n", typeEncoding];

            // 3. 查找所有手势实例，并检查它们 '位' 属性的实际值
            NSMutableArray *allGestures = [NSMutableArray array];
            FindGesturesOfTypeRecursive(gestureClass, self.view, allGestures);
            
            if (allGestures.count > 0) {
                [report appendFormat:@"找到 %lu 个手势实例。检查它们 '位' 属性的当前值：\n\n", (unsigned long)allGestures.count];
                int count = 0;
                for (UIGestureRecognizer *gesture in allGestures) {
                    // 使用KVC读取 '位' 属性的值
                    id weiValue = [gesture valueForKey:@"位"];
                    NSString *valueDescription;
                    if (weiValue == nil) {
                        valueDescription = @"值为 nil";
                    } else {
                        valueDescription = [NSString stringWithFormat:@"值的类是: %@", NSStringFromClass([weiValue class])];
                    }
                    [report appendFormat:@"手势 #%d: %@\n", ++count, valueDescription];
                }
            } else {
                [report appendString:@"未能在视图中找到任何手势实例。\n"];
            }
        }
    }

    // 显示报告
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"诊断报告" message:report preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"复制并关闭" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        [UIPasteboard generalPasteboard].string = report;
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
