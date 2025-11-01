#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量与辅助函数 (修正版)
// =========================================================================

static UIView *g_mainControlPanelView = nil;
static UITextView *g_logTextView = nil;

// 任务控制相关的全局变量
static BOOL g_isTestRunning = NO;
static NSMutableArray *g_testWorkQueue = nil;
static NSMutableArray<NSString *> *g_testResults = nil;

// 一个简化的日志函数
static void LogMessage(NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
  
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSString *logLine = [NSString stringWithFormat:@"%@%@\n", logPrefix, message];
        
        g_logTextView.text = [logLine stringByAppendingString:g_logTextView.text];
        NSLog(@"[Echo独立测试脚本] %@", message);
    });
}

// 获取当前最顶层窗口的辅助函数 (兼容新版iOS)
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

// 递归查找手势的辅助函数
static void FindGesturesOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !aClass || !storage) return;
    for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
        if ([gesture isKindOfClass:aClass]) {
            [storage addObject:gesture];
        }
    }
    for (UIView *subview in view.subviews) {
        FindGesturesOfClassRecursive(aClass, subview, storage);
    }
}

// 递归查找弹窗内所有UILabel文本的辅助函数 (已修正)
static NSString* ExtractAllLabelsFromView(UIView *view) {
    if (!view) return @"[View is nil]";
    NSMutableArray<UILabel *> *labels = [NSMutableArray array];
    
    // __block 修正了递归Block的编译错误
    __block void (^findLabels)(UIView *);
    findLabels = ^(UIView *currentView) {
        if ([currentView isKindOfClass:[UILabel class]]) {
            [labels addObject:(UILabel *)currentView];
        }
        for (UIView *subview in currentView.subviews) {
            findLabels(subview);
        }
    };
    findLabels(view);
    
    [labels sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
        if (obj1.frame.origin.y < obj2.frame.origin.y) return NSOrderedAscending;
        if (obj1.frame.origin.y > obj2.frame.origin.y) return NSOrderedDescending;
        return NSOrderedSame;
    }];

    NSMutableString *result = [NSMutableString string];
    for (UILabel *label in labels) {
        if (label.text && label.text.length > 0) {
            [result appendFormat:@"%@\n", label.text];
        }
    }
    return [result stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}


// =========================================================================
// 2. 核心Hook：拦截弹窗
// =========================================================================

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    
    if (g_isTestRunning) {
        // 使用正确的中文类名进行判断
        Class tianJiangPopupClass = NSClassFromString(@"_TtC12六壬大占18天將摘要視圖");

        // 移除了未使用的 tianDiPanPopupClass
        if (tianJiangPopupClass && [vcToPresent isKindOfClass:tianJiangPopupClass]) {
            LogMessage(@"成功拦截到 [天将摘要视图] 弹窗！");
            
            [vcToPresent loadViewIfNeeded];
            
            NSString *extractedText = ExtractAllLabelsFromView(vcToPresent.view);
            [g_testResults addObject:extractedText];
            LogMessage(@"提取内容:\n---\n%@\n---", extractedText);

            dispatch_async(dispatch_get_main_queue(), ^{
                [self performSelector:@selector(processTestQueue)];
            });
            
            return;
        }
    }

    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}


// =========================================================================
// 3. Tweak核心逻辑 (修正版)
// =========================================================================
// 关键修正: 为了让Theos预处理器正确识别Swift类, %hook指令我们暂时用回乱码名
// 这仅仅是给编译器看的"密码"，代码内部我们全部使用正确的中文名
%hook _TtC12å…­å£¬å¤§å  14ViewController

// ---- 3.1 核心测试流程 ----
%new
- (void)runTianJiangExtractionTest {
    if (g_isTestRunning) {
        LogMessage(@"测试已在运行中，请勿重复点击。");
        return;
    }
    LogMessage(@"[测试启动] 开始提取天地盘上的'天将'详情...");
    
    g_isTestRunning = YES;
    g_testWorkQueue = [NSMutableArray array];
    g_testResults = [NSMutableArray array];

    UIView *tianDiPanView = MSHookIvar<UIView *>(self, "天地盤視圖");
    if (!tianDiPanView) {
        LogMessage(@"[致命错误] 找不到'天地盤視圖'实例！测试中止。");
        g_isTestRunning = NO;
        return;
    }
    LogMessage(@"成功定位到'天地盤視圖'。");

    // 使用正确的中文类名字符串
    Class tianJiangGestureClass = NSClassFromString(@"_TtCC12六壬大占14ViewController18天將觸摸手勢");
    if (!tianJiangGestureClass) {
        LogMessage(@"[致命错误] 找不到'天将触摸手势'类！请确认类名正确。测试中止。");
        g_isTestRunning = NO;
        return;
    }
    LogMessage(@"成功找到'天将触摸手势'类定义。");

    FindGesturesOfClassRecursive(tianJiangGestureClass, tianDiPanView, g_testWorkQueue);

    if (g_testWorkQueue.count == 0) {
        LogMessage(@"[错误] 未找到任何'天将'手势！测试中止。");
        g_isTestRunning = NO;
        return;
    }
    
    LogMessage(@"成功定位到 %lu 个'天将'手势，任务队列已创建。", (unsigned long)g_testWorkQueue.count);

    [self processTestQueue];
}

// ---- 3.2 队列处理函数 ----
%new
- (void)processTestQueue {
    if (g_testWorkQueue.count == 0) {
        LogMessage(@"[测试完成] 所有 %lu 个天将详情已提取完毕！", (unsigned long)g_testResults.count);
        
        NSMutableString *finalReport = [NSMutableString string];
        [finalReport appendString:@"\n\n======= 最终提取结果 =======\n"];
        for (NSString *result in g_testResults) {
            [finalReport appendFormat:@"\n--- 单项结果 ---\n%@\n", result];
        }
        LogMessage(@"%@", finalReport);

        g_isTestRunning = NO;
        return;
    }

    UIGestureRecognizer *gesture = g_testWorkQueue.firstObject;
    [g_testWorkQueue removeObjectAtIndex:0];
    
    id positionInfo = [gesture valueForKey:@"位"];
    LogMessage(@"[任务 %lu/%lu] 正在触发手势: 天将 - %@", (unsigned long)(g_testResults.count + 1), (unsigned long)(g_testResults.count + g_testWorkQueue.count + 1), positionInfo);

    NSArray *targets = [gesture valueForKey:@"_targets"];
    if (!targets || targets.count == 0) {
        LogMessage(@"[错误] 手势没有target！跳过。");
        [self processTestQueue];
        return;
    }
    
    id targetActionPair = targets.firstObject;
    id realTarget = [targetActionPair valueForKey:@"_target"];
    SEL realAction = NSSelectorFromString([targetActionPair valueForKey:@"_action"]);

    if (realTarget && realAction && [realTarget respondsToSelector:realAction]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [realTarget performSelector:realAction withObject:gesture];
        #pragma clang diagnostic pop
    } else {
        LogMessage(@"[错误] 无法触发手势，target或action无效。跳过。");
        [self processTestQueue];
    }
}

// ---- 3.3 创建简化的UI面板 ----
%new
- (void)createOrShowTestControlPanel {
    if (g_mainControlPanelView && g_mainControlPanelView.superview) {
        [g_mainControlPanelView removeFromSuperview];
        g_mainControlPanelView = nil;
        g_logTextView = nil;
        return;
    }
    
    UIWindow *keyWindow = GetFrontmostWindow(); // 使用修正后的辅助函数
    if (!keyWindow) { return; }

    g_mainControlPanelView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    g_mainControlPanelView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    [keyWindow addSubview:g_mainControlPanelView];
    
    // ... UI布局代码保持不变 ...
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, keyWindow.bounds.size.width - 40, 30)];
    titleLabel.text = @"Echo 独立测试脚本";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [g_mainControlPanelView addSubview:titleLabel];
    
    UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
    testButton.frame = CGRectMake(50, 100, keyWindow.bounds.size.width - 100, 50);
    [testButton setTitle:@"开始提取天地盘-天将详情" forState:UIControlStateNormal];
    testButton.backgroundColor = [UIColor systemBlueColor];
    [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    testButton.layer.cornerRadius = 10;
    [testButton addTarget:self action:@selector(runTianJiangExtractionTest) forControlEvents:UIControlEventTouchUpInside];
    [g_mainControlPanelView addSubview:testButton];
    
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 170, keyWindow.bounds.size.width - 40, keyWindow.bounds.size.height - 250)];
    g_logTextView.backgroundColor = [UIColor blackColor];
    g_logTextView.textColor = [UIColor greenColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO;
    g_logTextView.text = @"日志记录:\n";
    g_logTextView.layer.cornerRadius = 5;
    [g_mainControlPanelView addSubview:g_logTextView];
    
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(50, keyWindow.bounds.size.height - 70, keyWindow.bounds.size.width - 100, 40);
    [closeButton setTitle:@"关闭面板" forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(createOrShowTestControlPanel) forControlEvents:UIControlEventTouchUpInside];
    [g_mainControlPanelView addSubview:closeButton];
}

// 替换 viewDidLoad 来添加我们的触发按钮
- (void)viewDidLoad {
    %orig;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = GetFrontmostWindow();
        if (!keyWindow) return;

        UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
        controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
        [controlButton setTitle:@"推衍课盘(测试)" forState:UIControlStateNormal];
        controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        controlButton.backgroundColor = [UIColor systemOrangeColor];
        [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        controlButton.layer.cornerRadius = 18;
        [controlButton addTarget:self action:@selector(createOrShowTestControlPanel) forControlEvents:UIControlEventTouchUpInside];
        [keyWindow addSubview:controlButton];
    });
}

%end


// =========================================================================
// 4. 构造器：应用Hook
// =========================================================================

%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[Echo独立测试脚本] 已加载。");
    }
}
