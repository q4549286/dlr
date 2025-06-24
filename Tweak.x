#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog(@"[KeChuan-Test-Ivar] " format, ##__VA_ARGS__)

static NSInteger const TestButtonTag = 556692; // 新的Tag
// ... 其他全局变量不变 ...
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_keChuanWorkQueue = nil;
static NSMutableArray *g_keChuanTitleQueue = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}
static id GetIvarFromObject(id object, const char *ivarName) {
    Ivar ivar = class_getInstanceVariable([object class], ivarName);
    if (ivar) { return object_getIvar(object, ivar); }
    return nil;
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Ivar)
- (void)performKeChuanDetailExtractionTest_Ivar;
- (void)processKeChuanQueue_Ivar;
@end

%hook UIViewController

// --- viewDidLoad 和 presentViewController 保持不变 ---
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
            [testButton setTitle:@"测试课传(Ivar终版)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemRedColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Ivar) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            viewControllerToPresent.view.alpha = 0.0f;
            flag = NO;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) {
                        [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            });
            %orig(viewControllerToPresent, flag, completion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performKeChuanDetailExtractionTest_Ivar {
    EchoLog(@"开始执行 [课传详情] Ivar终版测试");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];

    // --- Part A: 通过Ivar精确找到容器 ---
    UIView *sanChuanContainer = nil;
    UIView *siKeContainer = nil;

    Class topContainerClass = NSClassFromString(@"六壬大占.課傳視圖");
    if (topContainerClass) {
        NSMutableArray *topViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(topContainerClass, self.view, topViews);
        if (topViews.count > 0) {
            UIView *topContainer = topViews.firstObject;
            sanChuanContainer = GetIvarFromObject(topContainer, "三傳");
            siKeContainer = GetIvarFromObject(topContainer, "四課");
            EchoLog(@"通过Ivar定位: 三传容器=%@, 四课容器=%@", sanChuanContainer, siKeContainer);
        }
    }

    // --- Part B: 在正确的三传容器内解析 ---
    if (sanChuanContainer) {
        NSMutableArray *allLabels = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], sanChuanContainer, allLabels);
        NSMutableDictionary<NSString *, NSMutableArray *> *rows = [NSMutableDictionary dictionary];
        for (UILabel *label in allLabels) {
            CGPoint absolutePoint = [label.superview convertPoint:label.frame.origin toView:nil];
            NSString *yKey = [NSString stringWithFormat:@"%.0f", absolutePoint.y];
            if (!rows[yKey]) { rows[yKey] = [NSMutableArray array]; }
            [rows[yKey] addObject:label];
        }
        NSArray *sortedYKeys = [rows.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }];
        NSArray *rowTitles = @[@"初传", @"中传", @"末传"];
        for (NSUInteger i = 0; i < sortedYKeys.count; i++) {
            if (i >= rowTitles.count) break;
            NSMutableArray *rowLabels = rows[sortedYKeys[i]];
            [rowLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            if (rowLabels.count >= 2) {
                UILabel *dizhiLabel = rowLabels[rowLabels.count - 2];
                UILabel *tianjiangLabel = rowLabels[rowLabels.count - 1];
                [g_keChuanWorkQueue addObject:@{@"item": dizhiLabel, @"type": @"dizhi"}];
                [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                [g_keChuanWorkQueue addObject:@{@"item": tianjiangLabel, @"type": @"tianjiang"}];
                [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
            }
        }
    }

    // --- Part C: 在正确的四课容器内解析 ---
    if (siKeContainer) {
        NSMutableArray *allLabels = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], siKeContainer, allLabels);
        NSMutableDictionary *cols = [NSMutableDictionary dictionary];
        for (UILabel *label in allLabels) {
            NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))];
            if (!cols[key]) { cols[key] = [NSMutableArray array]; }
            [cols[key] addObject:label];
        }
        if (cols.allKeys.count == 4) {
            NSArray *sortedKeys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }];
            NSArray *colTitles = @[@"第四课", @"第三课", @"第二课", @"第一课"];
            for (NSUInteger i = 0; i < sortedKeys.count; i++) {
                NSMutableArray *colLabels = cols[sortedKeys[i]];
                [colLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                if (colLabels.count >= 2) {
                    UILabel *tianjiangLabel = colLabels[0];
                    UILabel *dizhiLabel = colLabels[1];
                    [g_keChuanWorkQueue addObject:@{@"item": dizhiLabel, @"type": @"dizhi"}];
                    [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", colTitles[i], dizhiLabel.text]];
                    [g_keChuanWorkQueue addObject:@{@"item": tianjiangLabel, @"type": @"tianjiang"}];
                    [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", colTitles[i], tianjiangLabel.text]];
                }
            }
        }
    }
    
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"测试失败: 未能构建任何点击任务。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    [self processKeChuanQueue_Ivar];
}

%new
// --- 队列处理器 (保持不变) ---
- (void)processKeChuanQueue_Ivar {
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"[课传详情] 测试处理完毕");
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"Ivar终版测试完成" message:@"所有详情已提取并复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
        g_isExtractingKeChuanDetail = NO;
        g_keChuanWorkQueue = nil;
        g_capturedKeChuanDetailArray = nil;
        g_keChuanTitleQueue = nil;
        return;
    }
    NSDictionary *task = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    UIView *itemToClick = task[@"item"];
    NSString *itemType = task[@"type"];
    SEL actionToPerform = nil;
    if ([itemType isEqualToString:@"dizhi"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    } else if ([itemType isEqualToString:@"tianjiang"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    }
    if (actionToPerform && [self respondsToSelector:actionToPerform]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:itemToClick];
        #pragma clang diagnostic pop
    } else {
        EchoLog(@"警告: 未能为 %@ 找到并执行对应的点击方法。", itemType);
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self processKeChuanQueue_Ivar];
    });
}
%end
