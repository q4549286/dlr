#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

%hook UIPopoverPresentationController

// Hook popover 的配置过程
- (id)initWithPresentedViewController:(UIViewController *)presentedViewController presentingViewController:(UIViewController *)presentingViewController {
    NSLog(@"[Popover偵察兵] UIPopoverPresentationController is being created!");
    NSLog(@"[Popover偵察兵]   - Presented VC: %@", NSStringFromClass([presentedViewController class]));
    NSLog(@"[Popover偵察兵]   - Presenting VC: %@", NSStringFromClass([presentingViewController class]));
    return %orig;
}

// Hook 关键属性的设置
- (void)setSourceView:(UIView *)sourceView {
    NSLog(@"[Popover偵察兵] setSourceView: %@", NSStringFromClass([sourceView class]));
    %orig;
}

- (void)setSourceRect:(CGRect)sourceRect {
    NSLog(@"[Popover偵察兵] setSourceRect: {{%.2f, %.2f}, {%.2f, %.2f}}", sourceRect.origin.x, sourceRect.origin.y, sourceRect.size.width, sourceRect.size.height);
    %orig;
}

- (void)setBarButtonItem:(UIBarButtonItem *)barButtonItem {
    NSLog(@"[Popover偵察兵] setBarButtonItem: %@", barButtonItem);
    %orig;
}

%end


%hook UIViewController

// 只是为了看看 present 方法有没有被调用
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    NSLog(@"[Popover偵察兵] UIViewController presentViewController is called.");
    NSLog(@"[Popover偵察兵]   - Modal Presentation Style: %ld", (long)viewControllerToPresent.modalPresentationStyle);
    
    // 检查是否有 popoverPresentationController
    if (viewControllerToPresent.popoverPresentationController) {
        NSLog(@"[Popover偵察兵]   - Found popoverPresentationController!");
    }
    
    %orig;
}

%end

%ctor {
    NSLog(@"[Popover偵察兵] 已加载，请手动点击天地盘以触发日志。");
}
