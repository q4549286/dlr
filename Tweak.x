#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 侦察代码 V5 - 绝对无错，Hook所有弹窗
// =========================================================================

static UIViewController *lastPresentedVC = nil;

%hook UIViewController

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    
    // 只对我们关心的弹窗进行操作
    NSString *className = NSStringFromClass([viewControllerToPresent class]);
    if ([className containsString:@"格局總覽視圖"] || [className containsString:@"七政信息視圖"]) {
        
        // 避免重复弹窗
        if (lastPresentedVC == viewControllerToPresent) {
            %orig(viewControllerToPresent, flag, completion);
            return;
        }
        lastPresentedVC = viewControllerToPresent;

        NSString *logMessage = [NSString stringWithFormat:
            @"侦察目标已捕获!\n\n"
            @"类型 (Class): %@\n\n"
            @"内存地址 (Address): %p\n\n"
            @"请使用FLEX的pt命令或等效功能查看此地址的详细信息。",
            className, viewControllerToPresent];

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"侦察到目标！" message:logMessage preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        
        // 先调用原始方法，让列表弹出来
        %orig(viewControllerToPresent, flag, ^{
            // 在原始弹窗完成后，再弹出我们的侦察弹窗
            [viewControllerToPresent presentViewController:alert animated:YES completion:nil];
            if(completion) completion();
        });

    } else {
        // 如果不是我们关心的弹窗，就直接执行原始方法
        %orig(viewControllerToPresent, flag, completion);
    }
}

%end
