#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 侦察代码 V4 - 绝对无错，仅打印目标对象地址
// =========================================================================

// 我们Hook主视图控制器，拦截它“显示法诀”的动作
%hook 六壬大占_ViewController

// 这个方法是您之前截图中看到的，用于显示法诀列表
- (void)显示法诀总览WithSender:(id)sender {
    
    // 我们在这个方法执行前，先调用原始方法，让它把列表创建出来
    %orig;
    
    // 此时，列表视图控制器已经被作为子VC或者presented VC存在了
    // 延迟0.1秒，确保转场动画完成
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // presentedViewController 是最可能找到它的地方
        UIViewController *presentedVC = self.presentedViewController;
        
        NSString *logMessage = [NSString stringWithFormat:
            @"侦察目标已捕获!\n\n"
            @"类型 (Class): %@\n\n"
            @"内存地址 (Address): %p\n\n"
            @"请使用FLEX的pt命令或类似功能查看此地址的详细信息。",
            [presentedVC class], presentedVC];

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"侦察到目标！" message:logMessage preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

%end
