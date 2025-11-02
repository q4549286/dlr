#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 核心 Hook
// =========================================================================
static void (*Original_ViewController_顯示天地盤觸摸WithSender)(id, SEL, id);

static void Tweak_ViewController_顯示天地盤觸摸WithSender(id self, SEL _cmd, id sender) {
    NSLog(@"[蓝图侦察兵] ==================== 真实点击事件捕获 ====================");
    
    if ([sender isKindOfClass:[UIGestureRecognizer class]]) {
        UIGestureRecognizer *gesture = (UIGestureRecognizer *)sender;
        
        NSLog(@"[蓝图侦察兵] *** GESTURE PUBLIC PROPERTIES ***");
        NSLog(@"[蓝图侦察兵] Class: %@", NSStringFromClass([gesture class]));
        NSLog(@"[蓝图侦察兵] State: %ld", (long)gesture.state);
        NSLog(@"[蓝图侦察兵] View: %@", gesture.view);
        NSLog(@"[蓝图侦察兵] Window: %@", gesture.view.window);
        NSLog(@"[蓝图侦察兵] NumberOfTouches: %lu", (unsigned long)gesture.numberOfTouches);
        
        if (gesture.view) {
            NSLog(@"[蓝图侦察兵] LocationInView: %@", NSStringFromCGPoint([gesture locationInView:gesture.view]));
        }
        
        NSLog(@"[蓝图侦察兵] *** GESTURE PRIVATE IVARS (via KVC) ***");
        @try {
            id targets = [gesture valueForKey:@"_targets"];
            NSLog(@"[蓝图侦察兵] _targets: %@", targets);
            
            id touches = [gesture valueForKey:@"touches"];
            NSLog(@"[蓝图侦察兵] touches (KVC): %@", touches);
            
            if (touches && [touches isKindOfClass:[NSSet class]] && ((NSSet *)touches).count > 0) {
                UITouch *touch = [((NSSet *)touches) anyObject];
                NSLog(@"[蓝图侦察兵] --- TOUCH DETAILS ---");
                NSLog(@"[蓝图侦察兵] Touch Class: %@", NSStringFromClass([touch class]));
                NSLog(@"[蓝图侦察兵] Touch Phase: %ld", (long)touch.phase);
                NSLog(@"[蓝图侦察兵] Touch TapCount: %lu", (unsigned long)touch.tapCount);
                NSLog(@"[蓝图侦察兵] Touch View: %@", touch.view);
                NSLog(@"[蓝图侦察兵] Touch Window: %@", touch.window);

                // <<<< 核心修复点 >>>>
                if (touch.window) {
                     NSLog(@"[蓝图侦察兵] Touch LocationInWindow (Corrected): %@", NSStringFromCGPoint([touch locationInView:touch.window]));
                }
                
                // 尝试读取私有变量
                id touchLocationInWindow = [touch valueForKey:@"_locationInWindow"];
                NSLog(@"[蓝图侦察兵] Touch _locationInWindow (KVC): %@", touchLocationInWindow);
            }
        } @catch (NSException *exception) {
            NSLog(@"[蓝图侦察兵] KVC Error: %@", exception.reason);
        }
    } else {
        NSLog(@"[蓝图侦察兵] Sender is not a UIGestureRecognizer: %@", sender);
    }
    
    NSLog(@"[蓝图侦察兵] ======================= 捕获结束 =======================");

    Original_ViewController_顯示天地盤觸摸WithSender(self, _cmd, sender);
}

%ctor {
    @autoreleasepool {
        Class vcClass = NSClassFromString(@"六壬大占.ViewController");
        if (vcClass) {
             SEL originalSelector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
             MSHookMessageEx(vcClass, originalSelector, (IMP)Tweak_ViewController_顯示天地盤觸摸WithSender, (IMP *)&Original_ViewController_顯示天地盤觸摸WithSender);
             NSLog(@"[蓝图侦察兵V3] 已加载。请手动点击天地盘以触发日志。");
        } else {
             NSLog(@"[蓝图侦察兵V3] 错误: 找不到 ViewController 类。");
        }
    }
}
