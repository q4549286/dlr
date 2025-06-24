#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 我们不再需要任何辅助函数，任何全局变量。
// 只有最纯粹、最简单的Hook。

// =========================================================================
// 核心审判逻辑：我们只Hook一个绝对会执行的方法：viewDidLoad
// =========================================================================
%hook 六壬大占.ViewController

- (void)viewDidLoad {
    // 必须先调用原始实现，否则App会直接黑屏
    %orig;

    // 【【【终极存在性证明】】】
    // 在视图加载后，立即弹出一个无法被忽略的、证明Tweak存在的弹窗。
    // 这里没有任何复杂的逻辑，没有任何可能失败的变量。
    // 如果这个弹窗都没有出现，就意味着Tweak本身没有被加载。
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Tweak存在性证明"
                                                                   message:@"如果您看到了这个弹窗，证明Tweak本身【已经成功加载】，并且对'viewDidLoad'的Hook是【有效的】。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"收到" style:UIAlertActionStyleDefault handler:nil]];

    // 我们需要确保在主线程上显示它
    dispatch_async(dispatch_get_main_queue(), ^{
        // 使用 rootViewController 来呈现，这是最可靠的方式
        [[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:alert animated:YES completion:nil];
    });
}

%end
