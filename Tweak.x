#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量与辅助函数 (v6 最终版)
// =========================================================================

static UIView *g_mainControlPanelView = nil;
static UITextView *g_logTextView = nil;

static BOOL g_isTestRunning = NO;
static NSMutableArray *g_testWorkQueue = nil;
static NSMutableArray<NSString *> *g_testResults = nil;

// 日志函数
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

// 获取窗口函数
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

// 查找手势函数
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

// 提取Label文本函数
static void FindAllLabelsRecursive(UIView *view, NSMutableArray<UILabel *> *labels) {
    if ([view isKindOfClass:[UILabel class]]) {
        [labels addObject:(UILabel *)view];
    }
    for (UIView *subview in view.subviews) {
        FindAllLabelsRecursive(subview, labels);
    }
}
static NSString* ExtractAllLabelsFromView(UIView *view) {
    if (!view) return @"[View is nil]";
    NSMutableArray<UILabel *> *labels = [NSMutableArray array];
    
    FindAllLabelsRecursive(view, labels);
    
    [labels sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
        CGPoint obj1Origin = [obj1.superview convertPoint:obj1.frame.origin toView:nil];
        CGPoint obj2Origin = [obj2.superview convertPoint:obj2.frame.origin toView:nil];
        if (obj1Origin.y < obj2Origin.y) return NSOrderedAscending;
        if (obj1Origin.y > obj2Origin.y) return NSOrderedDescending;
        if (obj1Origin.x < obj2Origin.x) return NSOrderedAscending;
        if (obj1Origin.x > obj2Origin.x) return NSOrderedDescending;
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
// 2. 核心Hook：拦截弹窗 (保持不变)
// =========================================================================

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    
    if (g_isTestRunning) {
        Class tianJiangPopupClass = NSClassFromString(@"_TtC12六壬大占18天將摘要視圖");
        Class tianDiPanPopupClass = NSClassFromString(@"_TtC12六壬大占27天地盤宮位摘要視圖");

        if ((tianJiangPopupClass && [vcToPresent isKindOfClass:tianJiangPopupClass]) || (tianDiPanPopupClass && [vcToPresent isKindOfClass:tianDiPanPopupClass])) {
            LogMessage(@"成功拦截到弹窗: %@", NSStringFromClass([vcToPresent class]));
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
// 3. Tweak核心逻辑 (v6 纯运行时实现)
// =========================================================================

// --- 我们将所有新方法作为独立的C函数来实现，然后在运行时添加到类中 ---

void runTianJiangExtractionTest(id self, SEL _cmd) {
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

    [self performSelector:@selector(processTestQueue)];
}

void processTestQueue(id self, SEL _cmd) {
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
        [self performSelector:@selector(processTestQueue)];
        return;
    }
    
    id targetActionPair = targets.firstObject;
    id realTarget = [targetActionPair valueForKey:@"_target"];
    SEL realAction = NSSelectorFromString(NSStringFromSelector((SEL)[targetActionPair valueForKey:@"_action"]));

    if (realTarget && realAction && [realTarget respondsToSelector:realAction]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [realTarget performSelector:realAction withObject:gesture];
        #pragma clang diagnostic pop
    } else {
        LogMessage(@"[错误] 无法触发手势，target或action无效。跳过。");
        [self performSelector:@selector(processTestQueue)];
    }
}

void createOrShowTestControlPanel(id self, SEL _cmd) {
    if (g_mainControlPanelView && g_mainControlPanelView.superview) {
        [g_mainControlPanelView removeFromSuperview];
        g_mainControlPanelView = nil;
        g_logTextView = nil;
        return;
    }
    
    UIWindow *keyWindow = GetFrontmostWindow();
    if (!keyWindow) { return; }

    g_mainControlPanelView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    g_mainControlPanelView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    [keyWindow addSubview:g_mainControlPanelView];
    
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

// 这是我们将要Hook的 viewDidLoad 的新实现
static void (*Original_ViewController_viewDidLoad)(id, SEL);
static void Tweak_ViewController_viewDidLoad(UIViewController *self, SEL _cmd) {
    Original_ViewController_viewDidLoad(self, _cmd); // 调用原始方法

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = GetFrontmostWindow();
        if (!keyWindow) return;
        if ([keyWindow viewWithTag:888888]) return;

        UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
        controlButton.frame = CGRectMake(self.view.bounds.size.width - 150, 45, 140, 36);
        controlButton.tag = 888888;
        [controlButton setTitle:@"推衍课盘(测试)" forState:UIControlStateNormal];
        controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        controlButton.backgroundColor = [UIColor systemOrangeColor];
        [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        controlButton.layer.cornerRadius = 18;
        [controlButton addTarget:self action:@selector(createOrShowTestControlPanel) forControlEvents:UIControlEventTouchUpInside];
        [keyWindow addSubview:controlButton];
    });
}


// =========================================================================
// 4. 构造器：应用Hook (v6 纯运行时最终版)
// =========================================================================
%ctor {
    @autoreleasepool {
        // 全局Hook presentViewController
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);

        // 在运行时查找目标ViewController类
        Class vcClass = objc_getClass("_TtC12六壬大占14ViewController");
        if (vcClass) {
            // 动态地将我们的C函数作为新方法添加到这个类里
            class_addMethod(vcClass, @selector(runTianJiangExtractionTest), (IMP)runTianJiangExtractionTest, "v@:");
            class_addMethod(vcClass, @selector(processTestQueue), (IMP)processTestQueue, "v@:");
            class_addMethod(vcClass, @selector(createOrShowTestControlPanel), (IMP)createOrShowTestControlPanel, "v@:");
            
            // 使用 MSHookMessageEx 手动Hook viewDidLoad 方法
            MSHookMessageEx(vcClass, @selector(viewDidLoad), (IMP)&Tweak_ViewController_viewDidLoad, (IMP *)&Original_ViewController_viewDidLoad);
            
            NSLog(@"[Echo独立测试脚本] 已加载并动态Hook成功。");
        } else {
            NSLog(@"[Echo独立测试脚本] 错误：无法在运行时找到 _TtC12六壬大占14ViewController 类！");
        }
    }
}
