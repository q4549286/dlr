#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局UI与辅助函数
// =========================================================================
static UIView *g_extractorView = nil;
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
        // 让新日志显示在底部，符合阅读习惯
        NSString *newText = [NSString stringWithFormat:@"%@%@\n", currentText, message];
        g_logTextView.text = newText;
        // 自动滚动到底部
        [g_logTextView scrollRangeToVisible:NSMakeRange(newText.length, 0)];
        NSLog(@"[Extractor] %@", message);
    });
}


// =========================================================================
// 2. UIViewController Hook & 核心逻辑
// =========================================================================

@interface UIViewController (EchoExtractor)
- (void)extractFullData;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([self.view.window viewWithTag:777888]) return;
            UIButton *extractorButton = [UIButton buttonWithType:UIButtonTypeSystem];
            extractorButton.frame = CGRectMake(self.view.bounds.size.width - 150, 45, 140, 36);
            extractorButton.tag = 777888;
            [extractorButton setTitle:@"提取完整数据" forState:UIControlStateNormal];
            extractorButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.35 alpha:1.0]; // Green
            [extractorButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            extractorButton.layer.cornerRadius = 18;
            [extractorButton addTarget:self action:@selector(extractFullData) forControlEvents:UIControlEventTouchUpInside];
            [self.view.window addSubview:extractorButton];
        });
    }
}

%new
- (void)extractFullData {
    if (g_extractorView) {
        [g_extractorView removeFromSuperview];
        g_extractorView = nil;
        g_logTextView = nil;
        return;
    }
    
    g_extractorView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, self.view.bounds.size.width - 20, 500)];
    g_extractorView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    g_extractorView.layer.cornerRadius = 15;
    g_extractorView.layer.borderColor = [UIColor greenColor].CGColor;
    g_extractorView.layer.borderWidth = 1.0;
    
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectInset(g_extractorView.bounds, 10, 10)];
    g_logTextView.backgroundColor = [UIColor clearColor];
    g_logTextView.textColor = [UIColor whiteColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logTextView.editable = NO;
    g_logTextView.text = @""; // 清空初始文本
    
    [g_extractorView addSubview:g_logTextView];
    [self.view.window addSubview:g_extractorView];

    LogToScreen(@"[INFO] 开始提取完整数据...");

    // 1. 定位视图 (已验证是安全的)
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    __block UIView *plateView = nil;
    void (^__block __weak weak_findViewRecursive)(UIView *);
    void (^findViewRecursive)(UIView *);
    weak_findViewRecursive = findViewRecursive = ^(UIView *view) {
        if (plateView) return; 
        if ([view isKindOfClass:plateViewClass]) { plateView = view; return; }
        for (UIView *subview in view.subviews) { weak_findViewRecursive(subview); }
    };
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.hidden == NO) { findViewRecursive(window); if (plateView) break; }
    }

    if (!plateView) {
        LogToScreen(@"[CRITICAL] 找不到天地盘视图实例。");
        return;
    }
    LogToScreen(@"[SUCCESS] 成功定位到天地盘视图实例: <%p>", plateView);

    // 2. 定义所有要提取的变量
    NSArray *ivarSuffixes = @[
        @"地宮宮名列", @"天神宮名列", @"天將宮名列",
        @"天盤外經", @"天盤內經", @"天盤將經"
    ];

    // 3. 循环提取并进行详细解析 (已验证是安全的)
    for (NSString *suffix in ivarSuffixes) {
        LogToScreen(@"\n--- [TASK] 正在读取 '%@' ---", suffix);
        id dataObject = GetIvarValueSafely(plateView, suffix);
        
        if (!dataObject) {
            LogToScreen(@"[ERROR] 读取失败: 值为 nil。");
            continue;
        }

        @try {
            NSString *className = NSStringFromClass([dataObject class]);
            
            // --- 处理字典类型 (宫名列) ---
            if ([dataObject isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dataDict = (NSDictionary *)dataObject;
                LogToScreen(@"[INFO] 类型: %@, 数量: %lu", className, (unsigned long)dataDict.count);
                
                // 为了更好的可读性，对Key进行排序
                NSArray *sortedKeys = [dataDict.allKeys sortedArrayUsingSelector:@selector(compare:)];
                
                for (id key in sortedKeys) {
                    id layer = dataDict[key];
                    NSString *text = GetStringFromLayer(layer);
                    LogToScreen(@"  - Key: %@ -> Text: '%@'", key, text);
                }
            } 
            // --- 处理数组类型 (经纬) ---
            else if ([dataObject isKindOfClass:[NSArray class]]) {
                NSArray *dataArray = (NSArray *)dataObject;
                LogToScreen(@"[INFO] 类型: %@, 数量: %lu", className, (unsigned long)dataArray.count);

                for (int i = 0; i < dataArray.count; i++) {
                    id layer = dataArray[i];
                    NSString *text = GetStringFromLayer(layer);
                    LogToScreen(@"  - Index [%d]: '%@'", i, text);
                }
            }
            // --- 处理其他未知类型 ---
            else {
                LogToScreen(@"[WARNING] 未知类型: %@。 描述: %@", className, [dataObject description]);
            }
        } @catch (NSException *exception) {
            LogToScreen(@"[CRITICAL] 解析 '%@' 时发生崩溃! 原因: %@", suffix, exception.reason);
        }
    }
    
    LogToScreen(@"\n--- [COMPLETE] 所有数据提取完毕 ---");
}

%end

%ctor {
    @autoreleasepool {
        NSLog(@"[EchoDataExtractor] 最终数据提取脚本已加载。");
    }
}
