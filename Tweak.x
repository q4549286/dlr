#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 全局状态
// =========================================================================
static BOOL g_isExtracting = NO;
static NSMutableArray *g_workQueue = nil;
static NSMutableArray *g_titleQueue = nil;
static NSMutableArray *g_capturedDetails = nil;

// =========================================================================
// 2. 主功能实现
// =========================================================================
@interface UIViewController (TheActualFinalBypass)
- (void)startFinalBypassExtraction;
- (void)processNextFinalBypassQueueItem;
@end

// 【【【语法修正】】】
// 将所有对 UIViewController 的 hook 都放在这一个块中
%hook UIViewController

// --- 注入最终按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = self.view.window; if (!window) return;
            NSInteger buttonTag = 1;
            [[window viewWithTag:buttonTag] removeFromSuperview];
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(self.view.center.x - 110, 50, 220, 44);
            button.tag = buttonTag;
            [button setTitle:@"提取课传(最终版)" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:18];
            button.backgroundColor = [UIColor redColor];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.layer.cornerRadius = 22;
            [button addTarget:self action:@selector(startFinalBypassExtraction) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:button];
        });
    }
}

// --- 拦截器，用于捕获数据并驱动队列 ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtracting) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            viewControllerToPresent.view.alpha = 0.0f; flag = NO;
            void (^extractionCompletion)(void) = ^{
                if (completion) { completion(); }
                
                // 捕获数据
                NSMutableString *allText = [NSMutableString string];
                for(UIView* v in viewControllerToPresent.view.subviews) {
                    if([v isKindOfClass:[UILabel class]]) {
                        NSString *text = ((UILabel*)v).text;
                        if (text) [allText appendFormat:@"%@ ", [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                NSString* capturedDetail = allText.length > 0 ? [allText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] : @"[无文本信息]";
                NSString* title = (g_titleQueue.count > 0) ? g_titleQueue.firstObject : @"[未知标题]";
                [g_capturedDetails addObject:capturedDetail];
                [g_titleQueue removeObjectAtIndex:0]; // 移除已处理的标题

                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processNextFinalBypassQueueItem];
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
// --- 流程起点：空间关联 ---
- (void)startFinalBypassExtraction {
    if (g_isExtracting) { return; }
    g_isExtracting = YES; g_workQueue = [NSMutableArray array]; g_titleQueue = [NSMutableArray array]; g_capturedDetails = [NSMutableArray array];

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
                [landmarkRegions addObject:[NSValue valueWithCGRect:[chuanView.superview convertRect:chuanView.frame toView:nil]]];
                [landmarkTitles addObject:titles[i]];
            }
        }
    }

    NSMutableArray<UILabel *> *allLabels = [NSMutableArray array];
    void (^findLabels)(UIView*) = ^(UIView *v) {
        if([v isKindOfClass:[UILabel class]]) [allLabels addObject:(UILabel*)v];
        for(UIView *sv in v.subviews) findLabels(sv);
    };
    findLabels(self.view);

    NSMutableArray<NSMutableArray *> *groupedLabels = [NSMutableArray array];
    for (int i=0; i<landmarkRegions.count; ++i) [groupedLabels addObject:[NSMutableArray array]];
    for (UILabel *label in allLabels) {
        CGPoint centerInWindow = [label.superview convertPoint:label.center toView:nil];
        for (int i=0; i<landmarkRegions.count; ++i) {
            if (CGRectContainsPoint(landmarkRegions[i].CGRectValue, centerInWindow)) {
                 [groupedLabels[i] addObject:label]; break;
            }
        }
    }
    
    for (int i=0; i<groupedLabels.count; ++i) {
        NSMutableArray *group = groupedLabels[i];
        if (group.count >= 4) {
            [group sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
                 return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)];
            }];
            UILabel *dizhiLabel = group[2];
            UILabel *tianjiangLabel = group[3];
            [g_workQueue addObject:dizhiLabel]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", landmarkTitles[i], dizhiLabel.text]];
            [g_workQueue addObject:tianjiangLabel]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", landmarkTitles[i], tianjiangLabel.text]];
        }
    }

    if (g_workQueue.count == 0) { g_isExtracting = NO; return; }
    [self processNextFinalBypassQueueItem];
}

%new
// --- 队列处理器：强制修改状态并派发 ---
- (void)processNextFinalBypassQueueItem {
    if (g_workQueue.count == 0) {
        NSMutableString *result = [NSMutableString string];
        for (NSUInteger i = 0; i < g_capturedDetails.count; i++) {
             [result appendFormat:@"--- (提取 #%lu) ---\n%@\n\n", (unsigned long)i+1, g_capturedDetails[i]];
        }
        [UIPasteboard generalPasteboard].string = result;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"所有详情已复制到剪贴板！" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"完成！" style:UIAlertActionStyleDefault handler:nil]];
        g_isExtracting = NO; return;
    }

    UILabel *currentLabel = g_workQueue.firstObject; [g_workQueue removeObjectAtIndex:0];
    
    Class gestureClass = NSClassFromString(@"_TtCC12六壬大占14ViewController18課傳觸摸手勢");
    UIGestureRecognizer *realGesture = nil;
    for(UIGestureRecognizer *g in currentLabel.gestureRecognizers){
        if([g isKindOfClass:gestureClass]){ realGesture = g; break; }
    }

    if(realGesture){
        Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
        if(targetsIvar){
            NSArray *targets = object_getIvar(realGesture, targetsIvar);
            if(targets.count > 0){
                id targetActionPair = targets[0];
                id realTarget = [targetActionPair valueForKey:@"target"];
                SEL realAction = NSSelectorFromString([targetActionPair valueForKey:@"action"]);
                if(realTarget && realAction && [realTarget respondsToSelector:realAction]){
                    [realGesture setValue:@(UIGestureRecognizerStateEnded) forKey:@"state"];
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [realTarget performSelector:realAction withObject:realGesture];
                    #pragma clang diagnostic pop
                    [realGesture setValue:@(UIGestureRecognizerStatePossible) forKey:@"state"];
                    return;
                }
            }
        }
    }
    // 如果失败，直接跳到下一个
    [self processNextFinalBypassQueueItem];
}

%end // 【【【语法修正】】】 这里是唯一的 %end
