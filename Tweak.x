#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局UI与辅助函数
// =========================================================================
static UIView *g_inspectorView = nil;
static UITextView *g_logTextView = nil;

// 一个辅助函数，用于从实例中安全地获取 Ivar 值
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) {
    if (!object || !ivarNameSuffix) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) {
        return nil;
    }
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

// 一个辅助函数，用于从 CALayer 中提取字符串
static NSString *GetStringFromLayer(id layer) {
    if (layer && [layer respondsToSelector:@selector(string)]) {
        id stringValue = [layer valueForKey:@"string"];
        if ([stringValue isKindOfClass:[NSString class]]) {
            return stringValue;
        }
        if ([stringValue isKindOfClass:[NSAttributedString class]]) {
            return ((NSAttributedString *)stringValue).string;
        }
    }
    return @"[非文本Layer]";
}

// 日志函数
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
// 2. UIViewController Hook & 核心逻辑
// =========================================================================

@interface UIViewController (EchoInspector)
- (void)inspectTianDiPanData;
@end

%hook UIViewController

// 在主界面加载完成后，添加一个触发按钮
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIButton *inspectorButton = [UIButton buttonWithType:UIButtonTypeSystem];
            inspectorButton.frame = CGRectMake(self.view.bounds.size.width - 150, 45, 140, 36);
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

    LogToScreen(@"开始检查天地盘原始数据...");

    // 1. 找到天地盘视图实例
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    if (!plateViewClass) {
        LogToScreen(@"错误: 找不到类 '六壬大占.天地盤視圖類'");
        return;
    }

    UIView *plateView = nil;
    for (UIView *subview in self.view.window.subviews) {
        if ([subview isKindOfClass:plateViewClass]) {
            plateView = subview;
            break;
        }
    }
    
    if (!plateView) {
        // 如果在window里找不到，就在当前view里找
         for (UIView *subview in self.view.subviews) {
            if ([subview isKindOfClass:plateViewClass]) {
                plateView = subview;
                break;
            }
        }
    }

    if (!plateView) {
        LogToScreen(@"错误: 找不到 '六壬大占.天地盤視圖類' 的实例。");
        return;
    }
    LogToScreen(@"成功定位到天地盘视图实例: <%p>", plateView);

    // 2. 定义要检查的变量名后缀
    NSArray *ivarSuffixes = @[@"地宮宮名列", @"天神宮名列", @"天將宮名列"];

    // 3. 循环读取并打印
    for (NSString *suffix in ivarSuffixes) {
        LogToScreen(@"\n--- 正在读取后缀为 '%@' 的变量 ---", suffix);
        id dataObject = GetIvarValueSafely(plateView, suffix);
        
        if (!dataObject) {
            LogToScreen(@"读取失败: 变量值为 nil");
            continue;
        }

        LogToScreen(@"变量类型: %@", NSStringFromClass([dataObject class]));
        
        // 假设这些变量都是字典 (根据原脚本的 allValues 推断)
        if ([dataObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dataDict = (NSDictionary *)dataObject;
            LogToScreen(@"字典包含 %lu 个条目:", (unsigned long)dataDict.count);
            
            // 遍历字典中的所有 CALayer
            int i = 0;
            for (id key in dataDict) {
                CALayer *layer = dataDict[key];
                NSString *text = GetStringFromLayer(layer);
                // 获取 presentationLayer (动画过程中的图层) 或原始图层
                CALayer *pLayer = [layer presentationLayer] ?: layer; 
                
                LogToScreen(@"  [%d] Key: %@ -> Text: '%@'", i, key, text);
                LogToScreen(@"      - Position: {%.1f, %.1f}", pLayer.position.x, pLayer.position.y);
                LogToScreen(@"      - Bounds: {%.1f, %.1f, %.1f, %.1f}", pLayer.bounds.origin.x, pLayer.bounds.origin.y, pLayer.bounds.size.width, pLayer.bounds.size.height);
                i++;
            }
        } else {
            LogToScreen(@"警告: 变量不是预期的 NSDictionary 类型。");
        }
    }
    
    LogToScreen(@"\n--- 检查完毕 ---");
}

%end

// =========================================================================
// 3. 初始化
// =========================================================================
%ctor {
    @autoreleasepool {
        NSLog(@"[EchoRawDataInspector] 原始数据检查脚本已加载。");
    }
}
