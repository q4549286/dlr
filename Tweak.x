#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局状态与调试模块
// =========================================================================

static BOOL g_isExtracting = NO;
static NSMutableArray *g_workQueue = nil;
static NSMutableArray *g_titleQueue = nil;
static NSMutableArray *g_capturedDetails = nil;

// --- 调试模块 ---
static UITextView *g_debugLogView = nil;
static NSInteger g_stepCounter = 0;

static void DebugLog(NSString *format, ...) {
    if (!g_debugLogView) return;
    va_list args;
    va_start(args, format);
    NSString *logMessage = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSString *fullLog = [NSString stringWithFormat:@"[%ld] %@\n", (long)++g_stepCounter, logMessage];
    NSLog(@"[TweakDebug] %@", logMessage);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *newText = [g_debugLogView.text stringByAppendingString:fullLog];
        g_debugLogView.text = newText;
        if (newText.length > 0) {
            [g_debugLogView scrollRangeToVisible:NSMakeRange(newText.length - 1, 1)];
        }
    });
}

// 辅助函数
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 运行时Hook中文方法
// =========================================================================

// 保存原始方法实现的指针
static IMP g_orig_showKeChuanSummary = nil;
static IMP g_orig_showTianJiangSummary = nil;

// 我们自己的C函数实现，用于替换原始方法
static void MyShowKeChuanSummary(id self, SEL _cmd, id sender) {
    if ([sender isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)sender;
        DebugLog(@"[监控] App调用'顯示課傳摘要WithSender:'，Sender是UILabel，文本:'%@', 地址:%p", label.text, label);
    } else {
        DebugLog(@"[监控] App调用'顯示課傳摘要WithSender:'，Sender类型:%@, 地址:%p", NSStringFromClass([sender class]), sender);
    }
    // 调用原始实现
    ((void (*)(id, SEL, id))g_orig_showKeChuanSummary)(self, _cmd, sender);
}

static void MyShowTianJiangSummary(id self, SEL _cmd, id sender) {
    if ([sender isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)sender;
        DebugLog(@"[监控] App调用'顯示課傳天將摘要WithSender:'，Sender是UILabel，文本:'%@', 地址:%p", label.text, label);
    } else {
        DebugLog(@"[监控] App调用'顯示課傳天將摘要WithSender:'，Sender类型:%@, 地址:%p", NSStringFromClass([sender class]), sender);
    }
    // 调用原始实现
    ((void (*)(id, SEL, id))g_orig_showTianJiangSummary)(self, _cmd, sender);
}

// =========================================================================
// 3. 主功能实现
// =========================================================================
@interface UIViewController (FinalDebugAddons)
- (void)setupDebugModule;
- (void)startExtractionProcess;
- (void)processNextInQueue;
- (void)forceUIRefresh;
@end

%hook UIViewController

// --- viewDidLoad: 注入功能按钮和调试窗口 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        [self setupDebugModule];
    }
}

// --- presentViewController: 核心拦截逻辑 ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtracting) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            DebugLog(@"[拦截成功] 捕获到弹窗: %@ (地址: %p)", vcClassName, viewControllerToPresent);
            
            viewControllerToPresent.view.alpha = 0.0f;
            flag = NO;

            void (^extractionCompletion)(void) = ^{
                if (completion) { completion(); }

                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, labels);
                [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    CGFloat y1 = roundf(o1.frame.origin.y), y2 = roundf(o2.frame.origin.y);
                    if (y1 < y2) return NSOrderedAscending; if (y1 > y2) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                NSMutableArray<NSString *> *texts = [NSMutableArray array];
                for (UILabel *label in labels) { if (label.text.length > 0) [texts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; }
                NSString *fullDetail = [texts componentsJoinedByString:@"\n"];
                [g_capturedDetails addObject:fullDetail];
                DebugLog(@"[提取内容] 成功提取%ld个Label", (long)texts.count);

                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    DebugLog(@"[关闭弹窗] 已关闭弹窗: %p。延迟后继续...", viewControllerToPresent);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processNextInQueue];
                    });
                }];
            };
            
            %orig(viewControllerToPresent, flag, extractionCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
// --- setupDebugModule: 创建所有UI元素 ---
- (void)setupDebugModule {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = self.view.window; if (!window) return;

        [[window viewWithTag:998801] removeFromSuperview];
        [[window viewWithTag:998802] removeFromSuperview];

        g_debugLogView = [[UITextView alloc] initWithFrame:CGRectMake(10, window.bounds.size.height - 260, window.bounds.size.width - 20, 200)];
        g_debugLogView.tag = 998801;
        g_debugLogView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
        g_debugLogView.textColor = [UIColor greenColor];
        g_debugLogView.font = [UIFont fontWithName:@"Menlo" size:10];
        g_debugLogView.editable = NO;
        g_debugLogView.layer.borderColor = [UIColor greenColor].CGColor;
        g_debugLogView.layer.borderWidth = 1;
        g_debugLogView.layer.cornerRadius = 8;
        [window addSubview:g_debugLogView];
        
        DebugLog(@"调试模块已加载。");

        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(window.bounds.size.width - 160, 50, 150, 40);
        button.tag = 998802;
        [button setTitle:@"启动调试提取" forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        button.backgroundColor = [UIColor systemOrangeColor];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.layer.cornerRadius = 8;
        [button addTarget:self action:@selector(startExtractionProcess) forControlEvents:UIControlEventTouchUpInside];
        [window addSubview:button];
    });
}

%new
// --- startExtractionProcess: 流程起点 ---
- (void)startExtractionProcess {
    if (g_isExtracting) { DebugLog(@"[警告] 任务已在进行中!"); return; }
    
    g_isExtracting = YES; g_workQueue = [NSMutableArray array];
    g_titleQueue = [NSMutableArray array]; g_capturedDetails = [NSMutableArray array];
    g_stepCounter = 0; g_debugLogView.text = @"";
    DebugLog(@"--- 开始新一轮提取任务 ---");

    // 构建队列... (三传 & 四课)
    Class sanChuanClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanClass) {
        NSMutableArray *views = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanClass, self.view, views);
        if (views.count > 0) {
            UIView *c = views.firstObject;
            const char *ivars[] = {"初傳", "中傳", "末傳"};
            NSString *titles[] = {@"初传", @"中传", @"末传"};
            for (int i = 0; i < 3; ++i) {
                Ivar ivar = class_getInstanceVariable(sanChuanClass, ivars[i]);
                if (ivar) {
                     UIView *v = object_getIvar(c, ivar);
                     if (v) {
                        NSMutableArray *l = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], v, l);
                        [l sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
                        if (l.count >= 2) {
                            UILabel *dizhi = l[l.count-2], *tianjiang = l[l.count-1];
                            [g_workQueue addObject:dizhi]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", titles[i], dizhi.text]];
                            [g_workQueue addObject:tianjiang]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", titles[i], tianjiang.text]];
                        }
                    }
                }
            }
        }
    }
    DebugLog(@"[队列构建] 三传队列构建完成。");
    // 您可以在此添加四课的构建逻辑
    
    if (g_workQueue.count == 0) { DebugLog(@"[错误] 未找到任何可提取项，任务中止。"); g_isExtracting = NO; return; }
    
    DebugLog(@"[启动] 队列构建完毕，共 %ld 个任务。开始执行...", (long)g_workQueue.count);
    [self processNextInQueue];
}

%new
- (void)forceUIRefresh { /* 之前定义的强制刷新方法，保持不变 */ }

%new
- (void)processNextInQueue {
    if (g_workQueue.count == 0) {
        DebugLog(@"--- 所有任务完成 ---");
        g_isExtracting = NO;
        NSMutableString *result = [NSMutableString string];
        for (NSUInteger i = 0; i < g_titleQueue.count; i++) {
            [result appendFormat:@"--- %@ ---\n%@\n\n", g_titleQueue[i], (i < g_capturedDetails.count) ? g_capturedDetails[i] : @"[提取失败]"];
        }
        [UIPasteboard generalPasteboard].string = result;
        DebugLog(@"[完成] 结果已复制到剪贴板。");
        return;
    }
    
    UILabel *itemToClick = g_workQueue.firstObject; [g_workQueue removeObjectAtIndex:0];
    NSString *title = g_titleQueue[g_capturedDetails.count];
    DebugLog(@"[处理队列] 准备点击: '%@'", title);
    DebugLog(@"[处理队列] 目标UILabel文本:'%@', 地址:%p", itemToClick.text, itemToClick);

    SEL action = [title containsString:@"地支"] ? NSSelectorFromString(@"顯示課傳摘要WithSender:") : NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    
    if ([self respondsToSelector:action]) {
        DebugLog(@"[执行点击] 调用方法: %@", NSStringFromSelector(action));
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:action withObject:itemToClick];
        #pragma clang diagnostic pop
    } else {
        DebugLog(@"[错误] 方法 %@ 未找到，跳过此任务。", NSStringFromSelector(action));
        [self processNextInQueue];
    }
}
%end

// 使用构造函数来执行运行时Hook，这是最标准和安全的方式
%ctor {
    Class vcClass = NSClassFromString(@"六壬大占.ViewController");
    if (vcClass) {
        // Hook地支摘要方法
        SEL selKeChuan = NSSelectorFromString(@"顯示課傳摘要WithSender:");
        Method methodKeChuan = class_getInstanceMethod(vcClass, selKeChuan);
        if (methodKeChuan) {
            g_orig_showKeChuanSummary = method_setImplementation(methodKeChuan, (IMP)MyShowKeChuanSummary);
        }

        // Hook天将摘要方法
        SEL selTianJiang = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
        Method methodTianJiang = class_getInstanceMethod(vcClass, selTianJiang);
        if (methodTianJiang) {
            g_orig_showTianJiangSummary = method_setImplementation(methodTianJiang, (IMP)MyShowTianJiangSummary);
        }
    }
}
