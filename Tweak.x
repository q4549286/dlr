#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

#define LOG_PREFIX @"[EchoSpy V2] "
#define Log(format, ...) NSLog(LOG_PREFIX format, ##__VA_ARGS__)

// =========================================================================
// 1. 声明和定义窃听函数
// =========================================================================

// --- 声明原始方法实现的指针 ---
static void (*Original_ViewController_displayTouch)(id, SEL, id);
static void (*Original_PlateView_touchesBegan)(id, SEL, NSSet<UITouch *> *, UIEvent *);
static void (*Original_PlateView_touchesEnded)(id, SEL, NSSet<UITouch *> *, UIEvent *);


// --- 窃听函数 1: 监控 ViewController 的方法调用 ---
static void Tweak_ViewController_displayTouch(id self, SEL _cmd, id sender) {
    Log(@"<<<<< CAPTURED: ViewController's '顯示天地盤觸摸WithSender:' was called! >>>>>");
    Log(@"  - Sender Class: %@", sender ? NSStringFromClass([sender class]) : @"nil");
    Log(@"  - Sender Description: %@", sender ? [sender description] : @"nil");

    if ([sender isKindOfClass:[UIGestureRecognizer class]]) {
        UIGestureRecognizer *gesture = (UIGestureRecognizer *)sender;
        CGPoint location = [gesture locationInView:gesture.view];
        Log(@"  - It's a Gesture! Location: (%.2f, %.2f)", location.x, location.y);
    }
    
    Log(@"<<<<< Now calling original method... >>>>>");
    if (Original_ViewController_displayTouch) {
        Original_ViewController_displayTouch(self, _cmd, sender);
    }
    Log(@"<<<<< Original method finished. >>>>>");
}

// --- 窃听函数 2: 监控 天地盘视图 的触摸开始事件 ---
static void Tweak_PlateView_touchesBegan(id self, SEL _cmd, NSSet<UITouch *> *touches, UIEvent *event) {
    Log(@">>>>> EVENT START: PlateView received 'touchesBegan:withEvent:'! <<<<<");
    UITouch *touch = [touches anyObject];
    if (touch) {
        CGPoint location = [touch locationInView:(UIView *)self];
        Log(@"  - Touch Location: (%.2f, %.2f)", location.x, location.y);
        Log(@"  - Touch Phase: %ld (Should be 0 for Began)", (long)touch.phase);
    }
    
    Log(@">>>>> Now calling original touchesBegan... >>>>>");
    if (Original_PlateView_touchesBegan) {
        Original_PlateView_touchesBegan(self, _cmd, touches, event);
    }
    Log(@">>>>> Original touchesBegan finished. >>>>>");
}

// --- 窃听函数 3: 监控 天地盘视图 的触摸结束事件 ---
static void Tweak_PlateView_touchesEnded(id self, SEL _cmd, NSSet<UITouch *> *touches, UIEvent *event) {
    Log(@"<<<<< EVENT END: PlateView received 'touchesEnded:withEvent:'! >>>>>");
    UITouch *touch = [touches anyObject];
    if (touch) {
        CGPoint location = [touch locationInView:(UIView *)self];
        Log(@"  - Touch Location: (%.2f, %.2f)", location.x, location.y);
        Log(@"  - Touch Phase: %ld (Should be 3 for Ended)", (long)touch.phase);
    }
    
    Log(@"<<<<< Now calling original touchesEnded... >>>>>");
    if (Original_PlateView_touchesEnded) {
        Original_PlateView_touchesEnded(self, _cmd, touches, event);
    }
    Log(@"<<<<< Original touchesEnded finished. >>>>>");
}


// =========================================================================
// 2. 在 %ctor 中应用所有 Hook
// =========================================================================

%ctor {
    @autoreleasepool {
        Log(@"Applying Spy V2 Hooks...");

        // --- Hook 1: ViewController ---
        Class vcClass = NSClassFromString(@"六壬大占.ViewController");
        if (vcClass) {
            SEL selector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
            Method method = class_getInstanceMethod(vcClass, selector);
            if (method) {
                MSHookMessageEx(vcClass, selector, (IMP)&Tweak_ViewController_displayTouch, (IMP *)&Original_ViewController_displayTouch);
                Log(@"Hook 1 SUCCESS: ViewController method hooked.");
            } else {
                Log(@"Hook 1 FAILED: Method '顯示天地盤觸摸WithSender:' not found.");
            }
        } else {
            Log(@"Hook 1 FAILED: Class '六壬大占.ViewController' not found.");
        }

        // --- Hook 2 & 3: 天地盘视图类 ---
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盘视图类");
        if (plateViewClass) {
            // Hook touchesBegan
            SEL beganSelector = @selector(touchesBegan:withEvent:);
            Method beganMethod = class_getInstanceMethod(plateViewClass, beganSelector);
            if (beganMethod) {
                MSHookMessageEx(plateViewClass, beganSelector, (IMP)&Tweak_PlateView_touchesBegan, (IMP *)&Original_PlateView_touchesBegan);
                Log(@"Hook 2 SUCCESS: PlateView 'touchesBegan' hooked.");
            } else {
                Log(@"Hook 2 FAILED: Method 'touchesBegan:withEvent:' not found.");
            }

            // Hook touchesEnded
            SEL endedSelector = @selector(touchesEnded:withEvent:);
            Method endedMethod = class_getInstanceMethod(plateViewClass, endedSelector);
            if (endedMethod) {
                MSHookMessageEx(plateViewClass, endedSelector, (IMP)&Tweak_PlateView_touchesEnded, (IMP *)&Original_PlateView_touchesEnded);
                Log(@"Hook 3 SUCCESS: PlateView 'touchesEnded' hooked.");
            } else {
                Log(@"Hook 3 FAILED: Method 'touchesEnded:withEvent:' not found.");
            }
        } else {
            Log(@"Hook 2/3 FAILED: Class '六壬大占.天地盘视图类' not found.");
        }
    }
}
