#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数 (带屏幕日志功能)
// =========================================================================
static UITextView *g_screenLogger = nil;

#define EchoLog(format, ...) \
    do { \
        NSString *logMessage = [NSString stringWithFormat:format, ##__VA_ARGS__]; \
        NSLog(@"[KeChuan-Test-Recon-V14.1] %@", logMessage); \
        if (g_screenLogger) { \
            dispatch_async(dispatch_get_main_queue(), ^{ \
                NSString *newText = [NSString stringWithFormat:@"%@\n- %@", g_screenLogger.text, logMessage]; \
                if (newText.length > 4000) { newText = [newText substringFromIndex:newText.length - 4000]; } \
                g_screenLogger.text = newText; \
                [g_screenLogger scrollRangeToVisible:NSMakeRange(g_screenLogger.text.length - 1, 1)]; \
            }); \
        } \
    } while (0)

static NSInteger const TestButtonTag = 556690;
static NSInteger const LoggerViewTag = 778899;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)performIvarReconnaissance;
@end

%hook UIViewController

// --- viewDidLoad: 创建按钮和日志窗口 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            if ([keyWindow viewWithTag:TestButtonTag]) { [[keyWindow viewWithTag:TestButtonTag] removeFromSuperview]; }
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"侦查三传Ivar" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemIndigoColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performIvarReconnaissance) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
            
            if ([keyWindow viewWithTag:LoggerViewTag]) { [[keyWindow viewWithTag:LoggerViewTag] removeFromSuperview]; }
            UITextView *logger = [[UITextView alloc] initWithFrame:CGRectMake(10, 45, keyWindow.bounds.size.width - 170, 150)];
            logger.tag = LoggerViewTag;
            logger.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8];
            logger.textColor = [UIColor systemYellowColor];
            logger.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
            logger.editable = NO;
            logger.layer.borderColor = [UIColor systemYellowColor].CGColor;
            logger.layer.borderWidth = 1.0;
            logger.layer.cornerRadius = 5;
            g_screenLogger = logger;
            [keyWindow addSubview:g_screenLogger];
        });
    }
}

%new
// --- 核心侦查方法 ---
- (void)performIvarReconnaissance {
    g_screenLogger.text = @""; // 清空日志
    EchoLog(@"开始V14.1 Ivar侦查...");
    
    // 1. 找到'三傳視圖'类
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (!sanChuanContainerClass) {
        EchoLog(@"错误: 找不到'六壬大占.三傳視圖'类!");
        return;
    }
    EchoLog(@"成功找到'三傳視圖'类定义.");

    // 2. 找到'三傳視圖'的实例
    NSMutableArray *containers = [NSMutableArray array];
    FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, containers);
    
    if (containers.count == 0) {
        EchoLog(@"错误: 在当前视图层级中未找到'三傳視圖'的实例!");
        return;
    }
    
    UIView *sanChuanContainer = containers.firstObject;
    EchoLog(@"成功找到三传容器实例: <%@: %p>", [sanChuanContainer class], sanChuanContainer);
    
    // 3. 定义我们要查找的ivar名字列表
    const char *ivarNames[] = {
        "初传", "中传", "末传",
        "初傳", "中傳", "末傳",
        "初传", "中传", "末传",
        "_初传", "_中传", "_末传",
        "_初傳", "_中傳", "_末傳",
        NULL
    };
    
    BOOL foundAny = NO;
    // 4. 遍历并尝试读取每个ivar
    for (int i = 0; ivarNames[i] != NULL; ++i) {
        const char *ivarName = ivarNames[i];
        Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, ivarName);
        
        if (ivar) {
            foundAny = YES;
            id ivarValue = object_getIvar(sanChuanContainer, ivar);
            
            EchoLog(@"找到Ivar '%s'!", ivarName);

            // ================== 【【【编译错误修正点】】】 ==================
            EchoLog(@"  -> 值: <%@: %p>", (ivarValue ? NSStringFromClass([ivarValue class]) : @"(null class)"), ivarValue);
            // ==============================================================
            
            if (ivarValue && [ivarValue respondsToSelector:@selector(description)]) {
                EchoLog(@"  -> Description: %@", [ivarValue description]);
            }
        }
    }
    
    if (!foundAny) {
        EchoLog(@"警告: 在尝试的列表中, 未找到任何一个Ivar!");
    }
    
    EchoLog(@"侦查完毕.");
}

%end
