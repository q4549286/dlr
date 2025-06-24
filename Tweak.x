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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = self.view.window; if (!window) return;
            NSInteger buttonTag = 111222333;
            [[window viewWithTag:buttonTag] removeFromSuperview];
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(self.view.center.x - 90, 50, 180, 40);
            button.tag = buttonTag;
            [button setTitle:@"运行最终诊断" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            button.backgroundColor = [UIColor blackColor];
            button.layer.borderColor = [UIColor whiteColor].CGColor;
            button.layer.borderWidth = 1.0;
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.layer.cornerRadius = 8;
            [button addTarget:self action:@selector(runFinalDiagnostics) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:button];
        });
    }
}

%new
- (void)runFinalDiagnostics {
    NSMutableString *report = [NSMutableString string];
    [report appendString:@"六壬大占 - 终极诊断报告\n========================\n\n"];

    // --- Part 1: 地标视图分析 (Landmark Analysis) ---
    [report appendString:@"--- 1. 地标视图坐标 ---\n"];
    Ivar keChuanIvar = class_getInstanceVariable([self class], "課傳");
    UIView *keChuanView = keChuanIvar ? object_getIvar(self, keChuanIvar) : nil;
    Ivar sanChuanIvar = keChuanView ? class_getInstanceVariable([keChuanView class], "三傳") : nil;
    UIView *sanChuanView = sanChuanIvar ? object_getIvar(keChuanView, sanChuanIvar) : nil;
    
    if (sanChuanView) {
        const char *ivars[] = {"初傳", "中傳", "末傳"};
        for (int i=0; i<3; ++i) {
            Ivar chuanIvar = class_getInstanceVariable([sanChuanView class], ivars[i]);
            UIView *chuanView = chuanIvar ? object_getIvar(sanChuanView, chuanIvar) : nil;
            if (chuanView) {
                CGRect frameInWindow = [chuanView.superview convertRect:chuanView.frame toView:nil];
                [report appendFormat:@"地标: %s\n  - 地址: %p\n  - 坐标: %@\n\n", ivars[i], chuanView, NSStringFromCGRect(frameInWindow)];
            } else {
                [report appendFormat:@"地标: %s (未找到视图对象)\n\n", ivars[i]];
            }
        }
    } else {
        [report appendString:@"未能找到'三传视图'，无法分析地标。\n\n"];
    }

    // --- Part 2: 手势分析 (Gesture Analysis) ---
    [report appendString:@"--- 2. 手势及附着视图坐标 ---\n"];
    Class gestureClass = NSClassFromString(@"_TtCC12六壬大占14ViewController18課傳觸摸手勢");
    if (gestureClass) {
        NSMutableArray *allGestures = [NSMutableArray array];
        FindGesturesOfTypeRecursive(gestureClass, self.view, allGestures);
        
        if (allGestures.count > 0) {
            [report appendFormat:@"共找到 %lu 个目标手势。\n\n", (unsigned long)allGestures.count];
            int gestureCount = 0;
            for (UIGestureRecognizer *gesture in allGestures) {
                UIView *gestureView = gesture.view;
                CGRect frameInWindow = [gestureView.superview convertRect:gestureView.frame toView:nil];
                [report appendFormat:@"手势 #%d\n  - 地址: %p\n  - 附着于 <%@: %p>\n  - 附着视图坐标: %@\n\n", ++gestureCount, gesture, NSStringFromClass([gestureView class]), gestureView, NSStringFromCGRect(frameInWindow)];
            }
        } else {
            [report appendString:@"在整个视图中未能找到任何目标手势对象。\n\n"];
        }
    } else {
        [report appendString:@"未能找到手势类 _TtCC...。\n\n"];
    }

    // --- Part 3: 显示报告 ---
    UITextView *textView = [[UITextView alloc] init];
    textView.text = report;
    textView.editable = NO;
    textView.font = [UIFont systemFontOfSize:12];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"\n\n\n\n\n\n\n\n\n\n\n\n诊断报告" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert.view addSubview:textView];
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    [textView.topAnchor constraintEqualToAnchor:alert.view.topAnchor constant:60].active = YES;
    [textView.bottomAnchor constraintEqualToAnchor:alert.view.bottomAnchor constant:-60].active = YES;
    [textView.leadingAnchor constraintEqualToAnchor:alert.view.leadingAnchor constant:15].active = YES;
    [textView.trailingAnchor constraintEqualToAnchor:alert.view.trailingAnchor constant:-15].active = YES;
    
    [alert addAction:[UIAlertAction actionWithTitle:@"复制并关闭" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        [UIPasteboard generalPasteboard].string = report;
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
