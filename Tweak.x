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

// =========================================================================
// 2. 主功能实现
// =========================================================================
@interface UIViewController (TheFinalAnswer)
- (void)startSpatialExtraction;
- (void)processNextSpatialQueueItem;
@end

%hook UIViewController

// --- 注入最终的提取按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = self.view.window; if (!window) return;
            NSInteger buttonTag = 20240523;
            [[window viewWithTag:buttonTag] removeFromSuperview];
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(self.view.center.x - 90, 50, 180, 40);
            button.tag = buttonTag;
            [button setTitle:@"提取课传(最终版)" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            button.backgroundColor = [UIColor systemGreenColor];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.layer.cornerRadius = 20;
            [button addTarget:self action:@selector(startSpatialExtraction) forControlEvents:UIControlEventTouchUpInside];
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
                NSMutableArray *labels = [NSMutableArray array]; // ... find labels ...
                Class labelClass = [UILabel class];
                if ([contentView isKindOfClass:labelClass]) { [labels addObject:contentView]; }
                for (UIView *subview in contentView.subviews) { if ([subview isKindOfClass:labelClass]) { [labels addObject:subview]; } }
                [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { /*...*/ return NSOrderedSame; }];
                NSMutableArray<NSString *> *texts = [NSMutableArray array];
                for (UILabel *label in labels) { if (label.text.length > 0) [texts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; }
                // 简化版提取，因为弹窗视图结构未知，直接取所有文本
                NSMutableString *allText = [NSMutableString string];
                for(UIView* v in contentView.subviews) if([v isKindOfClass:[UILabel class]]) [allText appendFormat:@"%@ ", ((UILabel*)v).text];
                [g_capturedDetails addObject:allText];
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processNextSpatialQueueItem];
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
// --- 流程起点：基于最终诊断报告的完美空间关联 ---
- (void)startSpatialExtraction {
    if (g_isExtracting) { return; }
    g_isExtracting = YES; g_workQueue = [NSMutableArray array]; g_titleQueue = [NSMutableArray array]; g_capturedDetails = [NSMutableArray array];

    // --- 1. 获取所有地标区域和标题 ---
    NSMutableArray<NSValue *> *landmarkRegions = [NSMutableArray array];
    NSMutableArray<NSString *> *landmarkTitles = [NSMutableArray array];
    Ivar keChuanIvar = class_getInstanceVariable([self class], "課傳");
    UIView *keChuanView = keChuanIvar ? object_getIvar(self, keChuanIvar) : nil;
    Ivar sanChuanIvar = keChuanView ? class_getInstanceVariable([keChuanView class], "三傳") : nil;
    UIView *sanChuanView = sanChuanIvar ? object_getIvar(keChuanView, sanChuanIvar) : nil;

    if (sanChuanView) {
        const char *ivars[] = {"初傳", "中傳", "末傳"};
        NSString *titles[] = {@"初传", @"中传", @"末传"};
        for (int i=0; i<3; ++i) {
            Ivar chuanIvar = class_getInstanceVariable([sanChuanView class], ivars[i]);
            UIView *chuanView = chuanIvar ? object_getIvar(sanChuanView, chuanIvar) : nil;
            if (chuanView) {
                CGRect frameInWindow = [chuanView.superview convertRect:chuanView.frame toView:nil];
                [landmarkRegions addObject:[NSValue valueWithCGRect:frameInWindow]];
                [landmarkTitles addObject:titles[i]];
            }
        }
    }

    // --- 2. 获取所有手势 ---
    Class gestureClass = NSClassFromString(@"_TtCC12六壬大占14ViewController18課傳觸摸手勢");
    NSMutableArray *allGestures = [NSMutableArray array];
    if(gestureClass) FindGesturesOfTypeRecursive(gestureClass, self.view, allGestures);

    // --- 3. 将手势按地标区域分组 ---
    NSMutableArray<NSMutableArray *> *groupedGestures = [NSMutableArray array];
    for (int i=0; i<landmarkRegions.count; ++i) [groupedGestures addObject:[NSMutableArray array]];

    for (UIGestureRecognizer *gesture in allGestures) {
        UIView *gestureView = gesture.view;
        CGPoint centerInWindow = [gestureView.superview convertPoint:gestureView.center toView:nil];
        for (int i=0; i<landmarkRegions.count; ++i) {
            if (CGRectContainsPoint(landmarkRegions[i].CGRectValue, centerInWindow)) {
                [groupedGestures[i] addObject:gesture];
                break;
            }
        }
    }

    // --- 4. 从分组中构建工作队列 ---
    for (int i=0; i<groupedGestures.count; ++i) {
        NSMutableArray *group = groupedGestures[i];
        if (group.count >= 2) {
            // 根据X坐标排序，左边是地支，右边是天将
            [group sortUsingComparator:^NSComparisonResult(UIGestureRecognizer *g1, UIGestureRecognizer *g2) {
                return [@(g1.view.frame.origin.x) compare:@(g2.view.frame.origin.x)];
            }];
            UIGestureRecognizer *dizhiGesture = group[0];
            UIGestureRecognizer *tianjiangGesture = group[1];
            UILabel *d_label = (UILabel *)dizhiGesture.view;
            UILabel *t_label = (UILabel *)tianjiangGesture.view;
            NSString *baseTitle = landmarkTitles[i];

            [g_workQueue addObject:dizhiGesture]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", baseTitle, d_label.text]];
            [g_workQueue addObject:tianjiangGesture]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", baseTitle, t_label.text]];
        }
    }
    
    // ... 四课逻辑可按此模板添加 ...
    
    if (g_workQueue.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"失败" message:@"空间关联失败。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好吧" style:UIAlertActionStyleDefault handler:nil]];
        g_isExtracting = NO; return;
    }
    [self processNextSpatialQueueItem];
}

%new
// --- 队列处理器 (简化版) ---
- (void)processNextSpatialQueueItem {
    if (g_workQueue.count == 0) {
        NSMutableString *result = [NSMutableString string];
        for (NSUInteger i = 0; i < g_titleQueue.count; i++) {
            [result appendFormat:@"--- %@ ---\n%@\n\n", g_titleQueue[i], g_capturedDetails[i]];
        }
        [UIPasteboard generalPasteboard].string = result;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取完成！" message:@"所有详情已复制到剪贴板！" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"太棒了！" style:UIAlertActionStyleDefault handler:nil]];
        g_isExtracting = NO; return;
    }
    UIGestureRecognizer *gestureToTrigger = g_workQueue.firstObject; [g_workQueue removeObjectAtIndex:0];
    SEL actionToPerform = [g_titleQueue[g_capturedDetails.count] containsString:@"地支"] ? NSSelectorFromString(@"顯示課傳摘要WithSender:") : NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    if ([self respondsToSelector:actionToPerform]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:gestureToTrigger];
        #pragma clang diagnostic pop
    } else {
        [self processNextSpatialQueueItem];
    }
}
%end
