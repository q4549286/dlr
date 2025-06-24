#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 全局状态
// =========================================================================
static BOOL g_isExtracting = NO;
static NSMutableArray *g_workQueue = nil;      // 存储UILabel
static NSMutableArray *g_titleQueue = nil;     // 存储标题
static NSMutableString *g_finalResult = nil; // 存储最终结果

// =========================================================================
// 2. 主功能实现
// =========================================================================
@interface UIViewController (FinalBypass)
- (void)startBypassExtraction;
- (void)processNextBypassQueueItem;
@end

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
            [button setTitle:@"提取课传(釜底抽薪)" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:18];
            button.backgroundColor = [UIColor redColor];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.layer.cornerRadius = 22;
            [button addTarget:self action:@selector(startBypassExtraction) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:button];
        });
    }
}

%new
// --- 流程起点：空间关联，但只收集UILabel ---
- (void)startBypassExtraction {
    if (g_isExtracting) { return; }
    g_isExtracting = YES; g_workQueue = [NSMutableArray array]; g_titleQueue = [NSMutableArray array]; g_finalResult = [NSMutableString string];

    // --- 1. 获取地标区域 ---
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

    // --- 2. 获取所有UILabel并按地标分组 ---
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
    
    // --- 3. 构建工作队列 (只取我们关心的区域) ---
    for (int i=0; i<groupedLabels.count; ++i) {
        NSMutableArray *group = groupedLabels[i];
        NSString *baseTitle = landmarkTitles[i];
        if (group.count >= 4) { // 一个区域应该有4个label
            [group sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
                 return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)];
            }];
            UILabel *dizhiLabel = group[2];
            UILabel *tianjiangLabel = group[3];
            [g_workQueue addObject:dizhiLabel]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", baseTitle, dizhiLabel.text]];
            [g_workQueue addObject:tianjiangLabel]; [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", baseTitle, tianjiangLabel.text]];
        }
    }

    if (g_workQueue.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"失败" message:@"釜底抽薪失败：未能通过空间关联找到任何UILabel。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好吧" style:UIAlertActionStyleDefault handler:nil]];
        g_isExtracting = NO; return;
    }
    [self processNextBypassQueueItem];
}

%new
// --- 队列处理器：完全绕过手势，直接处理数据 ---
- (void)processNextBypassQueueItem {
    if (g_workQueue.count == 0) {
        [UIPasteboard generalPasteboard].string = g_finalResult;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取完成！" message:@"所有详情已复制到剪贴板！" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"终于成功了！" style:UIAlertActionStyleDefault handler:nil]];
        g_isExtracting = NO; return;
    }

    UILabel *currentLabel = g_workQueue.firstObject; [g_workQueue removeObjectAtIndex:0];
    NSString *currentTitle = g_titleQueue.firstObject; [g_titleQueue removeObjectAtIndex:0];

    // ** 釜底抽薪的核心 **
    // 之前我们是通过拦截弹窗来获取详情，现在我们反过来：我们只知道弹窗会显示什么
    // 但这个App的逻辑是：弹窗的内容是动态计算的，我们无法在不触发的情况下知道。
    // 这意味着我们最后的希望，还是必须让App自己去展示那个弹窗。
    
    // ** 真正的、最终的、绝对的顿悟 **
    // 我们不能自己创建VC，因为我们没有数据。
    // 我们必须触发手势，但手势的状态不对。
    // 唯一的解法是：强制修改手势的状态。
    
    Class gestureClass = NSClassFromString(@"_TtCC12六壬大占14ViewController18課傳觸摸手勢");
    UIGestureRecognizer *realGesture = nil;
    for(UIGestureRecognizer *g in currentLabel.gestureRecognizers){
        if([g isKindOfClass:gestureClass]){
            realGesture = g;
            break;
        }
    }

    if(realGesture){
        // 使用KVC强制修改readonly的state属性，这是最后的希望
        // 3 = UIGestureRecognizerStateEnded
        [realGesture setValue:@(3) forKey:@"state"];

        Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
        if(targetsIvar){
            NSArray *targets = object_getIvar(realGesture, targetsIvar);
            if(targets.count > 0){
                id targetActionPair = targets[0];
                id realTarget = [targetActionPair valueForKey:@"target"];
                SEL realAction = NSSelectorFromString([targetActionPair valueForKey:@"action"]);
                if(realTarget && realAction && [realTarget respondsToSelector:realAction]){
                    // 用修改了状态的真实手势去触发
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [realTarget performSelector:realAction withObject:realGesture];
                    #pragma clang diagnostic pop
                    
                    // 恢复状态，以防万一
                    // 0 = UIGestureRecognizerStatePossible
                    [realGesture setValue:@(0) forKey:@"state"];
                    return; // 等待presentViewController的拦截
                }
            }
        }
    }

    // 如果以上任何一步失败，直接跳到下一个
    [self processNextBypassQueueItem];
}

// 拦截器，用于捕获数据并驱动队列
%hook UIViewController
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
                [g_finalResult appendFormat:@"--- %@ ---\n%@\n\n", g_titleQueue[g_workQueue.count], capturedDetail];

                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processNextBypassQueueItem];
                    });
                }];
            };
            %orig(viewControllerToPresent, flag, extractionCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}
%end
