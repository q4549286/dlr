#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局UI与辅助函数
// =========================================================================
static UIView *g_inspectorView = nil;
static UITextView *g_logTextView = nil;

static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) {
    if (!object || !ivarNameSuffix) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) { return nil; }
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

static NSString *GetStringFromLayer(id layer) {
    if (layer && [layer respondsToSelector:@selector(string)]) {
        id stringValue = [layer valueForKey:@"string"];
        if ([stringValue isKindOfClass:[NSString class]]) { return stringValue; }
        if ([stringValue isKindOfClass:[NSAttributedString class]]) { return ((NSAttributedString *)stringValue).string; }
    }
    return @"[?]";
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
// 2. UIViewController Hook & 核心逻辑
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
            [inspectorButton setTitle:@"检查原始数据" forState:UIControlStateNormal];
            inspectorButton.backgroundColor = [UIColor colorWithRed:0.35 green:0.34 blue:0.84 alpha:1.0];
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
    g_inspectorView.layer.borderColor = [UIColor grayColor].CGColor;
    g_inspectorView.layer.borderWidth = 1.0;
    
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectInset(g_inspectorView.bounds, 10, 10)];
    g_logTextView.backgroundColor = [UIColor clearColor];
    g_logTextView.textColor = [UIColor whiteColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logTextView.editable = NO;
    
    [g_inspectorView addSubview:g_logTextView];
    [self.view.window addSubview:g_inspectorView];

    LogToScreen(@"[DEBUG] 开始执行 inspectTianDiPanData...");

    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    if (!plateViewClass) {
        LogToScreen(@"[CRITICAL] 找不到类 '六壬大占.天地盤視圖類'");
        return;
    }
    LogToScreen(@"[DEBUG] 成功找到类定义。");

    __block UIView *plateView = nil;
    
    // ===================================================================
    // 【最终修正】: 恢复兼容性API + 修正Block递归语法
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

    // 【修正】标准的递归 Block 写法
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

    for (UIWindow *window in windowsToSearch) {
        findViewRecursive(window);
        if (plateView) break;
    }
    // ======================= 最终修正结束 ========================

    if (!plateView) {
        LogToScreen(@"[CRITICAL] 遍历所有窗口也找不到 '六壬大占.天地盤視圖類' 的实例。");
        return;
    }
    LogToScreen(@"[SUCCESS] 成功定位到天地盘视图实例: <%p>", plateView);

    NSArray *ivarSuffixes = @[
        @"地宮宮名列", @"天神宮名列", @"天將宮名列",
        @"天盤外經", @"天盤內經", @"天盤將經"
    ];

    for (NSString *suffix in ivarSuffixes) {
        LogToScreen(@"\n--- [TASK] 正在读取后缀为 '%@' 的变量 ---", suffix);
        id dataObject = GetIvarValueSafely(plateView, suffix);
        
        LogToScreen(@"[DEBUG] GetIvarValueSafely 返回的指针地址是: %p", dataObject);

        if (!dataObject) {
            LogToScreen(@"[ERROR] 读取失败: 变量值为 nil。跳过此变量。");
            continue;
        }

        LogToScreen(@"[SUCCESS] 成功读取到非空值。尝试分析...");

        @try {
            NSString *className = NSStringFromClass([dataObject class]);
            LogToScreen(@"[INFO] 变量类型: %@", className);
            
            if ([dataObject isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dataDict = (NSDictionary *)dataObject;
                LogToScreen(@"[INFO] 确认是 NSDictionary，包含 %lu 个条目:", (unsigned long)dataDict.count);
                
                int i = 0;
                for (id key in [dataDict.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
                    id layer = dataDict[key];
                    if (![layer isKindOfClass:[CALayer class]]) {
                         LogToScreen(@"  [%d] Key: %@ -> 值不是 CALayer", i, key);
                         continue;
                    }
                    NSString *text = GetStringFromLayer(layer);
                    CALayer *pLayer = [layer presentationLayer] ?: layer; 
                    
                    LogToScreen(@"  [%d] Key: %@ -> Text: '%@'", i, key, text);
                    LogToScreen(@"      - Position: {%.1f, %.1f}", pLayer.position.x, pLayer.position.y);
                    i++;
                }
            } 
            else if ([dataObject isKindOfClass:[NSArray class]]) {
                NSArray *dataArray = (NSArray *)dataObject;
                LogToScreen(@"[INFO] 确认是 NSArray，包含 %lu 个条目:", (unsigned long)dataArray.count);

                for (int i = 0; i < dataArray.count; i++) {
                    id layer = dataArray[i];
                     if (![layer isKindOfClass:[CALayer class]]) {
                         LogToScreen(@"  [%d] 值不是 CALayer", i);
                         continue;
                    }
                    NSString *text = GetStringFromLayer(layer);
                    LogToScreen(@"  [%d] Text: '%@'", i, text);
                }
            }
            else {
                LogToScreen(@"[WARNING] 变量既不是 NSDictionary 也不是 NSArray。");
            }
        } @catch (NSException *exception) {
            LogToScreen(@"\n\n[CRASH DETECTED!] 在分析变量 '%@' 时发生崩溃!", suffix);
            LogToScreen(@"[CRASH INFO] 原因: %@", exception.reason);
        }
    }
    
    LogToScreen(@"\n--- [COMPLETE] 检查完毕 ---");
}

%end

%ctor {
    @autoreleasepool {
        NSLog(@"[EchoFullInspector] 完整检查脚本 (可编译最终版) 已加载。");
    }
}
