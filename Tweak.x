#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局状态与辅助函数
// =========================================================================
static BOOL g_isExtracting = NO;
static NSMutableArray *g_workQueue = nil;
static NSMutableArray *g_titleQueue = nil;
static NSMutableArray *g_capturedDetails = nil;

// -- 新的辅助函数：递归查找一个视图及其所有子视图上的手势 --
static void FindGesturesOfTypeRecursive(Class gestureClass, UIView *view, NSMutableArray *storage) {
    for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
        if ([gesture isKindOfClass:gestureClass]) {
            [storage addObject:gesture];
        }
    }
    for (UIView *subview in view.subviews) {
        FindGesturesOfTypeRecursive(gestureClass, subview, storage);
    }
}

// 辅助函数：查找UILabel
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能实现
// =========================================================================
@interface UIViewController (FinalGestureSolutionAddons)
- (void)startFinalExtractionProcess;
- (void)processNextInFinalQueue;
@end

%hook UIViewController

// --- viewDidLoad: 注入按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = self.view.window; if (!window) return;
            NSInteger buttonTag = 112244; // 新Tag
            [[window viewWithTag:buttonTag] removeFromSuperview];
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(window.bounds.size.width - 200, 50, 190, 40);
            button.tag = buttonTag;
            [button setTitle:@"提取课传(终极递归手势版)" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:15];
            button.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0]; // 深红色
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.layer.cornerRadius = 8;
            [button addTarget:self action:@selector(startFinalExtractionProcess) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:button];
        });
    }
}

// --- presentViewController: 核心拦截逻辑 (无需修改) ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtracting) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            viewControllerToPresent.view.alpha = 0.0f; flag = NO;
            void (^extractionCompletion)(void) = ^{
                if (completion) { completion(); }
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, labels);
                [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    CGFloat y1=roundf(o1.frame.origin.y), y2=roundf(o2.frame.origin.y);
                    if(y1<y2)return NSOrderedAscending; if(y1>y2)return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                NSMutableArray<NSString *> *texts = [NSMutableArray array];
                for (UILabel *label in labels) { if (label.text.length > 0) [texts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; }
                [g_capturedDetails addObject:[texts componentsJoinedByString:@"\n"]];
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processNextInFinalQueue];
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
// --- startFinalExtractionProcess: 流程起点，递归构建手势队列 ---
- (void)startFinalExtractionProcess {
    if (g_isExtracting) { return; }
    g_isExtracting = YES;
    g_workQueue = [NSMutableArray array];
    g_titleQueue = [NSMutableArray array];
    g_capturedDetails = [NSMutableArray array];

    Class gestureTargetClass = NSClassFromString(@"_TtCC12六壬大占14ViewController18課傳觸摸手勢");
    if (!gestureTargetClass) {
        // ... 错误处理 ...
        g_isExtracting = NO; return;
    }

    // --- 三传 ---
    Class sanChuanClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanClass) {
        NSMutableArray *views = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanClass, self.view, views);
        if (views.count > 0) {
            UIView *container = views.firstObject;
            const char *ivars[] = {"初傳", "中傳", "末傳"}; NSString *titles[] = {@"初传", @"中传", @"末传"};
            for (int i=0; i<3; ++i) {
                UIView *chuanView = object_getIvar(container, class_getInstanceVariable(sanChuanClass, ivars[i]));
                if(chuanView){
                    NSMutableArray *foundGestures = [NSMutableArray array];
                    // 【【【核心修正】】】 使用新的递归函数来查找手势
                    FindGesturesOfTypeRecursive(gestureTargetClass, chuanView, foundGestures);

                    if (foundGestures.count >= 2) {
                        // 根据手势所附加的视图的x坐标来排序（三传是左右结构）
                        [foundGestures sortUsingComparator:^NSComparisonResult(UIGestureRecognizer *g1, UIGestureRecognizer *g2) {
                            return [@(g1.view.frame.origin.x) compare:@(g2.view.frame.origin.x)];
                        }];
                        UIGestureRecognizer *dizhiGesture = foundGestures[0];
                        UIGestureRecognizer *tianjiangGesture = foundGestures[1];

                        NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
                        [labels sortUsingComparator:^NSComparisonResult(UILabel*o1,UILabel*o2){return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];}];
                        if(labels.count >= 2){
                            UILabel *d_label = labels[labels.count-2];
                            UILabel *t_label = labels[labels.count-1];
                            [g_workQueue addObject:dizhiGesture]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", titles[i], d_label.text]];
                            [g_workQueue addObject:tianjiangGesture]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", titles[i], t_label.text]];
                        }
                    }
                }
            }
        }
    }

    // --- 四课 ---
    Class siKeClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeClass) {
        NSMutableArray *views = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeClass, self.view, views);
        if (views.count > 0) {
            UIView *container = views.firstObject;
            const char *ivars[] = {"第一課", "第二課", "第三課", "第四課"}; NSString *titles[] = {@"第一课",@"第二课",@"第三课",@"第四课"};
            for (int i=0; i<4; ++i) {
                UIView *keView = object_getIvar(container, class_getInstanceVariable(siKeClass, ivars[i]));
                if (keView) {
                    NSMutableArray *foundGestures = [NSMutableArray array];
                    FindGesturesOfTypeRecursive(gestureTargetClass, keView, foundGestures);
                    if (foundGestures.count >= 2) {
                        // 根据手势所附加的视图的y坐标来排序（四课是上下结构）
                         [foundGestures sortUsingComparator:^NSComparisonResult(UIGestureRecognizer *g1, UIGestureRecognizer *g2) {
                            return [@(g1.view.frame.origin.y) compare:@(g2.view.frame.origin.y)];
                        }];
                        UIGestureRecognizer *tianjiangGesture = foundGestures[0];
                        UIGestureRecognizer *dizhiGesture = foundGestures[1];

                        NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], keView, labels);
                        [labels sortUsingComparator:^NSComparisonResult(UILabel*o1,UILabel*o2){return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];}];
                         if(labels.count >= 2){
                            UILabel *t_label = labels.firstObject;
                            UILabel *d_label = labels.lastObject;
                            [g_workQueue addObject:dizhiGesture]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", titles[i], d_label.text]];
                            [g_workQueue addObject:tianjiangGesture]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", titles[i], t_label.text]];
                        }
                    }
                }
            }
        }
    }

    if (g_workQueue.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:@"递归查找后，仍未找到任何手势识别器。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        g_isExtracting = NO; return;
    }
    
    [self processNextInFinalQueue];
}

%new
// --- processNextInFinalQueue: 队列处理器 (无需修改) ---
- (void)processNextInFinalQueue {
    if (g_workQueue.count == 0) {
        // 结束流程
        NSMutableString *result = [NSMutableString string];
        for (NSUInteger i = 0; i < g_titleQueue.count; i++) {
            NSString *title = g_titleQueue[i];
            NSString *detail = (i < g_capturedDetails.count) ? g_capturedDetails[i] : @"[提取失败]";
            [result appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = result;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"所有详情已复制到剪贴板！" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"完美！" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        g_isExtracting = NO;
        return;
    }

    UIGestureRecognizer *gestureToTrigger = g_workQueue.firstObject;
    [g_workQueue removeObjectAtIndex:0];
    
    NSString *title = g_titleQueue[g_capturedDetails.count];
    
    SEL actionToPerform = [title containsString:@"地支"] ? NSSelectorFromString(@"顯示課傳摘要WithSender:") : NSSelectorFromString(@"顯示課傳天將摘要WithSender:");

    if ([self respondsToSelector:actionToPerform]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:gestureToTrigger];
        #pragma clang diagnostic pop
    } else {
        [self processNextInFinalQueue];
    }
}
%end
