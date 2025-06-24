#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog(@"[KeChuan-Test-Truth-V-Final] " format, ##__VA_ARGS__)

static NSInteger const TestButtonTag = 556690;
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray<NSDictionary *> *g_keChuanWorkQueue = nil;
static NSMutableArray<NSString *> *g_keChuanTitleQueue = nil;

// 查找指定类的【第一个】子视图实例
static id FindFirstSubviewOfClass(Class aClass, UIView *view) {
    if ([view isKindOfClass:aClass]) {
        return view;
    }
    for (UIView *subview in view.subviews) {
        id found = FindFirstSubviewOfClass(aClass, subview);
        if (found) {
            return found;
        }
    }
    return nil;
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)performKeChuanDetailExtractionTest_Truth;
- (void)processKeChuanQueue_Truth;
@end

%hook UIViewController

// ... viewDidLoad 和 presentViewController 保持不变 ...
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            if ([keyWindow viewWithTag:TestButtonTag]) { [[keyWindow viewWithTag:TestButtonTag] removeFromSuperview]; }
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"测试课传(最终版)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemGreenColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            viewControllerToPresent.view.alpha = 0.0f; flag = NO;
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                // 提取文本
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; } }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                // 关键：在弹窗完全关闭后，再处理下一个任务
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    [self processKeChuanQueue_Truth];
                }];
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}


%new
- (void)performKeChuanDetailExtractionTest_Truth {
    EchoLog(@"开始执行 [课传详情] 最终版坐标模拟测试");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
    
    // 1. 【核心】定位统一的 `三傳視圖` 实例
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (!sanChuanContainerClass) {
        EchoLog(@"错误: 找不到 '六壬大占.三傳視圖' 这个容器类!");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    UIView *sanChuanContainerView = FindFirstSubviewOfClass(sanChuanContainerClass, self.view);
    if (!sanChuanContainerView) {
        EchoLog(@"错误: 找不到 '六壬大占.三傳視圖' 的实例!");
        g_isExtractingKeChuanDetail = NO;
        return;
    }

    // 2. 找到 `三傳視圖` 内部所有的 Label，并按视觉顺序排序 (Y坐标优先，X坐标其次)
    NSMutableArray<UILabel *> *allLabelsInContainer = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], sanChuanContainerView, allLabelsInContainer);
    [allLabelsInContainer sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
        if (roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
        if (roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
        return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
    }];

    // 3. 按行分组，识别出每一传的 Labels
    NSMutableDictionary<NSNumber *, NSMutableArray<UILabel *> *> *rows = [NSMutableDictionary dictionary];
    for (UILabel *label in allLabelsInContainer) {
        NSNumber *yKey = @(roundf(label.frame.origin.y));
        if (!rows[yKey]) {
            rows[yKey] = [NSMutableArray array];
        }
        [rows[yKey] addObject:label];
    }
    
    // 4. 按 Y 坐标给行排序
    NSArray<NSNumber *> *sortedYKeys = [rows.keys sortedArrayUsingSelector:@selector(compare:)];
    NSArray *rowTitles = @[@"初传", @"中传", @"末传"];
    
    for (NSUInteger i = 0; i < sortedYKeys.count; i++) {
        if (i >= rowTitles.count) break;
        
        NSArray<UILabel *> *rowLabels = rows[sortedYKeys[i]];
        // 在行内按 X 坐标排序
        [rowLabels sortedArrayUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
            return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
        }];
        
        if (rowLabels.count >= 2) {
            // 最右边两个通常是地支和天将
            UILabel *dizhiLabel = rowLabels[rowLabels.count - 2];
            UILabel *tianjiangLabel = rowLabels[rowLabels.count - 1];
            
            // 【关键】计算出 Label 的中心点，并转换到 `三傳視圖` 的坐标系下
            CGPoint dizhiPoint = [dizhiLabel.superview convertPoint:dizhiLabel.center toView:sanChuanContainerView];
            CGPoint tianjiangPoint = [tianjiangLabel.superview convertPoint:tianjiangLabel.center toView:sanChuanContainerView];

            [g_keChuanWorkQueue addObject:@{@"point": [NSValue valueWithCGPoint:dizhiPoint], @"type": @"dizhi"}];
            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
            
            [g_keChuanWorkQueue addObject:@{@"point": [NSValue valueWithCGPoint:tianjiangPoint], @"type": @"tianjiang"}];
            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
        }
    }
    
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"测试失败: 未能从 `三傳視圖` 中构建任何点击任务。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    
    [self processKeChuanQueue_Truth];
}

%new
- (void)processKeChuanQueue_Truth {
    if (g_keChuanWorkQueue.count == 0) {
        // ... 结束逻辑 ...
        return;
    }

    NSDictionary *task = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    CGPoint pointInContainer = [task[@"point"] CGPointValue];
    NSString *itemType = task[@"type"];

    // 找到 `三傳視圖` 实例
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    UIView *sanChuanContainerView = FindFirstSubviewOfClass(sanChuanContainerClass, self.view);
    if (!sanChuanContainerView) {
        EchoLog(@"错误: 处理队列时找不到 `三傳視圖` 实例，跳过任务。");
        [self processKeChuanQueue_Truth];
        return;
    }
    
    // 【最稳健的模拟点击】
    // 1. 创建一个临时视图，它的 frame 就是我们要点击的那个点
    UIView *clickProxy = [[UIView alloc] initWithFrame:CGRectMake(pointInContainer.x, pointInContainer.y, 1, 1)];
    
    // 2. 将临时视图作为参数，调用 `UIViewController` 的方法
    //    因为App的原始逻辑就是这么做的：VC -> 三传视图
    SEL actionToPerform = nil;
    if ([itemType isEqualToString:@"dizhi"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    } else if ([itemType isEqualToString:@"tianjiang"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    }

    if (actionToPerform && [self respondsToSelector:actionToPerform]) {
        EchoLog(@"正在 %@ 上模拟点击: %@", NSStringFromClass([sanChuanContainerView class]), g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count]);
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        // 传递这个代理视图，它的 frame.origin 就是我们想点击的坐标
        [self performSelector:actionToPerform withObject:clickProxy];
        #pragma clang diagnostic pop
    } else {
        EchoLog(@"错误: UIViewController 不响应 %@ 方法", NSStringFromSelector(actionToPerform));
        [self processKeChuanQueue_Truth];
    }
}
%end
