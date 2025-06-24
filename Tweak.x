#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog(@"[KeChuan-Test-Truth-V5-ClearLogic] " format, ##__VA_ARGS__)

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

// --- viewDidLoad 保持不变 ---
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
            [testButton setTitle:@"测试课传(清晰版)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemGreenColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// --- presentViewController: 保持稳定版本 ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            viewControllerToPresent.view.alpha = 0.0f;
            flag = NO;
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
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) { [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; }
                }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    // 稍作延迟，给UI刷新留出足够时间，防止状态错乱
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

// --- 【核心重构】基于你清晰的定位思路 ---
%new
- (void)performKeChuanDetailExtractionTest_Truth {
    EchoLog(@"开始执行 [课传详情] 清晰逻辑版测试");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];

    // --- Part A: 三传解析 ---
    Class chuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (chuanViewClass) {
        // 1. 找到所有 `傳視圖` 实例
        NSMutableArray *allChuanViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(chuanViewClass, self.view, allChuanViews);

        // 2. 【关键】严格按照 Y 坐标排序，确保顺序是 初传 -> 中传 -> 末传
        [allChuanViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
            return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)];
        }];
        
        NSArray *rowTitles = @[@"初传", @"中传", @"末传"];
        
        // 3. 遍历这个【有序的】视图数组
        for (NSUInteger i = 0; i < allChuanViews.count; i++) {
            if (i >= rowTitles.count) break;
            
            // 明确锁定当前是哪个传的视图
            UIView *chuanView = allChuanViews[i];
            
            // 在这个已锁定的视图内部查找 Labels
            NSMutableArray *labelsInChuanView = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], chuanView, labelsInChuanView);
            [labelsInChuanView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
            }];
            
            if (labelsInChuanView.count >= 2) {
                // 这些 Label 明确属于当前的 chuanView
                UILabel *dizhiLabel = labelsInChuanView[labelsInChuanView.count - 2];
                UILabel *tianjiangLabel = labelsInChuanView[labelsInChuanView.count - 1];
                
                // 4. 将【明确的 Label 实例】加入队列
                [g_keChuanWorkQueue addObject:@{@"item": dizhiLabel, @"type": @"dizhi"}];
                [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                
                [g_keChuanWorkQueue addObject:@{@"item": tianjiangLabel, @"type": @"tianjiang"}];
                [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
            }
        }
    }

    // --- Part B: 四课解析逻辑 (此逻辑本身是稳定的，保持不变) ---
    // (四课的解析逻辑之前一直工作正常，因为它是在一个大的容器内按列划分，不存在三传那样的兄弟视图混淆问题)
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        // ... 四课代码 ...
    }
    
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"测试失败: 未找到任何可点击的课传项目。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    [self processKeChuanQueue_Truth];
}

%new
// --- 队列处理器：回归最简单、最直接的 performSelector ---
- (void)processKeChuanQueue_Truth {
    if (g_keChuanWorkQueue.count == 0) {
        // ... (结束逻辑保持不变)
        EchoLog(@"[课传详情] 测试处理完毕");
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"清晰版测试完成" message:@"所有详情已提取并复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
        g_isExtractingKeChuanDetail = NO;
        g_keChuanWorkQueue = nil; g_capturedKeChuanDetailArray = nil; g_keChuanTitleQueue = nil;
        return;
    }

    NSDictionary *task = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    UIView *itemToClick = task[@"item"]; // 这个 item 是从特定 ChuanView 中找到的，上下文是明确的
    NSString *itemType = task[@"type"];

    SEL actionToPerform = nil;
    if ([itemType isEqualToString:@"dizhi"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    } else if ([itemType isEqualToString:@"tianjiang"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    }

    // 消息的接收者是 self (UIViewController)，参数是 itemToClick (UILabel)
    // 这是最标准的 Target-Action 模式的模拟
    if (actionToPerform && [self respondsToSelector:actionToPerform]) {
        EchoLog(@"正在点击: %@", g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count]);
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:itemToClick];
        #pragma clang diagnostic pop
    } else {
        EchoLog(@"警告: 未能为 %@ 找到并执行对应的点击方法。队列将继续处理下一个项目。", itemType);
        [self processKeChuanQueue_Truth];
    }
}
%end
