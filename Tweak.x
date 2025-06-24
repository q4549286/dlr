#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局状态
// =========================================================================
static BOOL g_isExtracting = NO;
static NSMutableArray *g_workQueue = nil;       // 新：存储UIGestureRecognizer对象
static NSMutableArray *g_titleQueue = nil;
static NSMutableArray *g_capturedDetails = nil;

// 辅助函数
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能实现
// =========================================================================
@interface UIViewController (GestureSolutionAddons)
- (void)startGestureExtractionProcess;
- (void)processNextGestureInQueue;
@end

%hook UIViewController

// --- viewDidLoad: 注入按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = self.view.window; if (!window) return;
            NSInteger buttonTag = 112233;
            [[window viewWithTag:buttonTag] removeFromSuperview];
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(window.bounds.size.width - 180, 50, 170, 40);
            button.tag = buttonTag;
            [button setTitle:@"提取课传(手势终极版)" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:15];
            button.backgroundColor = [UIColor purpleColor];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.layer.cornerRadius = 8;
            [button addTarget:self action:@selector(startGestureExtractionProcess) forControlEvents:UIControlEventTouchUpInside];
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
                        [self processNextGestureInQueue];
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
// --- startGestureExtractionProcess: 流程起点，构建手势队列 ---
- (void)startGestureExtractionProcess {
    if (g_isExtracting) { return; }
    g_isExtracting = YES;
    g_workQueue = [NSMutableArray array];
    g_titleQueue = [NSMutableArray array];
    g_capturedDetails = [NSMutableArray array];

    // --- 新的构建逻辑：查找手势识别器 ---
    Class gestureTargetClass = NSClassFromString(@"_TtCC12六壬大占14ViewController18課傳觸摸手勢");
    if (!gestureTargetClass) {
        NSLog(@"[Tweak Error] 无法找到关键的手势类 _TtCC12六壬大占14ViewController18課傳觸摸手勢");
        g_isExtracting = NO;
        return;
    }

    // 三传
    Class sanChuanClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanClass) {
        NSMutableArray *views = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanClass, self.view, views);
        if (views.count > 0) {
            UIView *container = views.firstObject;
            const char *ivars[] = {"初傳", "中傳", "末傳"}; NSString *titles[] = {@"初传", @"中传", @"末传"};
            for (int i=0; i<3; ++i) {
                UIView *chuanView = object_getIvar(container, class_getInstanceVariable(sanChuanClass, ivars[i]));
                if(chuanView){
                    // 在这个傳視圖上找到对应的地支和天将手势
                    UIGestureRecognizer *dizhiGesture = nil;
                    UIGestureRecognizer *tianjiangGesture = nil;
                    
                    for (UIGestureRecognizer *gesture in chuanView.gestureRecognizers) {
                        if ([gesture isKindOfClass:gestureTargetClass]) {
                            // 通过手势关联的方法名来区分是地支还是天将
                            // 这是个巧妙的技巧，因为手势通常会绑定到不同的action
                            // 我们需要用逆向工具（如Flex, Cycript）确认action名，但可以先猜测一下
                            NSString *actionString = NSStringFromSelector(NSSelectorFromString([NSString stringWithFormat:@"%@",[gesture valueForKey:@"action"]]));

                            if ([actionString containsString:@"天將"]) {
                                tianjiangGesture = gesture;
                            } else {
                                dizhiGesture = gesture;
                            }
                        }
                    }

                    if (dizhiGesture && tianjiangGesture) {
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

    // 四课 (同理，查找手势)
    // ... 四课逻辑 ...

    if (g_workQueue.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:@"未能找到任何课传的手势识别器，无法提取。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        g_isExtracting = NO;
        return;
    }
    
    [self processNextGestureInQueue];
}

%new
// --- processNextGestureInQueue: 队列处理器，使用手势作为sender ---
- (void)processNextGestureInQueue {
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

    // 取出队列头的手势对象
    UIGestureRecognizer *gestureToTrigger = g_workQueue.firstObject;
    [g_workQueue removeObjectAtIndex:0];
    
    NSString *title = g_titleQueue[g_capturedDetails.count];
    
    // 根据标题判断该调用哪个方法
    SEL actionToPerform = [title containsString:@"地支"] ? NSSelectorFromString(@"顯示課傳摘要WithSender:") : NSSelectorFromString(@"顯示課傳天將摘要WithSender:");

    if ([self respondsToSelector:actionToPerform]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        // 【【【最终核心修正】】】
        // 使用手势识别器本身作为参数(sender)来调用方法
        [self performSelector:actionToPerform withObject:gestureToTrigger];
        #pragma clang diagnostic pop
    } else {
        [self processNextGestureInQueue]; // 如果方法不对，跳过
    }
}
%end
