#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数 (无变化)
// =========================================================================
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray<NSDictionary *> *g_keChuanWorkQueue = nil;
static NSMutableArray<NSString *> *g_keChuanTitleQueue = nil;

static UITextView *g_logTextView = nil;
static UIView *g_controlPanelView = nil;

static void LogMessage(NSString *format, ...) { /* ... 实现与之前相同 ... */ }
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { /* ... 实现与之前相同 ... */ }

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)startExtraction_Truth;
- (void)processKeChuanQueue_Truth;
- (void)createOrShowControlPanel_Truth;
- (void)copyAndClose_Truth;
// 【新】懒加载安全的课体侦测方法
- (void)debug_ExploreKeTi_V3;
@end

%hook UIViewController

// --- viewDidLoad, presentViewController, 等核心功能与之前版本相同 ---
// --- 此处省略这些方法的实现以保持清晰 ---

// =========================================================================
// 【【【【【 全新的课体侦测模块 】】】】】
// =========================================================================
%new
- (void)createOrShowControlPanel_Truth {
    UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
    NSInteger panelTag = 556692;
    if (g_controlPanelView && g_controlPanelView.superview) {
        [g_controlPanelView removeFromSuperview]; g_controlPanelView = nil; g_logTextView = nil; return;
    }
    g_controlPanelView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, keyWindow.bounds.size.width - 20, keyWindow.bounds.size.height - 200)];
    g_controlPanelView.tag = panelTag;
    g_controlPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
    g_controlPanelView.layer.cornerRadius = 12; g_controlPanelView.clipsToBounds = YES;
    
    // 主功能按钮
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    startButton.frame = CGRectMake(10, 10, 160, 40);
    [startButton setTitle:@"提取三传+四课" forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(startExtraction_Truth) forControlEvents:UIControlEventTouchUpInside];
    startButton.backgroundColor = [UIColor systemGreenColor]; [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; startButton.layer.cornerRadius = 8;
    
    // 【新】课体侦测按钮
    UIButton *debugButton = [UIButton buttonWithType:UIButtonTypeSystem];
    debugButton.frame = CGRectMake(180, 10, 160, 40);
    [debugButton setTitle:@"侦测课体(V3)" forState:UIControlStateNormal];
    [debugButton addTarget:self action:@selector(debug_ExploreKeTi_V3) forControlEvents:UIControlEventTouchUpInside];
    debugButton.backgroundColor = [UIColor systemRedColor]; [debugButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; debugButton.layer.cornerRadius = 8;
    
    // 其他UI元素...
    [g_controlPanelView addSubview:startButton];
    [g_controlPanelView addSubview:debugButton];
    // ...
}

%new
- (void)debug_ExploreKeTi_V3 {
    LogMessage(@"--- 开始【课体】侦测 (V3 - 懒加载安全) ---");

    // 步骤 1: 尝试找到课体容器视图
    Class keTiContainerClass = NSClassFromString(@"六壬大占.課體視圖");
    if (!keTiContainerClass) { LogMessage(@"【侦测】致命错误: 找不到 課體視圖 类。"); return; }

    NSMutableArray *keTiContainers = [NSMutableArray array];
    FindSubviewsOfClassRecursive(keTiContainerClass, self.view, keTiContainers);
    
    UIView *keTiContainer = nil;
    if (keTiContainers.count > 0) {
        keTiContainer = keTiContainers.firstObject;
        LogMessage(@"【侦测】成功在视图层级中找到 課體視圖: %@", keTiContainer);
    } else {
        LogMessage(@"【侦测】视图层级中未找到 課體視圖，可能是懒加载。");
        // 如果您找到了相关Ivar，请在这里替换 " संभावितIvar名 "
        const char *ivarNameToTry = "課體"; // 这是一个猜测，需要您的情报
        Ivar keTiIvar = class_getInstanceVariable([self class], ivarNameToTry);
        if (keTiIvar) {
            keTiContainer = object_getIvar(self, keTiIvar);
            if (keTiContainer) {
                 LogMessage(@"【侦测】成功通过Ivar '%s' 获取到 課體視圖: %@", ivarNameToTry, keTiContainer);
            } else {
                 LogMessage(@"【侦测】Ivar '%s' 存在但值为nil。", ivarNameToTry);
            }
        } else {
            LogMessage(@"【侦测】在ViewController中也找不到名为 '%s' 的Ivar。", ivarNameToTry);
        }
    }

    if (!keTiContainer) {
        LogMessage(@"【侦测】彻底失败：无法定位到 課體視圖。侦测结束。");
        return;
    }

    // 步骤 2: 找到第一个课体单元进行分析
    Class keTiUnitClass = NSClassFromString(@"六壬大占.課體單元");
    NSMutableArray *keTiUnits = [NSMutableArray array];
    FindSubviewsOfClassRecursive(keTiUnitClass, keTiContainer, keTiUnits);

    if (keTiUnits.count == 0) {
        LogMessage(@"【侦测】在課體視圖中未找到任何 課體單元。");
        return;
    }

    UIView *firstUnit = keTiUnits.firstObject;
    LogMessage(@"\n============== 开始分析第一个课体单元 ==============");
    LogMessage(@"【单元视图】: %@", firstUnit);
    
    NSMutableArray *labelsInUnit = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], firstUnit, labelsInUnit);
    UILabel *titleLabel = labelsInUnit.firstObject;
    LogMessage(@"【单元文本】: '%@'", titleLabel ? titleLabel.text : @"<无>");

    // 步骤 3: 分析手势，找出 Target 和 Action
    if (firstUnit.gestureRecognizers.count == 0) {
        LogMessage(@"【侦测】错误：该单元上没有任何手势。");
        return;
    }
    
    UIGestureRecognizer *gesture = firstUnit.gestureRecognizers.firstObject;
    LogMessage(@"【单元手势】: %@", gesture);

    Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
    if (!targetsIvar) { LogMessage(@"【侦测】无法访问手势的 '_targets'。"); return; }
    
    NSArray *targets = object_getIvar(gesture, targetsIvar);
    if (!targets || targets.count == 0) { LogMessage(@"【侦测】手势没有目标。"); return; }

    id targetWrapper = targets.firstObject;
    id target = nil;
    SEL action = NULL;

    @try {
        target = [targetWrapper valueForKey:@"target"];
        NSValue *actionValue = [targetWrapper valueForKey:@"action"];
        if (actionValue) action = [actionValue pointerValue];
    } @catch (NSException *exception) {
        LogMessage(@"【侦测】获取target/action失败: %@", exception);
        return;
    }

    if (!target || !action) {
        LogMessage(@"【侦测】无法从手势中解析出 Target 或 Action。");
        return;
    }
    
    LogMessage(@"\n============== 核心情报 ==============");
    LogMessage(@"【手势目标 Target】: %@", target);
    LogMessage(@"【目标类名】: %@", [target class]);
    LogMessage(@"【执行方法 Action】: %@", NSStringFromSelector(action));
    LogMessage(@"=====================================");

    // 步骤 4: 列出 ViewController 的所有 Ivars，供我们检查是否需要设置
    LogMessage(@"\n--- ViewController 的所有实例变量(Ivars) ---");
    unsigned int ivarCount = 0;
    Ivar *ivars = class_copyIvarList([self class], &ivarCount);
    for(unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        LogMessage(@"Ivar: %s, 类型: %s", ivar_getName(ivar), ivar_getTypeEncoding(ivar));
    }
    free(ivars);
    LogMessage(@"--- Ivar 列表结束 ---");
    LogMessage(@"\n============== 侦测完毕 ==============");
}

%end
