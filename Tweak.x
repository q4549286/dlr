#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 全局状态与辅助函数
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

// =========================================================================
// 2. 主功能实现
// =========================================================================
@interface UIViewController (StuntDoubleDispatch)
- (void)startStuntDoubleExtraction;
- (void)processNextStuntDoubleQueueItem;
@end

%hook UIViewController

// --- 注入最终按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = self.view.window; if (!window) return;
            NSInteger buttonTag = 1337; // The final tag
            [[window viewWithTag:buttonTag] removeFromSuperview];
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(self.view.center.x - 100, 50, 200, 40);
            button.tag = buttonTag;
            [button setTitle:@"提取课传(最终答案)" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            button.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.layer.cornerRadius = 20;
            [button addTarget:self action:@selector(startStuntDoubleExtraction) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:button];
        });
    }
}

// --- presentViewController: 核心拦截逻辑 ---
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
                [g_capturedDetails addObject:allText.length > 0 ? [allText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] : @"[无文本信息]"];
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processNextStuntDoubleQueueItem];
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
// --- 流程起点：空间关联 (已证明正确) ---
- (void)startStuntDoubleExtraction {
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
    
    Class gestureClass = NSClassFromString(@"_TtCC12六壬大占14ViewController18課傳觸摸手勢");
    NSMutableArray *allGestures = [NSMutableArray array];
    if(gestureClass) FindGesturesOfTypeRecursive(gestureClass, self.view, allGestures);

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
            [g_workQueue addObject:dizhiGesture]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", landmarkTitles[i], ((UILabel *)dizhiGesture.view).text]];
            [g_workQueue addObject:tianjiangGesture]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", landmarkTitles[i], ((UILabel *)tianjiangGesture.view).text]];
        }
    }
    
    if (g_workQueue.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"失败" message:@"未能通过空间关联找到任何手势。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好吧" style:UIAlertActionStyleDefault handler:nil]];
        g_isExtracting = NO; return;
    }
    [self processNextStuntDoubleQueueItem];
}

%new
// --- 队列处理器：伪造派发！ ---
- (void)processNextStuntDoubleQueueItem {
    if (g_workQueue.count == 0) {
        NSMutableString *result = [NSMutableString string];
        for (NSUInteger i = 0; i < g_titleQueue.count; i++) {
            [result appendFormat:@"--- %@ ---\n%@\n\n", g_titleQueue[i], g_capturedDetails[i]];
        }
        [UIPasteboard generalPasteboard].string = result;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取完成！" message:@"所有详情已复制到剪贴板！" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"成功！" style:UIAlertActionStyleDefault handler:nil]];
        g_isExtracting = NO; return;
    }
    UIGestureRecognizer *realGesture = g_workQueue.firstObject; [g_workQueue removeObjectAtIndex:0];
    
    Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
    if (!targetsIvar) { [self processNextStuntDoubleQueueItem]; return; }
    NSArray *targets = object_getIvar(realGesture, targetsIvar);
    if (targets.count == 0) { [self processNextStuntDoubleQueueItem]; return; }
    
    id targetActionPair = targets[0];
    id realTarget = [targetActionPair valueForKey:@"target"];
    SEL realAction = NSSelectorFromString([targetActionPair valueForKey:@"action"]);

    if (realTarget && realAction && [realTarget respondsToSelector:realAction]) {
        // ** 终极答案：创建特技替身 **
        // 1. 创建一个和真实手势同类型的伪造手势
        UIGestureRecognizer *stuntGesture = [[[realGesture class] alloc] init];

        // 2. 将伪造手势的view指向真实手势的view，确保上下文正确
        [stuntGesture setValue:realGesture.view forKey:@"view"];

        // 3. 将伪造手势的状态设置为“Ended”，以通过App的状态检查
        stuntGesture.state = UIGestureRecognizerStateEnded;

        // 4. 用伪造手势作为参数，执行真正的Target-Action
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [realTarget performSelector:realAction withObject:stuntGesture];
        #pragma clang diagnostic pop
    } else {
        [self processNextStuntDoubleQueueItem];
    }
}
%end
