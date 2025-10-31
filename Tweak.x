#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局UI与日志函数
// =========================================================================
static UIView *g_recorderView = nil;
static UITextView *g_logTextView = nil;

// 原始函数指针
static id (*Original_GetIvarValueSafely)(id, id, NSString *);

// 日志函数
static void LogToScreen(NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *currentText = g_logTextView.text ?: @"";
        NSString *newText = [NSString stringWithFormat:@"%@%@\n", currentText, message];
        g_logTextView.text = newText;
        [g_logTextView scrollRangeToVisible:NSMakeRange(newText.length, 0)];
        NSLog(@"[Recorder] %@", message);
    });
}

// =========================================================================
// 2. Hook 我们自己的辅助函数
// =========================================================================

static id Tweak_GetIvarValueSafely(id self, SEL _cmd, id object, NSString *ivarNameSuffix) {
    LogToScreen(@"\n--- Hooked GetIvarValueSafely ---");
    LogToScreen(@"[PARAM] self(caller): <%@: %p>", NSStringFromClass([self class]), self);
    LogToScreen(@"[PARAM] object: <%@: %p>", NSStringFromClass([object class]), object);
    LogToScreen(@"[PARAM] ivarNameSuffix: '%@'", ivarNameSuffix);

    if (!object || !ivarNameSuffix) {
        LogToScreen(@"[EXIT] object or suffix is nil. Returning nil.");
        return nil;
    }

    unsigned int ivarCount = 0;
    LogToScreen(@"[STEP 1] Calling class_copyIvarList...");
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    LogToScreen(@"[STEP 1] Done. Found %u ivars.", ivarCount);

    if (!ivars) {
        LogToScreen(@"[EXIT] class_copyIvarList returned NULL. Returning nil.");
        return nil;
    }

    id value = nil;
    BOOL foundMatch = NO;
    LogToScreen(@"[STEP 2] Starting loop to find matching ivar...");
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name) {
            NSString *ivarNameStr = [NSString stringWithUTF8String:name];
            if ([ivarNameStr hasSuffix:ivarNameSuffix]) {
                foundMatch = YES;
                LogToScreen(@"[STEP 2] SUCCESS! Found matching ivar: '%@' at index %u.", ivarNameStr, i);
                
                LogToScreen(@"[STEP 3] PRE-CRASH CHECK:");
                LogToScreen(@"         - object pointer: %p", object);
                LogToScreen(@"         - ivar pointer: %p", ivar);
                LogToScreen(@"[STEP 3] Now calling object_getIvar...");

                value = object_getIvar(object, ivar);
                
                LogToScreen(@"[STEP 3] SURVIVED! object_getIvar returned.");
                LogToScreen(@"         - Returned value pointer: %p", value);
                break;
            }
        }
    }

    if (!foundMatch) {
        LogToScreen(@"[STEP 2] FAIL! Loop finished, no matching ivar found.");
    }
    
    LogToScreen(@"[STEP 4] Freeing ivars list...");
    free(ivars);
    LogToScreen(@"[STEP 4] Done.");

    LogToScreen(@"[EXIT] Function finished. Returning value at %p.", value);
    LogToScreen(@"---------------------------------");
    return value;
}

// =========================================================================
// 3. UIViewController Hook & 触发逻辑
// =========================================================================

@interface UIViewController (EchoRecorder)
- (void)triggerSafeInspection;
- (id)GetIvarValueSafely:(id)object withSuffix:(NSString *)ivarNameSuffix; // 改为两个参数
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([self.view.window viewWithTag:999000]) return;
            UIButton *recorderButton = [UIButton buttonWithType:UIButtonTypeSystem];
            recorderButton.frame = CGRectMake(self.view.bounds.size.width - 150, 45, 140, 36);
            recorderButton.tag = 999000;
            [recorderButton setTitle:@"黑盒记录仪" forState:UIControlStateNormal];
            recorderButton.backgroundColor = [UIColor systemOrangeColor];
            [recorderButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            recorderButton.layer.cornerRadius = 18;
            [recorderButton addTarget:self action:@selector(triggerSafeInspection) forControlEvents:UIControlEventTouchUpInside];
            [self.view.window addSubview:recorderButton];
        });
    }
}

%new
- (void)triggerSafeInspection {
    if (g_recorderView) {
        [g_recorderView removeFromSuperview];
        g_recorderView = nil;
        g_logTextView = nil;
        return;
    }
    
    g_recorderView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, self.view.bounds.size.width - 20, 500)];
    g_recorderView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    g_recorderView.layer.cornerRadius = 15;
    g_recorderView.layer.borderColor = [UIColor orangeColor].CGColor;
    g_recorderView.layer.borderWidth = 1.0;
    
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectInset(g_recorderView.bounds, 10, 10)];
    g_logTextView.backgroundColor = [UIColor clearColor];
    g_logTextView.textColor = [UIColor whiteColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logTextView.editable = NO;
    g_logTextView.text = @"";
    
    [g_recorderView addSubview:g_recorderView];
    [self.view.window addSubview:g_recorderView];

    LogToScreen(@"[INFO] 准备触发 GetIvarValueSafely...");

    // 找到天地盘视图实例
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    __block UIView *plateView = nil;
    void (^__block __weak weak_findViewRecursive)(UIView *);
    void (^findViewRecursive)(UIView *);
    weak_findViewRecursive = findViewRecursive = ^(UIView *view) {
        if (plateView) return; 
        if ([view isKindOfClass:plateViewClass]) { plateView = view; return; }
        for (UIView *subview in view.subviews) { weak_findViewRecursive(subview); }
    };

    // ===================================================================
    // 【最终修正】: 恢复兼容性最好的窗口遍历方法
    // ===================================================================
    NSMutableArray *windowsToSearch = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                [windowsToSearch addObjectsFromArray:scene.windows];
            }
        }
    }
    
    if (windowsToSearch.count == 0) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if ([UIApplication sharedApplication].windows) {
            [windowsToSearch addObjectsFromArray:[UIApplication sharedApplication].windows];
        }
        #pragma clang diagnostic pop
    }

    for (UIWindow *window in windowsToSearch) {
        findViewRecursive(window);
        if (plateView) break;
    }
    // ======================= 最终修正结束 ========================

    if (!plateView) {
        LogToScreen(@"[CRITICAL] 找不到天地盘视图实例。");
        return;
    }
    
    // 调用会经过我们的Hooked版本
    [self GetIvarValueSafely:plateView withSuffix:@"地宮宮名列"];
}

// 实际的GetIvarValueSafely实现，将被我们的Hook替换
%new
- (id)GetIvarValueSafely:(id)object withSuffix:(NSString *)ivarNameSuffix {
    // 这个方法体是空的，因为它只是一个“靶子”，让我们能用 MSHookMessageEx 来Hook它。
    // 真正的逻辑在 Tweak_GetIvarValueSafely 中。
    // 在这里我们甚至不需要调用原始实现，因为我们只是想触发Hook。
    return nil;
}

%end

// =========================================================================
// 4. 初始化
// =========================================================================
%ctor {
    @autoreleasepool {
        // 这次，我们把它当作一个实例方法来Hook，这更标准、更安全。
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(GetIvarValueSafely:withSuffix:), (IMP)&Tweak_GetIvarValueSafely, (IMP *)&Original_GetIvarValueSafely);
        
        NSLog(@"[EchoCrashRecorder] 终极黑盒记录仪已加载。");
    }
}
