#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 辅助函数和宏
// =========================================================================

#define LOG_PREFIX @"[EchoTester] "
#define LogInfo(format, ...) NSLog(LOG_PREFIX @"INFO: " format, ##__VA_ARGS__)
#define LogError(format, ...) NSLog(LOG_PREFIX @"ERROR: " format, ##__VA_ARGS__)
#define LogSuccess(format, ...) NSLog(LOG_PREFIX @"SUCCESS: " format, ##__VA_ARGS__)

#define SUPPRESS_LEAK_WARNING(code) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    code; \
    _Pragma("clang diagnostic pop")

static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        frontmostWindow = window;
                        break;
                    }
                }
                if (frontmostWindow) break;
            }
        }
    }
    if (!frontmostWindow) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        frontmostWindow = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
    }
    return frontmostWindow;
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}

// =========================================================================
// 2. 接口声明
// =========================================================================

@interface UIViewController (EchoTester)
- (void)runTianDiPanTest;
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix;
@end

// =========================================================================
// 3. 核心 Hook
// =========================================================================

%hook UIViewController

// 在主界面添加测试按钮
- (void)viewDidLoad {
    %orig;
    
    // 确保只在目标ViewController上添加按钮
    if ([NSStringFromClass([self class]) containsString:@"ViewController"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = GetFrontmostWindow();
            if (!keyWindow) return;

            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 120, 45, 110, 36);
            [testButton setTitle:@"开始测试" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor orangeColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 18;
            [testButton addTarget:self action:@selector(runTianDiPanTest) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            LogInfo(@"测试按钮已添加到窗口。");
        });
    }
}

%new
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix {
    if (!object || !ivarNameSuffix) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) {
        free(ivars);
        return nil;
    }
    id value = nil;
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name) {
            NSString *ivarName = [NSString stringWithUTF8String:name];
            if ([ivarName hasSuffix:ivarNameSuffix]) {
                value = object_getIvar(object, ivar);
                break;
            }
        }
    }
    free(ivars);
    return value;
}

%new
- (void)runTianDiPanTest {
    LogInfo(@"================== 天地盘点击测试开始 ==================");

    // --- 步骤 1: 定位天地盘视图 ---
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類");
    if (!plateViewClass) {
        LogError(@"定位失败: 找不到 天地盤視圖 或 天地盤視圖類。");
        return;
    }
    
    NSMutableArray *plateViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);
    if (plateViews.count == 0) {
        LogError(@"定位失败: 在当前视图层级中找不到天地盘视图的实例。");
        return;
    }
    UIView *plateView = plateViews.firstObject;
    LogSuccess(@"步骤 1: 成功定位天地盘视图实例: %@", plateView);

    // --- 步骤 2: 获取天将字典 ---
    id tianJiangDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天將宮名列"];
    if (![tianJiangDict isKindOfClass:[NSDictionary class]] || ((NSDictionary *)tianJiangDict).count == 0) {
        LogError(@"数据获取失败: 未能获取天将字典(天將宮名列)，或字典为空。");
        return;
    }
    LogSuccess(@"步骤 2: 成功获取天将字典，包含 %lu 个条目。", (unsigned long)((NSDictionary *)tianJiangDict).count);

    // --- 步骤 3: 选取一个测试目标 ---
    NSDictionary *jiangDict = (NSDictionary *)tianJiangDict;
    NSString *testTargetName = jiangDict.allKeys.firstObject;
    id testTargetLayer = jiangDict.allValues.firstObject;

    if (!testTargetName || ![testTargetLayer isKindOfClass:[CALayer class]]) {
        LogError(@"选取目标失败: 字典中找不到有效的键或值。");
        return;
    }
    LogSuccess(@"步骤 3: 选取测试目标 '%@', Layer对象: %@", testTargetName, testTargetLayer);

    // --- 步骤 4: 准备调用 ---
    SEL selector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
    if (![self respondsToSelector:selector]) {
        LogError(@"方法探测失败: ViewController 不响应 '顯示天地盤觸摸WithSender:' 方法。");
        return;
    }
    LogSuccess(@"步骤 4: 确认 ViewController 响应目标方法。");

    // --- 步骤 5: 执行三种模式的调用测试 ---
    
    // **测试模式 A: 传递 CALayer 对象 (我们之前的最终方案)**
    @try {
        LogInfo(@"--- 开始测试模式 A: 传递 CALayer 对象 ---");
        SUPPRESS_LEAK_WARNING([self performSelector:selector withObject:testTargetLayer]);
        LogSuccess(@"模式 A: 调用成功执行，没有立即崩溃。");
    } @catch (NSException *exception) {
        LogError(@"模式 A: 调用时捕获到异常 (崩溃): %@, 原因: %@", exception.name, exception.reason);
    }
    
    // **测试模式 B: 传递 CALayer 的名字 (NSString)**
    @try {
        LogInfo(@"--- 开始测试模式 B: 传递 CALayer 的名字 (NSString) ---");
        SUPPRESS_LEAK_WARNING([self performSelector:selector withObject:testTargetName]);
        LogSuccess(@"模式 B: 调用成功执行，没有立即崩溃。");
    } @catch (NSException *exception) {
        LogError(@"模式 B: 调用时捕获到异常 (崩溃): %@, 原因: %@", exception.name, exception.reason);
    }

    // **测试模式 C: 传递 nil (安全探测)**
    @try {
        LogInfo(@"--- 开始测试模式 C: 传递 nil 参数 ---");
        SUPPRESS_LEAK_WARNING([self performSelector:selector withObject:nil]);
        LogSuccess(@"模式 C: 调用成功执行，没有立即崩溃。这通常意味着方法内部有对nil的检查。");
    } @catch (NSException *exception) {
        LogError(@"模式 C: 调用时捕获到异常 (崩溃): %@, 原因: %@", exception.name, exception.reason);
    }

    LogInfo(@"================== 天地盘点击测试结束 ==================");
}

%end

%ctor {
    NSLog(LOG_PREFIX @"测试脚本已加载。");
}
