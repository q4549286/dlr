#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// --- 辅助函数 ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
//  主逻辑
// =========================================================================

%hook UIViewController

// 1. 添加触发按钮
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            // 避免重复添加
            if ([keyWindow viewWithTag:778899]) return;

            UIButton *detectButton = [UIButton buttonWithType:UIButtonTypeSystem];
            detectButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 85, 140, 36);
            detectButton.tag = 778899;
            [detectButton setTitle:@"探测课体函数" forState:UIControlStateNormal];
            detectButton.backgroundColor = [UIColor colorWithRed:0.5 green:0.2 blue:0.8 alpha:1.0]; // 紫色
            [detectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            detectButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            detectButton.layer.cornerRadius = 8;
            [detectButton addTarget:self action:@selector(detectKeTiFunction) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:detectButton];
        });
    }
}

// 2. 新增的探测方法
%new
- (void)detectKeTiFunction {
    NSLog(@"[Detector] 开始探测课体视图的点击事件...");

    // 目标视图的类名
    Class keTiViewClass = NSClassFromString(@"六壬大占.課體視圖");
    if (!keTiViewClass) {
        [self showDetectionResultWithTitle:@"探测失败" message:@"找不到类: 六壬大占.課體視圖"];
        return;
    }

    // 在当前视图控制器中寻找该视图
    NSMutableArray *foundViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(keTiViewClass, self.view, foundViews);

    if (foundViews.count == 0) {
        [self showDetectionResultWithTitle:@"探测失败" message:@"在当前界面上找不到课体视图的实例。"];
        return;
    }

    UIView *keTiView = foundViews.firstObject;
    NSLog(@"[Detector] 成功找到课体视图: %@", keTiView);

    // 获取视图上的手势识别器
    NSArray<UIGestureRecognizer *> *gestures = keTiView.gestureRecognizers;
    if (gestures.count == 0) {
        [self showDetectionResultWithTitle:@"探测失败" message:@"课体视图上没有任何手势识别器。"];
        return;
    }

    NSMutableString *resultString = [NSMutableString string];

    // 遍历所有手势
    for (UIGestureRecognizer *gesture in gestures) {
        NSLog(@"[Detector] 检查手势: %@", gesture.class);
        [resultString appendFormat:@"手势类型: %@\n", NSStringFromClass(gesture.class)];

        // 使用KVC黑魔法获取内部存储的目标-动作对
        // 这是逆向工程中的常用技巧
        id targets = [gesture valueForKey:@"_targets"];
        if (!targets || ![targets respondsToSelector:@selector(count)] || [targets count] == 0) {
            [resultString appendString:@"  - 未找到任何目标(target)。\n\n"];
            continue;
        }

        for (id targetObj in targets) {
            // 获取目标对象
            id target = [targetObj valueForKey:@"target"];
            // 获取方法(SEL)
            SEL action = [[targetObj valueForKey:@"action"] pointerValue];

            NSString *targetClassName = NSStringFromClass([target class]);
            NSString *actionString = NSStringFromSelector(action);

            NSLog(@"[Detector] -> 找到目标: %@, 方法: %@", targetClassName, actionString);
            
            [resultString appendFormat:@"  - 目标类名: %@\n", targetClassName];
            [resultString appendFormat:@"  - 方法名(Selector): %@\n\n", actionString];
        }
    }
    
    [self showDetectionResultWithTitle:@"探测结果" message:resultString];
}

%new
- (void)showDetectionResultWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"复制并关闭" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [UIPasteboard generalPasteboard].string = message;
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
