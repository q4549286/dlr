#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

%hook UIViewController

// 直接 Hook 目标方法
- (void)顯示天地盤觸摸WithSender:(UIGestureRecognizer *)sender {
    NSLog(@"[偵察兵] 目标方法被触发！");
    
    if ([sender isKindOfClass:[UITapGestureRecognizer class]]) {
        UITapGestureRecognizer *tapGesture = (UITapGestureRecognizer *)sender;
        
        // 打印所有我们关心的属性
        NSLog(@"[偵察兵] --- 真实点击的手势参数 ---");
        NSLog(@"[偵察兵] State: %ld", (long)tapGesture.state);
        NSLog(@"[偵察兵] Number of Touches: %lu", (unsigned long)tapGesture.numberOfTouches);
        
        // 使用 KVC 读取私有属性
        @try {
            CGPoint location = [[tapGesture valueForKey:@"_locationInView"] CGPointValue];
            NSLog(@"[偵察兵] _locationInView: {%.2f, %.2f}", location.x, location.y);
            
            id touches = [tapGesture valueForKey:@"touches"];
            NSLog(@"[偵察兵] touches (KVC): %@", touches);
            
            if ([touches isKindOfClass:[NSSet class]] && ((NSSet *)touches).count > 0) {
                UITouch *touch = [((NSSet *)touches) anyObject];
                NSLog(@"[偵察兵]   - Touch Phase: %ld", (long)touch.phase);
                NSLog(@"[偵察兵]   - Touch Tap Count: %lu", (unsigned long)touch.tapCount);
                NSLog(@"[偵察兵]   - Touch Window: %@", touch.window);
                NSLog(@"[偵察兵]   - Touch View: %@", touch.view);
            }

        } @catch (NSException *exception) {
            NSLog(@"[偵察兵] 读取私有属性失败: %@", exception.reason);
        }
        NSLog(@"[偵察兵] --------------------------");
    }
    
    // 调用原始方法，确保 App 正常工作
    %orig(sender);
}

%end

%ctor {
    NSLog(@"[偵察兵] 已加载，请手动点击天地盘。");
}
