#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// 声明一个函数指针，用于保存原始方法的实现
static void (*Original_顯示天地盤觸摸WithSender)(id, SEL, UIGestureRecognizer *);

// 我们自己的替换函数
static void Tweak_顯示天地盤觸摸WithSender(id self, SEL _cmd, UIGestureRecognizer *sender) {
    NSLog(@"[偵察兵] 目标方法被触发！");
    
    if ([sender isKindOfClass:[UITapGestureRecognizer class]]) {
        UITapGestureRecognizer *tapGesture = (UITapGestureRecognizer *)sender;
        
        NSLog(@"[偵察兵] --- 真实点击的手势参数 ---");
        NSLog(@"[偵察兵] State: %ld", (long)tapGesture.state);
        NSLog(@"[偵察兵] Number of Touches: %lu", (unsigned long)tapGesture.numberOfTouches);
        
        @try {
            // 使用 object_getIvar 可能比 KVC 更稳定
            Ivar locationIvar = class_getInstanceVariable([tapGesture class], "_locationInView");
            if(locationIvar) {
                // 因为 _locationInView 是一个 CGPoint 结构体，不是对象，所以需要特殊处理
                // 我们直接获取它的指针然后解引用
                CGPoint *locationPtr = (CGPoint *)((__bridge void *)tapGesture + ivar_getOffset(locationIvar));
                NSLog(@"[偵察兵] _locationInView: {%.2f, %.2f}", locationPtr->x, locationPtr->y);
            } else {
                 NSLog(@"[偵察兵] 无法找到 _locationInView Ivar");
            }
           
            id touches = [tapGesture valueForKey:@"touches"]; // KVC 在这里仍然是安全的
            NSLog(@"[偵察兵] touches (KVC): %@", touches);
            
            if ([touches isKindOfClass:[NSSet class]] && ((NSSet *)touches).count > 0) {
                UITouch *touch = [((NSSet *)touches) anyObject];
                NSLog(@"[偵察兵]   - Touch Phase: %ld", (long)touch.phase);
                NSLog(@"[偵察兵]   - Touch Tap Count: %lu", (unsigned long)touch.tapCount);
                NSLog(@"[偵察兵]   - Touch Window: %@", touch.window);
                NSLog(@"[偵察兵]   - Touch View: %@", touch.view);
            }

        } @catch (NSException *exception) {
            NSLog(@"[偵察兵] 读取属性失败: %@", exception.reason);
        }
        NSLog(@"[偵察兵] --------------------------");
    }
    
    // 调用原始方法的实现
    Original_顯示天地盤觸摸WithSender(self, _cmd, sender);
}

%ctor {
    @autoreleasepool {
        // 获取目标类
        Class vcClass = NSClassFromString(@"六壬大占.ViewController");
        if (vcClass) {
            // 获取目标方法的 SEL
            SEL targetSelector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
            
            // 使用 MSHookMessageEx 进行 Hook
            MSHookMessageEx(
                vcClass,
                targetSelector,
                (IMP)&Tweak_顯示天地盤觸摸WithSender,
                (IMP *)&Original_顯示天地盤觸摸WithSender
            );
            NSLog(@"[偵察兵] 已成功 Hook 中文方法，请手动点击天地盘。");
        } else {
            NSLog(@"[偵察兵] 错误：找不到 六壬大占.ViewController 类。");
        }
    }
}
