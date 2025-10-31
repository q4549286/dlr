#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 全局UI与辅助函数 (保持不变)
// =========================================================================
static UIView *g_inspectorView = nil;
static UITextView *g_logTextView = nil;

static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) {
    if (!object || !ivarNameSuffix) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) { free(ivars); return nil; }
    id value = nil;
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name) {
            NSString *ivarNameStr = [NSString stringWithUTF8String:name];
            if ([ivarNameStr hasSuffix:ivarNameSuffix]) {
                value = object_getIvar(object, ivar);
                break;
            }
        }
    }
    free(ivars);
    return value;
}

static void LogToScreen(NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *currentText = g_logTextView.text ?: @"";
        NSString *newText = [NSString stringWithFormat:@"%@\n%@", message, currentText];
        g_logTextView.text = newText;
        NSLog(@"[Inspector] %@", message);
    });
}

// =========================================================================
// 核心逻辑 (终极诊断版)
// =========================================================================

@interface UIViewController (EchoInspector)
- (void)inspectTianDiPanData;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([self.view.window viewWithTag:888999]) return;
            UIButton *inspectorButton = [UIButton buttonWithType:UIButtonTypeSystem];
            inspectorButton.frame = CGRectMake(self.view.bounds.size.width - 150, 45, 140, 36);
            inspectorButton.tag = 888999;
            [inspectorButton setTitle:@"终极诊断" forState:UIControlStateNormal];
            inspectorButton.backgroundColor = [UIColor systemRedColor];
            [inspectorButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            inspectorButton.layer.cornerRadius = 18;
            [inspectorButton addTarget:self action:@selector(inspectTianDiPanData) forControlEvents:UIControlEventTouchUpInside];
            [self.view.window addSubview:inspectorButton];
        });
    }
}

%new
- (void)inspectTianDiPanData {
    if (g_inspectorView) {
        [g_inspectorView removeFromSuperview];
        g_inspectorView = nil;
        g_logTextView = nil;
        return;
    }
    
    g_inspectorView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, self.view.bounds.size.width - 20, 500)];
    g_inspectorView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    g_inspectorView.layer.cornerRadius = 15;
    [g_inspectorView.layer setBorderColor:[UIColor redColor].CGColor];
    [g_inspectorView.layer setBorderWidth:1.0];
    
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectInset(g_inspectorView.bounds, 10, 10)];
    g_logTextView.backgroundColor = [UIColor clearColor];
    g_logTextView.textColor = [UIColor whiteColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO;
    
    [g_inspectorView addSubview:g_logTextView];
    [self.view.window addSubview:g_inspectorView];

    LogToScreen(@"[DIAGNOSTIC MODE] 诊断开始...");

    // 1. 定位视图
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    if (!plateViewClass) {
        LogToScreen(@"[CRITICAL] 找不到类 '六壬大占.天地盤視圖類'");
        return;
    }

    __block UIView *plateView = nil;
    void (^__block __weak weak_findViewRecursive)(UIView *);
    void (^findViewRecursive)(UIView *);
    weak_findViewRecursive = findViewRecursive = ^(UIView *view) {
        if (plateView) return; 
        if ([view isKindOfClass:plateViewClass]) {
            plateView = view;
            return;
        }
        for (UIView *subview in view.subviews) {
            weak_findViewRecursive(subview);
        }
    };

    // 兼容性好的窗口遍历
    NSMutableArray *windowsToSearch = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                [windowsToSearch addObjectsFromArray:scene.windows];
            }
        }
    } else {
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

    if (!plateView) {
        LogToScreen(@"[CRITICAL] 找不到 '六壬大占.天地盤視圖類' 的实例。");
        return;
    }
    LogToScreen(@"[SUCCESS] 成功定位到天地盘视图实例: <%p>", plateView);
    LogToScreen(@"[DEBUG] 实例描述: %@", plateView);


    // ============================================================
    // 【终极诊断核心】 - 逐个击破
    // ============================================================
    
    // --- 测试点 1: 地宮宮名列 ---
    LogToScreen(@"\n--- [TEST 1] 正在尝试读取 '地宮宮名列' ---");
    LogToScreen(@"[1A] 即将调用 GetIvarValueSafely...");
    id diGongObject = GetIvarValueSafely(plateView, @"地宮宮名列");
    LogToScreen(@"[1B] GetIvarValueSafely 调用完毕。");
    LogToScreen(@"[1C] 返回的指针地址是: %p", diGongObject);
    if (!diGongObject) { LogToScreen(@"[FAIL] 读取失败，返回nil。诊断中止。"); return; }
    LogToScreen(@"[SUCCESS] Test 1 通过！");

    // --- 测试点 2: 天神宮名列 ---
    LogToScreen(@"\n--- [TEST 2] 正在尝试读取 '天神宮名列' ---");
    LogToScreen(@"[2A] 即将调用 GetIvarValueSafely...");
    id tianShenObject = GetIvarValueSafely(plateView, @"天神宮名列");
    LogToScreen(@"[2B] GetIvarValueSafely 调用完毕。");
    LogToScreen(@"[2C] 返回的指针地址是: %p", tianShenObject);
    if (!tianShenObject) { LogToScreen(@"[FAIL] 读取失败，返回nil。诊断中止。"); return; }
    LogToScreen(@"[SUCCESS] Test 2 通过！");

    // --- 测试点 3: 天將宮名列 ---
    LogToScreen(@"\n--- [TEST 3] 正在尝试读取 '天將宮名列' ---");
    LogToScreen(@"[3A] 即将调用 GetIvarValueSafely...");
    id tianJiangObject = GetIvarValueSafely(plateView, @"天將宮名列");
    LogToScreen(@"[3B] GetIvarValueSafely 调用完毕。");
    LogToScreen(@"[3C] 返回的指针地址是: %p", tianJiangObject);
    if (!tianJiangObject) { LogToScreen(@"[FAIL] 读取失败，返回nil。诊断中止。"); return; }
    LogToScreen(@"[SUCCESS] Test 3 通过！");

    LogToScreen(@"\n[DIAGNOSTIC] 所有GetIvarValueSafely调用均安全通过！问题可能在后续处理。现在尝试解析...");
    
    // 如果上面都安全通过了，我们再尝试解析，并用 try-catch 包裹
    @try {
        LogToScreen(@"--- 正在解析 Test 1 的数据 ---");
        NSDictionary *diGongDict = (NSDictionary *)diGongObject;
        LogToScreen(@"地宮宮名列 包含 %lu 个条目。", (unsigned long)diGongDict.count);
        
        LogToScreen(@"--- 正在解析 Test 2 的数据 ---");
        NSDictionary *tianShenDict = (NSDictionary *)tianShenObject;
        LogToScreen(@"天神宮名列 包含 %lu 个条目。", (unsigned long)tianShenDict.count);

        LogToScreen(@"--- 正在解析 Test 3 的数据 ---");
        NSDictionary *tianJiangDict = (NSDictionary *)tianJiangObject;
        LogToScreen(@"天將宮名列 包含 %lu 个条目。", (unsigned long)tianJiangDict.count);

    } @catch (NSException *exception) {
        LogToScreen(@"\n\n[CRASH DETECTED!] 在解析数据时发生崩溃!");
        LogToScreen(@"[CRASH INFO] 原因: %@", exception.reason);
    }
    
    LogToScreen(@"\n--- [COMPLETE] 诊断完毕 ---");
}

%end

%ctor {
    @autoreleasepool {
        NSLog(@"[EchoUltimateDebugger] 终极诊断脚本已加载。");
    }
}
