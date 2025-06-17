#import <UIKit/UIKit.h>

// 我们Hook所有视图控制器的基类，这样就能影响App里的每一个页面
%hook UIViewController

// 这个方法返回一个布尔值(YES/NO)来决定是否隐藏状态栏
- (BOOL)prefersStatusBarHidden {
    // 不管App原来想干什么，我们都告诉系统：“不要隐藏状态栏！”
    return NO;
}

// 有些复杂的App会用这个方法来指定由哪个子控制器决定状态栏样式
// 我们把它也一并处理，确保我们的修改能生效
- (UIViewController *)childViewControllerForStatusBarHidden {
    // 返回nil，让系统回头去问UIViewController自己，而我们已经Hook了它
    return nil;
}

%end
