#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量
// =========================================================================
static NSMutableArray<NSString *> *g_recordedCoordinates = nil;

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (CoordinateRecorder)
- (void)toggleCoordinateRecordingMode;
@end

// 自定义一个 Window 类来拦截触摸事件
%hook UIWindow

- (void)sendEvent:(UIEvent *)event {
    if (g_recordedCoordinates != nil && event.type == UIEventTypeTouches) {
        NSSet<UITouch *> *touches = [event allTouches];
        UITouch *touch = [touches anyObject];

        if (touch.phase == UITouchPhaseBegan) {
            CGPoint location = [touch locationInView:self];
            
            // 记录坐标
            NSString *coordString = [NSString stringWithFormat:@"(%.2f, %.2f)", location.x, location.y];
            [g_recordedCoordinates addObject:coordString];
            
            NSLog(@"[坐标记录器] 已记录坐标 #%lu: %@", (unsigned long)g_recordedCoordinates.count, coordString);
            
            // 在屏幕上显示一个视觉反馈
            UIView *feedbackCircle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
            feedbackCircle.center = location;
            feedbackCircle.backgroundColor = [UIColor.redColor colorWithAlphaComponent:0.5];
            feedbackCircle.layer.cornerRadius = 20;
            feedbackCircle.layer.borderColor = UIColor.whiteColor.CGColor;
            feedbackCircle.layer.borderWidth = 2;
            [self addSubview:feedbackCircle];
            
            // 更新按钮标题
            UIViewController *rootVC = self.rootViewController;
            if ([rootVC isKindOfClass:NSClassFromString(@"UINavigationController")]) {
                rootVC = [(UINavigationController *)rootVC viewControllers].firstObject;
            }
            UIButton *button = [rootVC.view.window viewWithTag:556692];
            if (button) {
                [button setTitle:[NSString stringWithFormat:@"已记录 %lu 点", (unsigned long)g_recordedCoordinates.count] forState:UIControlStateNormal];
            }

            [UIView animateWithDuration:0.5 animations:^{
                feedbackCircle.transform = CGAffineTransformMakeScale(1.5, 1.5);
                feedbackCircle.alpha = 0;
            } completion:^(BOOL finished) {
                [feedbackCircle removeFromSuperview];
            }];
        }
    }

    %orig; // 继续传递事件，保证App正常响应
}

%end


%hook UIViewController

// --- viewDidLoad: 创建模式切换按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger buttonTag = 556692; // 新的Tag
            if ([keyWindow viewWithTag:buttonTag]) { [[keyWindow viewWithTag:buttonTag] removeFromSuperview]; }
            
            UIButton *recordButton = [UIButton buttonWithType:UIButtonTypeSystem];
            recordButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 36);
            recordButton.tag = buttonTag;
            [recordButton setTitle:@"开始记录坐标" forState:UIControlStateNormal];
            recordButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            recordButton.backgroundColor = [UIColor systemOrangeColor];
            [recordButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            recordButton.layer.cornerRadius = 8;
            [recordButton addTarget:self action:@selector(toggleCoordinateRecordingMode) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:recordButton];
        });
    }
}

%new
// --- 切换坐标记录模式 ---
- (void)toggleCoordinateRecordingMode {
    UIButton *button = [self.view.window viewWithTag:556692];

    if (g_recordedCoordinates != nil) {
        // --- 结束记录 ---
        
        // 拼接所有坐标，准备复制
        NSString *result = [g_recordedCoordinates componentsJoinedByString:@",\n"];
        result = [NSString stringWithFormat:@"@[\n%@\n]", result];
        [UIPasteboard generalPasteboard].string = result;
        
        // 提示用户
        NSString *message = [NSString stringWithFormat:@"记录结束！\n共 %lu 个坐标点已复制到剪贴板。\n\n请将内容发送给我。", (unsigned long)g_recordedCoordinates.count];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"操作完成" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

        [button setTitle:@"开始记录坐标" forState:UIControlStateNormal];
        button.backgroundColor = [UIColor systemOrangeColor];
        
        g_recordedCoordinates = nil; // 重置
        
    } else {
        // --- 开始记录 ---
        g_recordedCoordinates = [NSMutableArray array];
        
        [button setTitle:@"结束记录" forState:UIControlStateNormal];
        button.backgroundColor = [UIColor systemRedColor];
        
        NSString *instructions = @"请严格按顺序点击18个目标：\n\n"
                                 @"--- 三传 (6点) ---\n"
                                 @"1. 初传-地支\n2. 初传-天将\n"
                                 @"3. 中传-地支\n4. 中传-天将\n"
                                 @"5. 末传-地支\n6. 末传-天将\n\n"
                                 @"--- 四课 (12点) ---\n"
                                 @"7. 第一课-天盘(天将)\n"
                                 @"8. 第一课-天盘下地支\n"
                                 @"9. 第一课-地盘上地支\n"
                                 @"10. 第二课-天盘(天将)\n"
                                 @"11. 第二课-天盘下地支\n"
                                 @"12. 第二课-地盘上地支\n"
                                 @"13. 第三课-天盘(天将)\n"
                                 @"14. 第三课-天盘下地支\n"
                                 @"15. 第三课-地盘上地支\n"
                                 @"16. 第四课-天盘(天将)\n"
                                 @"17. 第四课-天盘下地支\n"
                                 @"18. 第四课-地盘上地支\n\n"
                                 @"如果某项不可点，请点其附近空白处。完成后再按此按钮。";

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"坐标记录已开启"
                                                                       message:instructions
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"我明白了" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}
%end
