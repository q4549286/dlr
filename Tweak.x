#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 日志和辅助函数
// =========================================================================
#define LOG_PREFIX @"[EchoBlackbox] "
#define Log(format, ...) NSLog(LOG_PREFIX format, ##__VA_ARGS__)

static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) { if (window.isKeyWindow) { frontmostWindow = window; break; } }
                if (frontmostWindow) break;
            }
        }
    }
    if (!frontmostWindow) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        frontmostWindow = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
    }
    return frontmostWindow;
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 接口声明和全局变量
// =========================================================================
@interface UIViewController (EchoBlackbox)
- (void)startMonitoringTimer;
- (void)stopMonitoringTimer;
- (void)monitorTask:(NSTimer *)timer;
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix;
@end

static NSTimer *g_monitoringTimer = nil;

// =========================================================================
// 3. 嗅探器 Hook (用于在你手动点击时触发)
// =========================================================================
static void (*Original_displayTianDiPanTouch)(id self, SEL _cmd, id sender);

static void Tweak_displayTianDiPanTouch(id self, SEL _cmd, id sender) {
    Log(@"========== REAL TOUCH DETECTED ==========");
    Log(@"Sender Class: %@", [sender class]);
    Log(@"Sender Description: %@", [sender description]);
    if ([sender isKindOfClass:[UIGestureRecognizer class]]) {
        UIGestureRecognizer *g = (UIGestureRecognizer *)sender;
        CGPoint p = [g locationInView:g.view];
        Log(@"Gesture Location: (%.2f, %.2f)", p.x, p.y);
    }
    Log(@"=========================================");
    
    if (Original_displayTianDiPanTouch) {
        Original_displayTianDiPanTouch(self, _cmd, sender);
    }
}

// =========================================================================
// 4. 主 Hook
// =========================================================================
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if ([NSStringFromClass([self class]) hasSuffix:@"ViewController"]) {
        Log(@"Target ViewController appeared. Starting monitor.");
        [self startMonitoringTimer];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    if ([NSStringFromClass([self class]) hasSuffix:@"ViewController"]) {
        Log(@"Target ViewController will disappear. Stopping monitor.");
        [self stopMonitoringTimer];
    }
}

%new
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix {
    if (!object || !ivarNameSuffix) return nil;
    id value = nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (ivars) {
        for (unsigned int i = 0; i < ivarCount; i++) {
            const char *name = ivar_getName(ivars[i]);
            if (name && [[NSString stringWithUTF8String:name] hasSuffix:ivarNameSuffix]) {
                value = object_getIvar(object, ivars[i]);
                break;
            }
        }
        free(ivars);
    }
    return value;
}

%new
- (void)startMonitoringTimer {
    if (g_monitoringTimer) {
        [g_monitoringTimer invalidate];
        g_monitoringTimer = nil;
    }
    g_monitoringTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                         target:self
                                                       selector:@selector(monitorTask:)
                                                       userInfo:nil
                                                        repeats:YES];
    Log(@"Monitoring timer started.");
}

%new
- (void)stopMonitoringTimer {
    if (g_monitoringTimer) {
        [g_monitoringTimer invalidate];
        g_monitoringTimer = nil;
        Log(@"Monitoring timer stopped.");
    }
}

%new
- (void)monitorTask:(NSTimer *)timer {
    Log(@"--- Monitor Task Running ---");
    @try {
        UIWindow *keyWindow = GetFrontmostWindow();
        if (!keyWindow) {
            Log(@"Monitor: Could not get key window.");
            return;
        }
        
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
        if (!plateViewClass) {
            Log(@"Monitor: Could not find class '六壬大占.天地盤視圖類'.");
            return;
        }

        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);

        if (plateViews.count > 0) {
            UIView *plateView = plateViews.firstObject;
            
            id tianShenDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天神宮名列"];
            id tianJiangDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天將宮名列"];
            
            Log(@"--- DUMPING DICTIONARIES ---");
            Log(@"天神宫名列 (tianShenDict): %@", tianShenDict); // 这会调用 description
            Log(@"天将宫名列 (tianJiangDict): %@", tianJiangDict); // 这会调用 description
            Log(@"--------------------------");
            
        } else {
            Log(@"Monitor: '天地盘视图类' not found in current view hierarchy.");
        }
    } @catch (NSException *exception) {
        Log(@"!!!!!! EXCEPTION in monitor task: %@, Reason: %@", exception.name, exception.reason);
    }
}

%end

// =========================================================================
// 5. %ctor 安装 Hook
// =========================================================================
%ctor {
    @autoreleasepool {
        Class vcClass = NSClassFromString(@"六壬大占.ViewController");
        if (vcClass) {
            MSHookMessageEx(vcClass, NSSelectorFromString(@"顯示天地盤觸摸WithSender:"), (IMP)&Tweak_displayTianDiPanTouch, (IMP *)&Original_displayTianDiPanTouch);
            Log(@"'顯示天地盤觸摸WithSender:' hook installed.");
        } else {
            Log(@"ERROR: Could not find '六壬大占.ViewController' to install touch hook.");
        }
        Log(@"Blackbox script loaded.");
    }
}
