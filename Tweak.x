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
static UITextView *g_debugLogView = nil; // 全局的调试日志窗口
static NSInteger g_stepCounter = 0;

// 向调试窗口追加日志，并自动滚动到底部
static void DebugLog(NSString *format, ...) {
    if (!g_debugLogView) return;
    
    va_list args;
    va_start(args, format);
    NSString *logMessage = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    NSString *fullLog = [NSString stringWithFormat:@"[%ld] %@\n", (long)++g_stepCounter, logMessage];
    NSLog(@"[TweakDebug] %@", logMessage); // 同时在控制台打印
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *newText = [g_debugLogView.text stringByAppendingString:fullLog];
        g_debugLogView.text = newText;
        // 自动滚动到底部
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
// 2. 主功能实现
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

                // 提取文本
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *labels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, labels);
                [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    CGFloat y1 = roundf(o1.frame.origin.y), y2 = roundf(o2.frame.origin.y);
                    if (y1 < y2) return NSOrderedAscending;
                    if (y1 > y2) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                NSMutableArray<NSString *> *texts = [NSMutableArray array];
                for (UILabel *label in labels) {
                    if (label.text.length > 0) [texts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                }
                NSString *fullDetail = [texts componentsJoinedByString:@"\n"];
                [g_capturedDetails addObject:fullDetail];
                DebugLog(@"[提取内容] 成功提取%ld个Label，内容:\n---BEGIN---\n%@\n---END---", (long)texts.count, fullDetail);

                // 关闭并驱动下一步
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

// --- 新增Hook: 监控目标方法的调用 ---
// 监控地支摘要的调用
- (void)顯示課傳摘要WithSender:(id)sender {
    if ([sender isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)sender;
        DebugLog(@"[监控] App调用'顯示課傳摘要WithSender:'，Sender是UILabel，文本:'%@', 地址:%p", label.text, label);
    } else {
        DebugLog(@"[监控] App调用'顯示課傳摘要WithSender:'，Sender类型:%@, 地址:%p", NSStringFromClass([sender class]), sender);
    }
    %orig;
}

// 监控天将摘要的调用
- (void)顯示課傳天將摘要WithSender:(id)sender {
     if ([sender isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)sender;
        DebugLog(@"[监控] App调用'顯示課傳天將摘要WithSender:'，Sender是UILabel，文本:'%@', 地址:%p", label.text, label);
    } else {
        DebugLog(@"[监控] App调用'顯示課傳天將摘要WithSender:'，Sender类型:%@, 地址:%p", NSStringFromClass([sender class]), sender);
    }
    %orig;
}


%new
// --- setupDebugModule: 创建所有UI元素 ---
- (void)setupDebugModule {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = self.view.window;
        if (!window) return;

        // 移除旧控件
        [[window viewWithTag:998801] removeFromSuperview];
        [[window viewWithTag:998802] removeFromSuperview];

        // 创建调试日志窗口
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

        // 创建功能按钮
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
    if (g_isExtracting) {
        DebugLog(@"[警告] 任务已在进行中!");
        return;
    }
    
    // 初始化
    g_isExtracting = YES;
    g_workQueue = [NSMutableArray array];
    g_titleQueue = [NSMutableArray array];
    g_capturedDetails = [NSMutableArray array];
    g_stepCounter = 0;
    g_debugLogView.text = @"";
    DebugLog(@"--- 开始新一轮提取任务 ---");

    // 构建队列 - 三传
    Class sanChuanClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanClass) {
        NSMutableArray *views = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanClass, self.view, views);
        if (views.count > 0) {
            UIView *c = views.firstObject;
            const char *ivars[] = {"初傳", "中傳", "末傳"};
            NSString *titles[] = {@"初传", @"中传", @"末传"};
            for (int i = 0; i < 3; ++i) {
                UIView *v = object_getIvar(c, class_getInstanceVariable(sanChuanClass, ivars[i]));
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
    
    DebugLog(@"[队列构建] 三传队列构建完成，共 %ld 项。", (long)g_workQueue.count);

    // 构建队列 - 四课
    // ... 四课逻辑与之前相同，为简洁此处省略，您可以按需添加 ...
    // ... 添加后记得也打印一条四课的日志 ...

    if (g_workQueue.count == 0) {
        DebugLog(@"[错误] 未找到任何可提取项，任务中止。");
        g_isExtracting = NO;
        return;
    }
    
    DebugLog(@"[启动] 队列构建完毕，共 %ld 个任务。开始执行...", (long)g_workQueue.count);
    [self processNextInQueue];
}

%new
// --- forceUIRefresh: 强制UI刷新 ---
- (void)forceUIRefresh {
    DebugLog(@"[刷新UI] 尝试强制刷新UI...");
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]]; // 短暂让出主线程
    DebugLog(@"[刷新UI] UI刷新操作完成。");
}

%new
// --- processNextInQueue: 队列处理器 ---
- (void)processNextInQueue {
    if (g_workQueue.count == 0) {
        DebugLog(@"--- 所有任务完成 ---");
        g_isExtracting = NO;
        NSMutableString *result = [NSMutableString string];
        for (NSUInteger i = 0; i < g_titleQueue.count; i++) {
            NSString *title = g_titleQueue[i];
            NSString *detail = (i < g_capturedDetails.count) ? g_capturedDetails[i] : @"[提取失败]";
            [result appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = result;
        DebugLog(@"[完成] 结果已复制到剪贴板。");
        return;
    }
    
    [self forceUIRefresh]; // 在每次点击前都尝试刷新一下UI

    UILabel *itemToClick = g_workQueue.firstObject;
    [g_workQueue removeObjectAtIndex:0];
    
    NSString *title = g_titleQueue[g_capturedDetails.count];
    DebugLog(@"[处理队列] 准备点击: '%@'", title);
    DebugLog(@"[处理队列] 目标UILabel文本:'%@', 地址:%p, Frame:%@", itemToClick.text, itemToClick, NSStringFromCGRect(itemToClick.frame));

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
