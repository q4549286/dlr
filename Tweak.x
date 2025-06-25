#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// --- 辅助函数 ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
//  接口声明 (修复编译错误的关键)
// =========================================================================
@interface UIViewController (KeTiDetector)
- (void)detectKeTiFunction;
- (void)showDetectionResultWithTitle:(NSString *)title message:(NSString *)message;
@end


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
    [resultString appendString:@"侦测到以下点击事件:\n\n"];

    // 遍历所有手势
    for (UIGestureRecognizer *gesture in gestures) {
        NSLog(@"[Detector] 检查手势: %@", gesture.class);
        
        // 使用KVC黑魔法获取内部存储的目标-动作对
        id targets = [gesture valueForKey:@"_targets"];
        if (!targets || ![targets respondsToSelector:@selector(count)] || [targets count] == 0) {
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
            
            [resultString appendFormat:@"▶︎ 目标类: %@\n", targetClassName];
            [resultString appendFormat:@"▶︎ 方法名(Selector): %@\n\n", actionString];
        }
    }
    
    if (resultString.length > 20) { // 确保真的找到了东西
        [self showDetectionResultWithTitle:@"探测成功！" message:resultString];
    } else {
        [self showDetectionResultWithTitle:@"探测失败" message:@"在课体视图的手势中未能找到任何有效的目标-动作对。"];
    }
}

%new
- (void)showDetectionResultWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    // 创建一个UITextView来显示，这样可以滚动和选择文本
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectZero];
    textView.text = message;
    textView.editable = NO;
    textView.backgroundColor = [UIColor clearColor];
    textView.font = [UIFont systemFontOfSize:13];
    
    // 把textView放到alertController里面，这也是个小技巧
    [alert setValue:textView forKey:@"accessoryView"];

    [alert addAction:[UIAlertAction actionWithTitle:@"复制信息" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [UIPasteboard generalPasteboard].string = message;
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
    
    // 适配一下TextView的大小
    [self presentViewController:alert animated:YES completion:^{
        // 调整 accessoryView 的高度
        CGRect newFrame = alert.view.bounds;
        newFrame.size.height = 250.0; // 可以根据需要调整
        alert.view.bounds = newFrame;
    }];
}

%end
