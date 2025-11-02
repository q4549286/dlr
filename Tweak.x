#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 核心 Hook
// =========================================================================

// --- Hook 1: 监控 Popover 的创建 ---
%hook UIPopoverPresentationController
- (id)initWithPresentedViewController:(UIViewController *)presentedViewController presentingViewController:(UIViewController *)presentingViewController {
    NSLog(@"[全链路侦察兵] ==> 步骤 2: PopoverPresentationController 正在创建...");
    NSLog(@"[全链路侦察兵]      Presented VC: %@", NSStringFromClass([presentedViewController class]));
    return %orig;
}
- (void)setSourceView:(UIView *)sourceView {
    NSLog(@"[全链路侦察兵] ==> 步骤 3: 设置 SourceView: <%@: %p>", NSStringFromClass([sourceView class]), sourceView);
    %orig;
}
- (void)setSourceRect:(CGRect)sourceRect {
    NSLog(@"[全链路侦察兵] ==> 步骤 4: 设置 SourceRect: %@", NSStringFromCGRect(sourceRect));
    %orig;
}
%end

// --- Hook 2: 监控最终的呈现动作 ---
%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    NSLog(@"[全链路侦察兵] ==> 步骤 5: UIViewController presentViewController 被调用。");
    %orig;
}
%end

// --- Hook 3: 监控事件的起点 ---
static void (*Original_ViewController_顯示天地盤觸摸WithSender)(id, SEL, id);

static void Tweak_ViewController_顯示天地盤觸摸WithSender(id self, SEL _cmd, id sender) {
    NSLog(@"[全链路侦察兵] ==================== 真实点击事件链路追踪 ====================");
    NSLog(@"[全链路侦察兵] ==> 步骤 1: '顯示天地盤觸摸WithSender:' 被触发。");
    
    if ([sender isKindOfClass:[UIGestureRecognizer class]]) {
        UIGestureRecognizer *gesture = (UIGestureRecognizer *)sender;
        
        NSLog(@"[全链路侦察兵]     Sender Class: %@", NSStringFromClass([gesture class]));
        NSLog(@"[全链路侦察兵]     Sender State: %ld", (long)gesture.state);
        NSLog(@"[全链路侦察兵]     Sender View: <%@: %p>",  NSStringFromClass([gesture.view class]), gesture.view);
        NSLog(@"[全链路侦察兵]     Sender LocationInView: %@", NSStringFromCGPoint([gesture locationInView:gesture.view]));
        
        @try {
            NSSet *touches = [gesture valueForKey:@"touches"];
            if (touches && touches.count > 0) {
                UITouch *touch = [touches anyObject];
                NSLog(@"[全链路侦察兵]     - Touch Phase: %ld", (long)touch.phase);
                NSLog(@"[全链路侦察兵]     - Touch LocationInWindow: %@", NSStringFromCGPoint([touch locationInView:touch.window]));
            }
        } @catch (NSException *exception) {
            NSLog(@"[全链路侦察兵]     - 获取 touches 失败: %@", exception.reason);
        }
    }
    
    // 调用原始方法，让事件链继续
    Original_ViewController_顯示天地盤觸摸WithSender(self, _cmd, sender);

    NSLog(@"[全链路侦察兵] ========================= 链路追踪结束 =========================");
}


%ctor {
    @autoreleasepool {
        Class vcClass = NSClassFromString(@"六壬大占.ViewController");
        if (vcClass) {
             SEL originalSelector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
             MSHookMessageEx(vcClass, originalSelector, (IMP)Tweak_ViewController_顯示天地盤觸摸WithSender, (IMP *)&Original_ViewController_顯示天地盤觸摸WithSender);
             NSLog(@"[全链路侦察兵] 已加载。请手动点击天地盘以触发日志。");
        } else {
             NSLog(@"[全链路侦察兵] 错误: 找不到 ViewController 类。");
        }
    }
}
