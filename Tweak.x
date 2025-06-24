#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 全局状态
// =========================================================================
static BOOL g_isExtracting = NO;
static NSMutableArray *g_workQueue = nil;
static NSMutableArray *g_titleQueue = nil;
static NSMutableString *g_finalResultString = nil;

// =========================================================================
// 2. 主功能实现
// =========================================================================
@interface UIViewController (TheFinalVictory)
- (void)startTheFinalExtraction;
- (void)processTheNextQueueItem;
@end

%hook UIViewController

// --- 注入最终按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = self.view.window; if (!window) return;
            NSInteger buttonTag = 2024;
            [[window viewWithTag:buttonTag] removeFromSuperview];
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(self.view.center.x - 110, 50, 220, 44);
            button.tag = buttonTag;
            [button setTitle:@"提取课传(胜利版)" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:18];
            button.backgroundColor = [UIColor orangeColor];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.layer.cornerRadius = 22;
            [button addTarget:self action:@selector(startTheFinalExtraction) forControlEvents:UIControlEventTouchUpInside];
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
                
                NSString *currentTitle = (g_titleQueue.count > 0) ? g_titleQueue.firstObject : @"[未知标题]";
                if (g_titleQueue.count > 0) { [g_titleQueue removeObjectAtIndex:0]; }

                NSMutableString *allText = [NSMutableString string];
                for(UIView* v in viewControllerToPresent.view.subviews) {
                    if([v isKindOfClass:[UILabel class]]) {
                        NSString *text = ((UILabel*)v).text;
                        if (text) [allText appendFormat:@"%@ ", [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                NSString* capturedDetail = allText.length > 0 ? [allText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] : @"[无文本信息]";
                
                [g_finalResultString appendFormat:@"--- %@ ---\n%@\n\n", currentTitle, capturedDetail];

                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processTheNextQueueItem];
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
- (void)startTheFinalExtraction {
    if (g_isExtracting) { return; }
    g_isExtracting = YES; g_workQueue = [NSMutableArray array]; g_titleQueue = [NSMutableArray array]; g_finalResultString = [NSMutableString string];

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
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-retain-cycles"
    __block void (^findLabels)(UIView*);
    findLabels = ^(UIView *v) {
        if([v isKindOfClass:[UILabel class]]) { [allLabels addObject:(UILabel*)v]; }
        for(UIView *sv in v.subviews) { findLabels(sv); }
    };
    #pragma clang diagnostic pop
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

    if (g_workQueue.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"启动失败" message:@"未能找到任何可提取的标签。请确保课盘已显示。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        g_isExtracting = NO; return;
    }
    [self processTheNextQueueItem];
}

%new
// --- 队列处理器：最终的、纯粹的派发 ---
- (void)processTheNextQueueItem {
    if (g_workQueue.count == 0) {
        [UIPasteboard generalPasteboard].string = g_finalResultString;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取完成！" message:[NSString stringWithFormat:@"所有 %lu 项详情已复制到剪贴板！", (unsigned long)g_finalResultString.length] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"胜利！" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
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
                    
                    // 【【【最终的、纯粹的逻辑】】】
                    // 1. 不触碰'位'属性，保留其原始值。
                    // 2. 只设置'state'属性。
                    [realGesture setValue:@(UIGestureRecognizerStateEnded) forKey:@"state"];
                    
                    // 3. 派发！
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [realTarget performSelector:realAction withObject:realGesture];
                    #pragma clang diagnostic pop
                    
                    // 4. 恢复手势状态。
                    [realGesture setValue:@(UIGestureRecognizerStatePossible) forKey:@"state"];
                    return; // 等待拦截器驱动下一次循环
                }
            }
        }
    }
    
    // 如果上面的任何一步失败，或者找不到手势，记录错误并继续
    NSString *currentTitle = (g_titleQueue.count > 0) ? g_titleQueue.firstObject : @"[未知标题]";
    if (g_titleQueue.count > 0) { [g_titleQueue removeObjectAtIndex:0]; }
    [g_finalResultString appendFormat:@"--- %@ ---\n[提取失败：未能触发手势]\n\n", currentTitle];
    [self processTheNextQueueItem]; // 保持链条不断
}

%end
