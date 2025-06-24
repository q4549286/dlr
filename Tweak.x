#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 全局状态
// =========================================================================
static BOOL g_isExtracting = NO;
static NSMutableArray *g_workQueue = nil;          // 存储要“点击”的UILabel
static NSMutableArray *g_originalGestures = nil;   // 存储原始手势，以获取target/action
static NSMutableArray *g_titleQueue = nil;         // 存储标题
static NSMutableArray *g_capturedDetails = nil;    // 存储捕获的数据

// =========================================================================
// 主功能实现
// =========================================================================
@interface UIViewController (TheMessengerSolution)
- (void)startMessengerExtraction;
- (void)processNextMessengerQueueItem;
@end

%hook UIViewController

// --- 注入最终按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = self.view.window; if (!window) return;
            NSInteger buttonTag = 200;
            [[window viewWithTag:buttonTag] removeFromSuperview];
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(self.view.center.x - 110, 50, 220, 44);
            button.tag = buttonTag;
            [button setTitle:@"提取课传(最终答案)" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:18];
            button.backgroundColor = [UIColor systemIndigoColor];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.layer.cornerRadius = 22;
            [button addTarget:self action:@selector(startMessengerExtraction) forControlEvents:UIControlEventTouchUpInside];
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
                NSMutableString *allText = [NSMutableString string];
                for(UIView* v in viewControllerToPresent.view.subviews) {
                    if([v isKindOfClass:[UILabel class]]) {
                        NSString *text = ((UILabel*)v).text;
                        if (text) [allText appendFormat:@"%@ ", [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                NSString* capturedDetail = allText.length > 0 ? [allText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] : @"[无文本信息]";
                [g_capturedDetails addObject:capturedDetail];
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processNextMessengerQueueItem];
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
// --- 流程起点：空间关联，构建队列 ---
- (void)startMessengerExtraction {
    if (g_isExtracting) { return; }
    g_isExtracting = YES; g_workQueue = [NSMutableArray array]; g_originalGestures = [NSMutableArray array];
    g_titleQueue = [NSMutableArray array]; g_capturedDetails = [NSMutableArray array];

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
    
    Class gestureClass = NSClassFromString(@"_TtCC12六壬大占14ViewController18課傳觸摸手勢");
    NSMutableArray<UIGestureRecognizer *> *allGestures = [NSMutableArray array];
    void (^findGestures)(UIView*) = ^(UIView *v) {
        for(UIGestureRecognizer *g in v.gestureRecognizers) if([g isKindOfClass:gestureClass]) [allGestures addObject:g];
        for(UIView *sv in v.subviews) findGestures(sv);
    };
    findGestures(self.view);

    NSMutableArray<NSMutableArray *> *groupedGestures = [NSMutableArray array];
    for (int i=0; i<landmarkRegions.count; ++i) [groupedGestures addObject:[NSMutableArray array]];
    for (UIGestureRecognizer *gesture in allGestures) {
        UIView *gestureView = gesture.view;
        CGPoint centerInWindow = [gestureView.superview convertPoint:gestureView.center toView:nil];
        for (int i=0; i<landmarkRegions.count; ++i) {
            if (CGRectContainsPoint(landmarkRegions[i].CGRectValue, centerInWindow)) {
                 [groupedGestures[i] addObject:gesture]; break;
            }
        }
    }
    
    for (int i=0; i<groupedGestures.count; ++i) {
        NSMutableArray *group = groupedGestures[i];
        if (group.count >= 2) {
            [group sortUsingComparator:^NSComparisonResult(UIGestureRecognizer *g1, UIGestureRecognizer *g2) {
                 return [@(g1.view.frame.origin.x) compare:@(g2.view.frame.origin.x)];
            }];
            UIGestureRecognizer *dizhiGesture = group[0];
            UIGestureRecognizer *tianjiangGesture = group[1];
            [g_workQueue addObject:dizhiGesture.view]; [g_originalGestures addObject:dizhiGesture]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", landmarkTitles[i], ((UILabel *)dizhiGesture.view).text]];
            [g_workQueue addObject:tianjiangGesture.view]; [g_originalGestures addObject:tianjiangGesture]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", landmarkTitles[i], ((UILabel *)tianjiangGesture.view).text]];
        }
    }

    if (g_workQueue.count == 0) { g_isExtracting = NO; return; }
    [self processNextMessengerQueueItem];
}

%new
// --- 队列处理器：信使派发！ ---
- (void)processNextMessengerQueueItem {
    if (g_workQueue.count == 0) {
        NSMutableString *result = [NSMutableString string];
        for (NSUInteger i = 0; i < g_titleQueue.count; i++) {
            [result appendFormat:@"--- %@ ---\n%@\n\n", g_titleQueue[i], g_capturedDetails[i]];
        }
        [UIPasteboard generalPasteboard].string = result;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"所有详情已复制到剪贴板！" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"成功！" style:UIAlertActionStyleDefault handler:nil]];
        g_isExtracting = NO; return;
    }

    UIView *targetView = g_workQueue.firstObject; [g_workQueue removeObjectAtIndex:0];
    UIGestureRecognizer *originalGesture = g_originalGestures.firstObject; [g_originalGestures removeObjectAtIndex:0];

    Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
    if(targetsIvar){
        NSArray *targets = object_getIvar(originalGesture, targetsIvar);
        if(targets.count > 0){
            id targetActionPair = targets[0];
            id realTarget = [targetActionPair valueForKey:@"target"];
            SEL realAction = NSSelectorFromString([targetActionPair valueForKey:@"action"]);
            if(realTarget && realAction && [realTarget respondsToSelector:realAction]){
                // ** 创建信使 **
                UIGestureRecognizer *messenger = [[[originalGesture class] alloc] init];
                // ** 赋予信使唯一需要的信息：它所代表的视图 **
                [messenger setValue:targetView forKey:@"view"];

                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [realTarget performSelector:realAction withObject:messenger];
                #pragma clang diagnostic pop
                return; // 等待presentViewController的拦截
            }
        }
    }
    // 如果失败，直接跳到下一个
    [self processNextMessengerQueueItem];
}

%end
