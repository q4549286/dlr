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
        if (newText.length > 0) [g_debugLogView scrollRangeToVisible:NSMakeRange(newText.length - 1, 1)];
    });
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能实现
// =========================================================================
@interface UIViewController (FinalSolutionAddons)
- (void)setupDebugModule;
- (void)startExtractionProcess;
- (void)processNextInQueue;
- (void)simulateTapOnView:(UIView *)view;
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

// --- presentViewController: 核心拦截逻辑 (保持不变) ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtracting) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            DebugLog(@"[拦截成功] 捕获到弹窗: %@", vcClassName);
            viewControllerToPresent.view.alpha = 0.0f;
            flag = NO;
            void (^extractionCompletion)(void) = ^{
                if (completion) { completion(); }
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *labels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, labels);
                [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    CGFloat y1 = roundf(o1.frame.origin.y), y2 = roundf(o2.frame.origin.y);
                    if (y1 < y2) return NSOrderedAscending; if (y1 > y2) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                NSMutableArray<NSString *> *texts = [NSMutableArray array];
                for (UILabel *label in labels) { if (label.text.length > 0) [texts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; }
                NSString *fullDetail = [texts componentsJoinedByString:@"\n"];
                [g_capturedDetails addObject:fullDetail];
                DebugLog(@"[提取内容] 成功提取到内容。");
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    DebugLog(@"[关闭弹窗] 延迟后继续...");
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
- (void)setupDebugModule {
    // (与上一版相同，保持不变)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = self.view.window; if (!window) return;
        [[window viewWithTag:998801] removeFromSuperview]; [[window viewWithTag:998802] removeFromSuperview];
        g_debugLogView = [[UITextView alloc] initWithFrame:CGRectMake(10, window.bounds.size.height - 260, window.bounds.size.width - 20, 200)];
        g_debugLogView.tag = 998801; g_debugLogView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7]; g_debugLogView.textColor = [UIColor systemGreenColor]; g_debugLogView.font = [UIFont fontWithName:@"Menlo" size:10]; g_debugLogView.editable = NO; g_debugLogView.layer.borderColor = [UIColor greenColor].CGColor; g_debugLogView.layer.borderWidth = 1; g_debugLogView.layer.cornerRadius = 8;
        [window addSubview:g_debugLogView];
        DebugLog(@"调试模块已加载(真实点击版)。");
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(window.bounds.size.width - 160, 50, 150, 40); button.tag = 998802;
        [button setTitle:@"启动真实点击提取" forState:UIControlStateNormal]; button.titleLabel.font = [UIFont boldSystemFontOfSize:15]; button.backgroundColor = [UIColor systemRedColor]; [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; button.layer.cornerRadius = 8;
        [button addTarget:self action:@selector(startExtractionProcess) forControlEvents:UIControlEventTouchUpInside];
        [window addSubview:button];
    });
}

%new
- (void)startExtractionProcess {
    // (与上一版相同，保持不变，但补全了四课)
    if (g_isExtracting) { DebugLog(@"[警告] 任务已在进行中!"); return; }
    g_isExtracting = YES; g_workQueue = [NSMutableArray array]; g_titleQueue = [NSMutableArray array]; g_capturedDetails = [NSMutableArray array]; g_stepCounter = 0; g_debugLogView.text = @"";
    DebugLog(@"--- 开始新一轮提取任务 (真实点击模式) ---");
    // 三传
    Class sc = NSClassFromString(@"六壬大占.三傳視圖");
    if (sc) {
        NSMutableArray *v = [NSMutableArray array]; FindSubviewsOfClassRecursive(sc, self.view, v);
        if (v.count > 0) {
            UIView *c = v.firstObject; const char *ivars[] = {"初傳", "中傳", "末傳"}; NSString *titles[] = {@"初传", @"中传", @"末传"};
            for (int i=0; i<3; ++i) {
                UIView *cv = object_getIvar(c, class_getInstanceVariable(sc, ivars[i]));
                if(cv){
                    NSMutableArray *l=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class],cv,l);
                    [l sortUsingComparator:^NSComparisonResult(UILabel*o1,UILabel*o2){return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];}];
                    if(l.count>=2){
                        UILabel*d=l[l.count-2],*t=l[l.count-1];
                        [g_workQueue addObject:d];[g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)",titles[i],d.text]];
                        [g_workQueue addObject:t];[g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)",titles[i],t.text]];
                    }
                }
            }
        }
    }
    // 四课
    Class sk = NSClassFromString(@"六壬大占.四課視圖");
    if (sk) {
        NSMutableArray *v = [NSMutableArray array]; FindSubviewsOfClassRecursive(sk, self.view, v);
        if (v.count > 0) {
            UIView *c = v.firstObject; const char *ivars[] = {"第一課", "第二課", "第三課", "第四課"}; NSString *titles[] = {@"第一课",@"第二课",@"第三课",@"第四课"};
            for (int i=0; i<4; ++i) {
                UIView *kv = object_getIvar(c, class_getInstanceVariable(sk, ivars[i]));
                if(kv){
                    NSMutableArray *l=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class],kv,l);
                    [l sortUsingComparator:^NSComparisonResult(UILabel*o1,UILabel*o2){return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];}];
                    if(l.count>=2){
                        UILabel *t=l.firstObject,*d=l.lastObject;
                        [g_workQueue addObject:d];[g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)",titles[i],d.text]];
                        [g_workQueue addObject:t];[g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)",titles[i],t.text]];
                    }
                }
            }
        }
    }
    DebugLog(@"[队列构建] 队列构建完成，共 %ld 项。", (long)g_workQueue.count);
    if (g_workQueue.count == 0) { DebugLog(@"[错误] 未找到任何可提取项。"); g_isExtracting = NO; return; }
    [self processNextInQueue];
}

%new
// --- 核心解决方案：模拟真实触摸事件 ---
- (void)simulateTapOnView:(UIView *)view {
    if (!view || !view.window) {
        DebugLog(@"[错误] 目标视图无效或不在窗口中，无法模拟点击。");
        return;
    }
    DebugLog(@"[模拟点击] 正在对 %@ (%@) 执行真实触摸事件...", view.class, [view respondsToSelector:@selector(text)] ? [(UILabel *)view text] : @"");
    
    // 1. 获取视图在窗口中的中心点
    CGPoint centerPoint = [view.superview convertPoint:view.center toView:nil];

    // 2. 创建触摸事件
    UIEvent *event = [[UIEvent alloc] init];
    UITouch *touch = [[UITouch alloc] initWithPoint:centerPoint inWindow:view.window];
    
    // 3. 关联触摸和事件 (这是私有API，需要动态调用来避免编译警告)
    [touch setValue:@(UITouchPhaseBegan) forKey:@"phase"];
    [touch setValue:view.window forKey:@"window"];
    SEL setEventSEL = NSSelectorFromString([NSString stringWithFormat:@"%@%@%@", @"_set", @"IOHID", @"Event:"]);
    if ([touch respondsToSelector:setEventSEL]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [touch performSelector:setEventSEL withObject:event];
        #pragma clang diagnostic pop
    }
    
    // 4. 发送事件
    [view.window sendEvent:event];

    // 5. 模拟手指抬起
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [touch setValue:@(UITouchPhaseEnded) forKey:@"phase"];
        [view.window sendEvent:event];
        DebugLog(@"[模拟点击] 触摸事件发送完毕。");
    });
}

%new
// --- 队列处理器 (已更新为使用真实点击) ---
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
    
    UIView *itemToClick = g_workQueue.firstObject;
    [g_workQueue removeObjectAtIndex:0];
    
    NSString *title = g_titleQueue[g_capturedDetails.count];
    DebugLog(@"[处理队列] 准备点击: '%@'", title);

    // 【【【最终修正】】】
    // 不再使用 performSelector，而是调用我们新的模拟真实点击方法
    [self simulateTapOnView:itemToClick];
}

%end
