#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 核心 Hook (这次只 Hook UIKit 的标准方法)
// =========================================================================

%hook UIViewController

// 监控所有 ViewController 的创建
- (id)init {
    id result = %orig;
    // 只打印我们关心的 App 内部的 VC
    if ([NSStringFromClass([self class]) containsString:@"六壬大占"]) {
        NSLog(@"[广撒网侦察兵] ==> VC 被创建: %@", NSStringFromClass([self class]));
    }
    return result;
}

- (id)initWithCoder:(NSCoder *)coder {
    id result = %orig(coder);
    if ([NSStringFromClass([self class]) containsString:@"六壬大占"]) {
        NSLog(@"[广撒网侦察兵] ==> VC 被创建 (from Storyboard/XIB): %@", NSStringFromClass([self class]));
    }
    return result;
}


// 监控所有 ViewController 的呈现
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    NSLog(@"[广撒网侦察兵] ==================== 弹窗呈现事件 ====================");
    NSLog(@"[广撒网侦察兵] Presenting VC: %@", NSStringFromClass([self class]));
    NSLog(@"[广撒网侦察兵] Presented VC: %@", NSStringFromClass([viewControllerToPresent class]));
    NSLog(@"[广撒网侦察兵] Presentation Style: %ld", (long)viewControllerToPresent.modalPresentationStyle);

    // 如果是 Popover，打印出所有关键信息
    UIPopoverPresentationController *popover = viewControllerToPresent.popoverPresentationController;
    if (popover) {
        NSLog(@"[广撒网侦察兵] --- Popover Details ---");
        NSLog(@"[广撒网侦察兵] Source View: <%@: %p>", NSStringFromClass([popover.sourceView class]), popover.sourceView);
        NSLog(@"[广撒网侦察兵] Source Rect: %@", NSStringFromCGRect(popover.sourceRect));
        NSLog(@"[广撒网侦察兵] Permitted Arrow Directions: %lu", (unsigned long)popover.permittedArrowDirections);
        NSLog(@"[广撒网侦察兵] Delegate: %@", popover.delegate);
    }
    
    NSLog(@"[广撒网侦察兵] ===================================================");

    %orig(viewControllerToPresent, flag, completion);
}

%end


%ctor {
    NSLog(@"[广撒网侦察兵] 已加载。请手动点击天地盘上的任意元素。");
}
