#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog(@"[KeChuan-Test-Truth-V6-DelegateCall] " format, ##__VA_ARGS__)

static NSInteger const TestButtonTag = 556690;
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_keChuanWorkQueue = nil;
static NSMutableArray *g_keChuanTitleQueue = nil;

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
            [testButton setTitle:@"测试课传(代理版)" forState:UIControlStateNormal];
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
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processKeChuanQueue_Truth];
                    });
                }];
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

// --- 【终极核心重构】模拟 CollectionView 代理调用 ---
%new
- (void)performKeChuanDetailExtractionTest_Truth {
    EchoLog(@"开始执行 [课传详情] 代理调用版测试");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];

    Class chuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (!chuanViewClass) {
        EchoLog(@"错误: 找不到 '六壬大占.傳視圖' 类");
        g_isExtractingKeChuanDetail = NO;
        return;
    }

    // 1. 找到所有 `傳視圖` 实例
    NSMutableArray<UIView *> *allChuanViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(chuanViewClass, self.view, allChuanViews);
    if (allChuanViews.count == 0) {
        EchoLog(@"错误: 未找到任何 `傳視圖` 实例");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    
    // 2. 找到它们的共同父视图，我们假设它是一个 CollectionView
    UIView *containerView = allChuanViews.firstObject.superview;
    if (![containerView isKindOfClass:[UICollectionView class]]) {
        EchoLog(@"警告: 三传的父视图 %@ 不是一个 UICollectionView。将尝试按 Y 坐标排序作为后备方案。", NSStringFromClass([containerView class]));
        // 如果不是 CollectionView，退回到 Y 坐标排序
         [allChuanViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
            return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)];
        }];
    }
    
    // 3. 构建任务队列
    NSArray *rowTitles = @[@"初传", @"中传", @"末传"];
    UICollectionView *collectionView = ([containerView isKindOfClass:[UICollectionView class]]) ? (UICollectionView *)containerView : nil;

    for (NSUInteger i = 0; i < allChuanViews.count; i++) {
        if (i >= rowTitles.count) break;
        
        UIView *chuanView = allChuanViews[i];
        NSIndexPath *indexPath = collectionView ? [collectionView indexPathForCell:(UICollectionViewCell *)chuanView] : [NSIndexPath indexPathForRow:i inSection:0];

        // 在视图内部找到地支和天将Label，仅用于获取文本
        NSMutableArray *labels = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
        
        if (labels.count >= 2) {
            UILabel *dizhiLabel = labels[labels.count - 2];
            UILabel *tianjiangLabel = labels[labels.count - 1];

            // 入队：摘要 (地支)
            [g_keChuanWorkQueue addObject:@{@"indexPath": indexPath, @"type": @"dizhi"}];
            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
            
            // 入队：天将
            [g_keChuanWorkQueue addObject:@{@"indexPath": indexPath, @"type": @"tianjiang"}];
            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
        }
    }
    
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"测试失败: 未能构建任何课传任务。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    [self processKeChuanQueue_Truth];
}

%new
// --- 队列处理器：直接调用最可能存在的代理方法 ---
- (void)processKeChuanQueue_Truth {
    if (g_keChuanWorkQueue.count == 0) {
        // ... (结束逻辑)
        EchoLog(@"测试完成");
        // ...
        return;
    }

    NSDictionary *task = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    NSIndexPath *indexPath = task[@"indexPath"];
    NSString *itemType = task[@"type"];
    
    // 我们需要找到那个 CollectionView 和它的 delegate
    Class chuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    NSMutableArray<UIView *> *allChuanViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(chuanViewClass, self.view, allChuanViews);
    if(allChuanViews.count == 0) {
        EchoLog(@"错误：处理队列时找不到傳視圖了。");
        [self processKeChuanQueue_Truth]; // 继续下一个
        return;
    }
    UICollectionView *collectionView = (UICollectionView *)allChuanViews.firstObject.superview;
    id delegate = [collectionView delegate];
    
    // 这是最关键的一步：猜测并调用正确的代理方法
    // 很多自定义的 CollectionView 会有类似这样的方法
    // SEL actionToPerform = @selector(collectionView:didSelectItemAtIndexPath:itemType:); // 这是一个大胆的猜测
    SEL actionToPerform;
    
    // 根据类型，我们调用不同的原始方法
    if ([itemType isEqualToString:@"dizhi"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    } else if ([itemType isEqualToString:@"tianjiang"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    }
    
    // 我们需要正确的 sender
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    if (!cell) {
         // 如果找不到 cell，可能是因为排序的后备方案
         if(indexPath.row < allChuanViews.count) {
             // 通过排序找到的 view 应该就是 cell
             [allChuanViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
                 return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)];
             }];
             cell = (UICollectionViewCell *)allChuanViews[indexPath.row];
         }
    }

    if (!cell) {
        EchoLog(@"错误：在 indexPath %@ 找不到对应的 Cell。", indexPath);
        [self processKeChuanQueue_Truth];
        return;
    }

    // 从cell中找到对应的 label 作为 sender
    UIView *senderLabel = nil;
    NSMutableArray *labelsInCell = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], cell, labelsInCell);
    [labelsInCell sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
    if(labelsInCell.count >= 2){
       if ([itemType isEqualToString:@"dizhi"]) {
           senderLabel = labelsInCell[labelsInCell.count - 2];
       } else {
           senderLabel = labelsInCell[labelsInCell.count - 1];
       }
    }

    if (actionToPerform && [self respondsToSelector:actionToPerform] && senderLabel) {
        EchoLog(@"正在调用 %@ on self with sender from cell at indexPath %@", NSStringFromSelector(actionToPerform), indexPath);
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:senderLabel];
        #pragma clang diagnostic pop
    } else {
        EchoLog(@"致命错误：无法在 self 上执行 %@。", NSStringFromSelector(actionToPerform));
        [self processKeChuanQueue_Truth];
    }
}
%end
