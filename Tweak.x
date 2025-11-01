#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 伪造手势类
// =========================================================================
@interface EchoFakeGestureRecognizer : UIGestureRecognizer
@property (nonatomic, assign) CGPoint fakeLocation;
@end

@implementation EchoFakeGestureRecognizer
- (CGPoint)locationInView:(UIView *)view {
    return self.fakeLocation;
}
@end

// =========================================================================
// 2. 全局变量与辅助函数
// =========================================================================
static UIView *g_debuggerView = nil;
static UITextView *g_logTextView = nil;
static BOOL g_isPerformingFakeClick = NO;

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
        NSLog(@"[Debugger] %@", message);
    });
}

// =========================================================================
// 3. 核心Hook
// =========================================================================

@interface UIViewController (EchoDebugger)
- (void)startDebugTest;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([self.view.window viewWithTag:666777]) return;
            UIButton *debuggerButton = [UIButton buttonWithType:UIButtonTypeSystem];
            debuggerButton.frame = CGRectMake(self.view.bounds.size.width - 150, 45, 140, 36);
            debuggerButton.tag = 666777;
            [debuggerButton setTitle:@"Hook调试" forState:UIControlStateNormal];
            debuggerButton.backgroundColor = [UIColor systemOrangeColor];
            [debuggerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            debuggerButton.layer.cornerRadius = 18;
            [debuggerButton addTarget:self action:@selector(startDebugTest) forControlEvents:UIControlEventTouchUpInside];
            [self.view.window addSubview:debuggerButton];
        });
    }
}

%new
- (void)startDebugTest {
    if (g_debuggerView) {
        [g_debuggerView removeFromSuperview];
        g_debuggerView = nil; g_logTextView = nil;
        return;
    }
    
    g_debuggerView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, self.view.bounds.size.width - 20, 300)];
    g_debuggerView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    g_debuggerView.layer.cornerRadius = 15;
    g_debuggerView.layer.borderColor = [UIColor orangeColor].CGColor;
    g_debuggerView.layer.borderWidth = 1.0;
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectInset(g_debuggerView.bounds, 10, 10)];
    g_logTextView.backgroundColor = [UIColor clearColor]; g_logTextView.textColor = [UIColor whiteColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:11]; g_logTextView.editable = NO; g_logTextView.text = @"";
    [g_debuggerView addSubview:g_logTextView];
    [self.view.window addSubview:g_debuggerView];

    LogToScreen(@"[DEBUG MODE] Starting test...");

    UIViewController *vc = self;
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    __block UIView *plateView = nil;
    
    void (^__block __weak weak_findViewRecursive)(UIView *);
    void (^findViewRecursive)(UIView *);
    weak_findViewRecursive = findViewRecursive = ^(UIView *view) {
        if (plateView) return; 
        if ([view isKindOfClass:plateViewClass]) { plateView = view; return; }
        for (UIView *subview in view.subviews) { weak_findViewRecursive(subview); }
    };
    findViewRecursive(self.view.window);
    
    if (!plateView) {
        LogToScreen(@"[CRITICAL] Failed to find plate view instance.");
        return;
    }
    LogToScreen(@"[SUCCESS] Found plate view instance.");

    CGPoint testPosition = CGPointMake(CGRectGetMidX(plateView.bounds), CGRectGetMidY(plateView.bounds));
    LogToScreen(@"[INFO] Using test position: {%.1f, %.1f}", testPosition.x, testPosition.y);
    
    EchoFakeGestureRecognizer *fakeGesture = [[EchoFakeGestureRecognizer alloc] init];
    fakeGesture.fakeLocation = testPosition;
    
    LogToScreen(@"[ACTION] Performing fake click via performSelector...");
    g_isPerformingFakeClick = YES;
    
    SEL clickSelector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [vc performSelector:clickSelector withObject:fakeGesture];
    #pragma clang diagnostic pop
    
    g_isPerformingFakeClick = NO;
    LogToScreen(@"[ACTION] performSelector returned.");
}

%end

// =========================================================================
// 4. 初始化 (严格按照原始结构)
// =========================================================================
%ctor {
    @autoreleasepool {
        // 使用 Method Swizzling 来动态替换方法，这是最稳妥的方式
        Class vcClass = NSClassFromString(@"六壬大占.ViewController");
        if (vcClass) {
            SEL originalSelector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
            Method originalMethod = class_getInstanceMethod(vcClass, originalSelector);
            
            if (originalMethod) {
                IMP originalImp = method_getImplementation(originalMethod);
                
                IMP swizzledImp = imp_implementationWithBlock(^(id _self, UIGestureRecognizer *sender){
                    LogToScreen(@"\n--- SWIZZLE TRIGGERED: 顯示天地盤觸摸WithSender: ---");
                    if (g_isPerformingFakeClick) { LogToScreen(@"[INFO] Invoked by Tweak."); } 
                    else { LogToScreen(@"[INFO] Invoked by user tap."); }
                    LogToScreen(@"[PARAM] Sender Class: %@", NSStringFromClass([sender class]));
                    @try {
                        CGPoint location = [sender locationInView:[_self view]];
                        LogToScreen(@"[PARAM] Location in vc.view: {%.1f, %.1f}", location.x, location.y);
                    } @catch (NSException *exception) {
                        LogToScreen(@"[ERROR] Exception while getting location: %@", exception.reason);
                    }
                    LogToScreen(@"[EXEC] Calling original implementation...");
                    // 调用原始实现
                    ((void (*)(id, SEL, id))originalImp)(_self, originalSelector, sender);
                    LogToScreen(@"[EXEC] Original implementation returned.");
                });
                
                method_setImplementation(originalMethod, swizzledImp);
                NSLog(@"[Debugger] Swizzled 顯示天地盤觸摸WithSender: successfully.");
            } else {
                NSLog(@"[Debugger] ERROR: Could not find method 顯示天地盤觸摸WithSender: to swizzle.");
            }
        } else {
             NSLog(@"[Debugger] ERROR: Could not find class 六壬大占.ViewController.");
        }
    }
}
