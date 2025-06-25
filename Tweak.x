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

static void LogMessage(NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss.SSS"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSString *fullMessage = [logPrefix stringByAppendingString:message];
        g_logTextView.text = [NSString stringWithFormat:@"%@\n%@", fullMessage, g_logTextView.text];
        NSLog(@"[KeChuanExtractor] %@", message);
    });
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)startExtraction_Truth;
- (void)processKeChuanQueue_Truth;
- (void)createOrShowControlPanel_Truth;
- (void)copyAndClose_Truth;
// 【新】为课体添加调试方法
- (void)debug_ExploreKeTi;
@end

%hook UIViewController

// --- viewDidLoad, presentViewController, copyAndClose_Truth (无变化) ---
- (void)viewDidLoad { %orig; /* ... */ }
- (void)presentViewController:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))completion { /* ... */ }
%new
- (void)copyAndClose_Truth { /* ... */ }

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
    startButton.frame = CGRectMake(10, 10, 150, 40);
    [startButton setTitle:@"提取三传+四课" forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(startExtraction_Truth) forControlEvents:UIControlEventTouchUpInside];
    startButton.backgroundColor = [UIColor systemGreenColor]; [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; startButton.layer.cornerRadius = 8;
    
    // 【新】课体调试按钮
    UIButton *ketiDebugButton = [UIButton buttonWithType:UIButtonTypeSystem];
    ketiDebugButton.frame = CGRectMake(170, 10, 150, 40);
    [ketiDebugButton setTitle:@"探索课体(Debug)" forState:UIControlStateNormal];
    [ketiDebugButton addTarget:self action:@selector(debug_ExploreKeTi) forControlEvents:UIControlEventTouchUpInside];
    ketiDebugButton.backgroundColor = [UIColor systemRedColor]; [ketiDebugButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; ketiDebugButton.layer.cornerRadius = 8;
    
    // 复制按钮
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(10, 60, 150, 40);
    [copyButton setTitle:@"复制结果并关闭" forState:UIControlStateNormal];
    [copyButton addTarget:self action:@selector(copyAndClose_Truth) forControlEvents:UIControlEventTouchUpInside];
    copyButton.backgroundColor = [UIColor systemOrangeColor]; [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; copyButton.layer.cornerRadius = 8;
    
    // 日志窗口
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 110, g_controlPanelView.bounds.size.width - 20, g_controlPanelView.bounds.size.height - 120)];
    g_logTextView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0]; g_logTextView.textColor = [UIColor systemGreenColor]; g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12]; g_logTextView.editable = NO; g_logTextView.layer.cornerRadius = 8; g_logTextView.text = @"日志控制台已准备就绪。\n";
    
    [g_controlPanelView addSubview:startButton];
    [g_controlPanelView addSubview:ketiDebugButton];
    [g_controlPanelView addSubview:copyButton];
    [g_controlPanelView addSubview:g_logTextView];
    [keyWindow addSubview:g_controlPanelView];
}

// --- 原有功能，保持不变 ---
%new
- (void)startExtraction_Truth { /* ... */ }
%new
- (void)processKeChuanQueue_Truth { /* ... */ }
// 省略这些方法的完整实现，以保持清晰


// =========================================================================
// 【【【【【 新增的课体信息探索模块 】】】】】
// =========================================================================
%new
- (void)debug_ExploreKeTi {
    LogMessage(@"--- 开始【课体】信息探索 ---");

    Class ketiViewClass = NSClassFromString(@"六壬大占.課體視圖");
    if (!ketiViewClass) {
        LogMessage(@"【探索】错误：找不到 課體視圖 类。");
        return;
    }

    NSMutableArray *ketiViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(ketiViewClass, self.view, ketiViews);

    if (ketiViews.count == 0) {
        LogMessage(@"【探索】错误：在视图层级中找不到 課體視圖 的实例。");
        return;
    }
    
    UIView *ketiView = ketiViews.firstObject;
    LogMessage(@"【探索】成功找到 課體視圖 实例: %@", ketiView);

    // 使用 runtime 获取手势的所有目标-动作对
    Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
    if (!targetsIvar) {
         LogMessage(@"【探索】致命错误: 无法访问手势的 '_targets' 私有变量。无法继续。");
         return;
    }

    int gestureIndex = 0;
    for (UIGestureRecognizer *gesture in ketiView.gestureRecognizers) {
        LogMessage(@"\n\n============== 正在分析手势 #%d: %@ ==============", gestureIndex, [gesture class]);
        
        NSArray *targets = object_getIvar(gesture, targetsIvar);
        
        if (!targets || targets.count == 0) {
            LogMessage(@"【探索】手势 #%d 没有找到任何目标(target)。", gestureIndex);
            gestureIndex++;
            continue;
        }

        int targetIndex = 0;
        for (id targetWrapper in targets) {
            SEL action = NULL;
            id target = nil;
            @try {
                action = [targetWrapper performSelector:@selector(action)];
                target = [targetWrapper performSelector:@selector(target)];
            } @catch (NSException *exception) {
                LogMessage(@"【探索】获取 target/action 失败: %@", exception);
                continue;
            }

            if (target && action) {
                LogMessage(@"\n--- 手势 #%d 的目标 #%d ---", gestureIndex, targetIndex);
                LogMessage(@"【目标对象】: %@", target);
                LogMessage(@"【目标类名】: %@", [target class]);
                LogMessage(@"【执行动作】: %@", NSStringFromSelector(action));

                LogMessage(@"\n--- 开始列出目标对象【%@】的所有方法 ---", [target class]);
                unsigned int methodCount = 0;
                Method *methods = class_copyMethodList([target class], &methodCount);
                if (methods) {
                    for (unsigned int i = 0; i < methodCount; i++) {
                        Method method = methods[i];
                        NSString *methodName = NSStringFromSelector(method_getName(method));
                        // 筛选出我们可能感兴趣的方法
                        if ([methodName containsString:@"點擊"] || [methodName containsString:@"課"] || [methodName containsString:@"tap"] || [methodName containsString:@"handle"]) {
                            LogMessage(@"    - (找到可疑方法): %@", methodName);
                        }
                    }
                    free(methods);
                    LogMessage(@"--- 方法列表结束 ---");
                } else {
                    LogMessage(@"    - 无法获取该对象的方法列表。");
                }
            }
            targetIndex++;
        }
        gestureIndex++;
    }
    LogMessage("\n\n============== 探索完毕 ==============");
}

%end
