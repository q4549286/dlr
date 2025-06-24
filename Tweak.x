#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 全局状态与辅助函数
// =========================================================================
static BOOL g_isExtracting = NO;
static NSMutableArray *g_workQueue = nil;
static NSMutableArray *g_titleQueue = nil;
static NSMutableArray *g_capturedDetails = nil;

// 辅助函数：递归查找手势
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
@interface UIViewController (FinalAttackSolution)
- (void)startFinalExtractionProcess;
- (void)processNextFinalQueueItem;
@end

%hook UIViewController

// --- 注入最终的提取按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = self.view.window; if (!window) return;
            NSInteger buttonTag = 1000000;
            [[window viewWithTag:buttonTag] removeFromSuperview];
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(self.view.center.x - 90, 50, 180, 40);
            button.tag = buttonTag;
            [button setTitle:@"执行最终提取" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            button.backgroundColor = [UIColor orangeColor];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.layer.cornerRadius = 20;
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
                        [self processNextFinalQueueItem];
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
// --- 流程起点，集所有情报于一身的最终实现 ---
- (void)startFinalExtractionProcess {
    if (g_isExtracting) { return; }
    g_isExtracting = YES; g_workQueue = [NSMutableArray array]; g_titleQueue = [NSMutableArray array]; g_capturedDetails = [NSMutableArray array];

    // 获取手势类
    Class gestureTargetClass = NSClassFromString(@"_TtCC12六壬大占14ViewController18課傳觸摸手勢");
    if (!gestureTargetClass) { g_isExtracting = NO; return; }

    // 1. 从 VC 获取 `課傳` 对象 (課傳視圖)
    Ivar keChuanIvar = class_getInstanceVariable([self class], "課傳");
    if (!keChuanIvar) { g_isExtracting = NO; return; }
    UIView *keChuanView = object_getIvar(self, keChuanIvar);
    if (!keChuanView) { g_isExtracting = NO; return; }
    
    // 2. 从 `課傳視圖` 获取 `三傳` 对象 (三傳視圖)
    Ivar sanChuanIvar = class_getInstanceVariable([keChuanView class], "三傳");
    if (!sanChuanIvar) { g_isExtracting = NO; return; }
    UIView *sanChuanView = object_getIvar(keChuanView, sanChuanIvar);

    // --- 处理三传 ---
    if (sanChuanView) {
        const char *ivars[] = {"初傳", "中傳", "末傳"}; NSString *titles[] = {@"初传", @"中传", @"末传"};
        for (int i=0; i<3; ++i) {
            Ivar chuanIvar = class_getInstanceVariable([sanChuanView class], ivars[i]);
            if (!chuanIvar) continue;
            UIView *chuanView = object_getIvar(sanChuanView, chuanIvar); // 这是初/中/末传的独立视图
            if(chuanView){
                NSMutableArray *foundGestures = [NSMutableArray array];
                FindGesturesOfTypeRecursive(gestureTargetClass, chuanView, foundGestures);
                if (foundGestures.count >= 2) {
                    [foundGestures sortUsingComparator:^NSComparisonResult(UIGestureRecognizer *g1, UIGestureRecognizer *g2) {
                        return [@(g1.view.frame.origin.x) compare:@(g2.view.frame.origin.x)];
                    }];
                    UIGestureRecognizer *dizhiGesture = foundGestures[0];
                    UIGestureRecognizer *tianjiangGesture = foundGestures[1];
                    NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
                    [labels sortUsingComparator:^NSComparisonResult(UILabel*o1,UILabel*o2){return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];}];
                    if(labels.count >= 2){
                        UILabel *d_label = labels[labels.count-2], *t_label = labels[labels.count-1];
                        [g_workQueue addObject:dizhiGesture]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", titles[i], d_label.text]];
                        [g_workQueue addObject:tianjiangGesture]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", titles[i], t_label.text]];
                    }
                }
            }
        }
    }
    // ... 此处可按同样逻辑添加四课的处理 ...
    
    if (g_workQueue.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"失败" message:@"最终查找失败，未能找到任何手势。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        g_isExtracting = NO; return;
    }
    [self processNextFinalQueueItem];
}

%new
// --- 队列处理器 (无需修改) ---
- (void)processNextFinalQueueItem {
    if (g_workQueue.count == 0) {
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
        g_isExtracting = NO; return;
    }
    UIGestureRecognizer *gestureToTrigger = g_workQueue.firstObject; [g_workQueue removeObjectAtIndex:0];
    NSString *title = g_titleQueue[g_capturedDetails.count];
    SEL actionToPerform = [title containsString:@"地支"] ? NSSelectorFromString(@"顯示課傳摘要WithSender:") : NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    if ([self respondsToSelector:actionToPerform]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:gestureToTrigger];
        #pragma clang diagnostic pop
    } else {
        [self processNextFinalQueueItem];
    }
}
%end
