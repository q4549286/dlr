#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// ... (顶部的全局UI与辅助函数部分保持不变) ...
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
    return @"[非文本Layer]";
}

static void LogToScreen(NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *newText = [NSString stringWithFormat:@"%@\n%@", message, g_logTextView.text];
        g_logTextView.text = newText;
        NSLog(@"[Inspector] %@", message);
    });
}


// =========================================================================
// 2. UIViewController Hook & 核心逻辑 (安全调试版)
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
            // 确保只添加一次按钮
            if ([self.view.window viewWithTag:888999]) return;
            UIButton *inspectorButton = [UIButton buttonWithType:UIButtonTypeSystem];
            inspectorButton.frame = CGRectMake(self.view.bounds.size.width - 150, 45, 140, 36);
            inspectorButton.tag = 888999;
            [inspectorButton setTitle:@"检查原始数据" forState:UIControlStateNormal];
            inspectorButton.backgroundColor = [UIColor systemIndigoColor];
            [inspectorButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            inspectorButton.layer.cornerRadius = 18;
            [inspectorButton addTarget:self action:@selector(inspectTianDiPanData) forControlEvents:UIControlEventTouchUpInside];
            [self.view.window addSubview:inspectorButton];
        });
    }
}

%new
- (void)inspectTianDiPanData {
    // 创建或销毁日志窗口
    if (g_inspectorView) {
        [g_inspectorView removeFromSuperview];
        g_inspectorView = nil;
        g_logTextView = nil;
        return;
    }
    
    g_inspectorView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, self.view.bounds.size.width - 20, 400)];
    g_inspectorView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    g_inspectorView.layer.cornerRadius = 15;
    g_inspectorView.layer.borderColor = [UIColor grayColor].CGColor;
    g_inspectorView.layer.borderWidth = 1.0;
    
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectInset(g_inspectorView.bounds, 10, 10)];
    g_logTextView.backgroundColor = [UIColor clearColor];
    g_logTextView.textColor = [UIColor whiteColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO;
    
    [g_inspectorView addSubview:g_logTextView];
    [self.view.window addSubview:g_inspectorView];

    LogToScreen(@"[DEBUG] 开始执行 inspectTianDiPanData...");

    // 1. 找到天地盘视图实例
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    if (!plateViewClass) {
        LogToScreen(@"[CRITICAL] 找不到类 '六壬大占.天地盤視圖類'");
        return;
    }
    LogToScreen(@"[DEBUG] 成功找到类定义。");

    // 修改查找方式，使其更健壮
    UIView *plateView = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        for (UIView *view in window.subviews) {
            // 递归查找
            if ([view isKindOfClass:plateViewClass]) {
                plateView = view;
                break;
            }
            for (UIView *subview in view.subviews) {
                 if ([subview isKindOfClass:plateViewClass]) {
                    plateView = subview;
                    break;
                }
            }
            if (plateView) break;
        }
        if (plateView) break;
    }

    if (!plateView) {
        LogToScreen(@"[CRITICAL] 遍历所有窗口也找不到 '六壬大占.天地盤視圖類' 的实例。");
        return;
    }
    LogToScreen(@"[SUCCESS] 成功定位到天地盘视图实例: <%p>", plateView);

    // 2. 定义要检查的变量名后缀
    NSArray *ivarSuffixes = @[@"地宮宮名列", @"天神宮名列", @"天將宮名列"];

    // 3. 循环读取并打印
    for (NSString *suffix in ivarSuffixes) {
        LogToScreen(@"\n--- [TASK] 正在读取后缀为 '%@' 的变量 ---", suffix);
        id dataObject = GetIvarValueSafely(plateView, suffix);
        
        // 【关键安全检查 1】
        // 只打印指针地址，这是最安全的操作，不会导致崩溃
        LogToScreen(@"[DEBUG] GetIvarValueSafely 返回的指针地址是: %p", dataObject);

        // 【关键安全检查 2】
        // 如果指针为 nil，就直接跳过，不再进行后续操作
        if (!dataObject) {
            LogToScreen(@"[ERROR] 读取失败: 变量值为 nil。跳过此变量。");
            continue;
        }

        // 只有在指针有效时，才尝试进一步操作
        LogToScreen(@"[SUCCESS] 成功读取到非空值。尝试分析...");

        // 【崩溃点隔离】我们怀疑这里会崩溃，所以把它放在 try-catch 块里
        @try {
            LogToScreen(@"[DEBUG] 尝试获取变量类型...");
            NSString *className = NSStringFromClass([dataObject class]);
            LogToScreen(@"[INFO] 变量类型: %@", className);
            
            if ([dataObject isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dataDict = (NSDictionary *)dataObject;
                LogToScreen(@"[INFO] 确认是 NSDictionary，包含 %lu 个条目:", (unsigned long)dataDict.count);
                
                int i = 0;
                for (id key in dataDict) {
                    CALayer *layer = dataDict[key];
                    NSString *text = GetStringFromLayer(layer);
                    CALayer *pLayer = [layer presentationLayer] ?: layer; 
                    
                    LogToScreen(@"  [%d] Key: %@ -> Text: '%@'", i, key, text);
                    LogToScreen(@"      - Position: {%.1f, %.1f}", pLayer.position.x, pLayer.position.y);
                    i++;
                }
            } else {
                LogToScreen(@"[WARNING] 变量不是预期的 NSDictionary 类型。");
            }
        } @catch (NSException *exception) {
            LogToScreen(@"\n\n[CRASH DETECTED!] 在分析变量 '%@' 时发生崩溃!", suffix);
            LogToScreen(@"[CRASH INFO] 原因: %@", exception.reason);
            LogToScreen(@"[CRASH INFO] 详细信息: %@", exception.userInfo);
        }
    }
    
    LogToScreen(@"\n--- [COMPLETE] 检查完毕 ---");
}

%end

// =========================================================================
// 3. 初始化
// =========================================================================
%ctor {
    @autoreleasepool {
        NSLog(@"[EchoRawDataInspector] 原始数据检查脚本 (安全调试版) 已加载。");
    }
}
