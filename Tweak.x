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
        NSLog(@"[KeChuan-Test-Recon-V15] %@", logMessage); \
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
- (void)performDeepIvarReconnaissance;
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
            [testButton setTitle:@"深度侦查傳視圖" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemTealColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performDeepIvarReconnaissance) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
            
            if ([keyWindow viewWithTag:LoggerViewTag]) { [[keyWindow viewWithTag:LoggerViewTag] removeFromSuperview]; }
            UITextView *logger = [[UITextView alloc] initWithFrame:CGRectMake(10, 45, keyWindow.bounds.size.width - 170, 150)];
            logger.tag = LoggerViewTag;
            logger.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8];
            logger.textColor = [UIColor systemGreenColor];
            logger.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
            logger.editable = NO;
            logger.layer.borderColor = [UIColor systemGreenColor].CGColor;
            logger.layer.borderWidth = 1.0;
            logger.layer.cornerRadius = 5;
            g_screenLogger = logger;
            [keyWindow addSubview:g_screenLogger];
        });
    }
}

%new
// --- 核心深度侦查方法 ---
- (void)performDeepIvarReconnaissance {
    g_screenLogger.text = @""; // 清空日志
    EchoLog(@"开始V15 深度Ivar侦查...");
    
    // 1. 找到'三傳視圖'实例
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (!sanChuanContainerClass) { EchoLog(@"错误: 找不到'三傳視圖'类!"); return; }
    NSMutableArray *containers = [NSMutableArray array];
    FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, containers);
    if (containers.count == 0) { EchoLog(@"错误: 未找到'三傳視圖'实例!"); return; }
    UIView *sanChuanContainer = containers.firstObject;
    EchoLog(@"找到三传容器: %p", sanChuanContainer);

    // 2. 获取三个'傳視圖'实例
    const char *sanChuanIvarNames[] = {"初传", "中传", "末传", NULL};
    NSMutableArray *chuanViews = [NSMutableArray array];
    for (int i = 0; sanChuanIvarNames[i] != NULL; ++i) {
        Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, sanChuanIvarNames[i]);
        if (ivar) {
            id chuanView = object_getIvar(sanChuanContainer, ivar);
            if (chuanView) {
                [chuanViews addObject:chuanView];
            }
        }
    }
    
    if (chuanViews.count == 0) {
        EchoLog(@"错误: 未能从三传容器中读取到任何傳視圖实例!");
        return;
    }

    // 3. 遍历每个'傳視圖'实例，打印它的所有ivar
    Class chuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (!chuanViewClass) { EchoLog(@"错误: 找不到'傳視圖'类!"); return; }
    
    for (int i = 0; i < chuanViews.count; i++) {
        UIView *chuanView = chuanViews[i];
        EchoLog(@"\n===== 正在侦查 %s (%p) =====", sanChuanIvarNames[i], chuanView);
        
        unsigned int ivarCount;
        Ivar *ivars = class_copyIvarList(chuanViewClass, &ivarCount);
        
        if (ivars) {
            EchoLog(@" -> 找到 %d 个实例变量:", ivarCount);
            for (unsigned int j = 0; j < ivarCount; j++) {
                Ivar ivar = ivars[j];
                const char *ivarName = ivar_getName(ivar);
                const char *ivarType = ivar_getTypeEncoding(ivar);
                id ivarValue = object_getIvar(chuanView, ivar);
                EchoLog(@"   - 名称: %s, 类型: %s, 值: <%@: %p>", ivarName, ivarType, (ivarValue ? [ivarValue class] : @"(null)"), ivarValue);
            }
            free(ivars);
        } else {
            EchoLog(@" -> 未找到任何实例变量.");
        }
    }
    
    EchoLog(@"\n深度侦查完毕.");
}

%end
