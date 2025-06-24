#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 全局状态与辅助函数
// =========================================================================
static BOOL g_isExtracting = NO;
static NSMutableArray *g_workQueue = nil;
static NSMutableArray *g_titleQueue = nil;
static NSMutableArray *g_capturedDetails = nil;

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

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 主功能实现
// =========================================================================
@interface UIViewController (UltimateSolution)
- (void)startUltimateExtractionProcess;
- (void)processNextUltimateQueueItem;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = self.view.window; if (!window) return;
            NSInteger buttonTag = 20240520; // A unique tag for victory day
            [[window viewWithTag:buttonTag] removeFromSuperview];
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(self.view.center.x - 100, 50, 200, 44);
            button.tag = buttonTag;
            [button setTitle:@"提取课传 (决战版)" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:17];
            button.backgroundColor = [UIColor systemGreenColor];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.layer.cornerRadius = 22;
            button.layer.shadowColor = [UIColor blackColor].CGColor;
            button.layer.shadowOffset = CGSizeMake(0, 2);
            button.layer.shadowRadius = 4;
            button.layer.shadowOpacity = 0.5;
            [button addTarget:self action:@selector(startUltimateExtractionProcess) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:button];
        });
    }
}

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
                    return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];
                }];
                NSMutableArray<NSString *> *texts = [NSMutableArray array];
                for (UILabel *label in labels) { if (label.text.length > 0) [texts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; }
                [g_capturedDetails addObject:[texts componentsJoinedByString:@"\n"]];
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processNextUltimateQueueItem];
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
- (void)startUltimateExtractionProcess {
    if (g_isExtracting) { return; }
    g_isExtracting = YES; g_workQueue = [NSMutableArray array]; g_titleQueue = [NSMutableArray array]; g_capturedDetails = [NSMutableArray array];

    // 1. 全局扫描所有目标手势
    Class gestureClass = NSClassFromString(@"_TtCC12六壬大占14ViewController18課傳觸摸手勢");
    if (!gestureClass) { g_isExtracting = NO; return; }
    NSMutableArray *allGesturesOnScreen = [NSMutableArray array];
    FindGesturesOfTypeRecursive(gestureClass, self.view, allGesturesOnScreen);

    if (allGesturesOnScreen.count < 6) { // 至少要有三传的6个手势
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:[NSString stringWithFormat:@"全局扫描到的手势不足 (%lu个)", (unsigned long)allGesturesOnScreen.count] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        g_isExtracting = NO; return;
    }
    
    // 2. 精确定位三传的各个“地标”视图
    Ivar keChuanIvar = class_getInstanceVariable([self class], "課傳");
    UIView *keChuanView = keChuanIvar ? object_getIvar(self, keChuanIvar) : nil;
    Ivar sanChuanIvar = keChuanView ? class_getInstanceVariable([keChuanView class], "三傳") : nil;
    UIView *sanChuanView = sanChuanIvar ? object_getIvar(keChuanView, sanChuanIvar) : nil;
    Class chuanShiTuClass = NSClassFromString(@"六壬大占.傳視圖");

    if (sanChuanView && chuanShiTuClass) {
        NSMutableArray *chuanViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(chuanShiTuClass, sanChuanView, chuanViews);
        // 按Y坐标排序，确保顺序是 初传 -> 中传 -> 末传
        [chuanViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
            return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)];
        }];
        
        NSString *titles[] = {@"初传", @"中传", @"末传"};
        for (int i=0; i < chuanViews.count && i < 3; ++i) {
            UIView *chuanView = chuanViews[i];
            CGRect regionRect = [chuanView.superview convertRect:chuanView.frame toView:nil];
            NSMutableArray *gesturesInRegion = [NSMutableArray array];

            // 3. 空间匹配：将全局手势与地标区域进行配对
            for (UIGestureRecognizer *gesture in allGesturesOnScreen) {
                UIView *tappedView = gesture.view;
                // 使用中心点进行判断，更准确
                CGPoint centerInWindow = [tappedView.superview convertPoint:tappedView.center toView:nil];
                if (CGRectContainsPoint(regionRect, centerInWindow)) {
                    [gesturesInRegion addObject:gesture];
                }
            }

            if (gesturesInRegion.count >= 2) {
                // 按X坐标排序，确保顺序是 地支 -> 天将
                [gesturesInRegion sortUsingComparator:^NSComparisonResult(UIGestureRecognizer *g1, UIGestureRecognizer *g2) {
                    return [@(g1.view.frame.origin.x) compare:@(g2.view.frame.origin.x)];
                }];
                UIGestureRecognizer *dizhiGesture = gesturesInRegion[0];
                UIGestureRecognizer *tianjiangGesture = gesturesInRegion[1];
                
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
    
    if (g_workQueue.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"失败" message:@"最终配对失败，未能将手势与课传区域关联。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        g_isExtracting = NO; return;
    }
    [self processNextUltimateQueueItem];
}

%new
- (void)processNextUltimateQueueItem {
    if (g_workQueue.count == 0) {
        NSMutableString *result = [NSMutableString string];
        for (NSUInteger i = 0; i < g_titleQueue.count; i++) {
            NSString *title = g_titleQueue[i];
            NSString *detail = (i < g_capturedDetails.count) ? g_capturedDetails[i] : @"[提取失败]";
            [result appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = result;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取完成！" message:@"所有详情已成功复制到剪贴板！" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"完美收官！" style:UIAlertActionStyleDefault handler:nil]];
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
        [self processNextUltimateQueueItem];
    }
}
%end
