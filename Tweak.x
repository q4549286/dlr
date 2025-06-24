#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 宏定义、全局变量与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[KeChuan-Test-V2] " format), ##VA_ARGS)

// --- 全局状态变量 for this test ---
static NSInteger const TestButtonTag = 556679; // Use a new tag to avoid conflicts
static BOOL g_isTestingKeChuan = NO;
static NSMutableArray *g_capturedTestDetails = nil;

// --- 辅助函数 (保持不变) ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能区：创建测试入口和核心逻辑
// =========================================================================
@interface UIViewController (EchoAITestAddons_V2)
- (void)performKeChuanDetailExtractionTest_V2;
@end

%hook UIViewController

// --- 2.1: 添加独立的测试按钮 (不变) ---
(void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            if ([keyWindow viewWithTag:TestButtonTag]) { [[keyWindow viewWithTag:TestButtonTag] removeFromSuperview]; }
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 40, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"测试课传详情V2" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_V2) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// --- 2.2: 拦截弹窗，现在能处理两种类型 ---
(void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingKeChuan) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        // 现在我们检查两种可能的弹窗
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            EchoLog(@"拦截到目标弹窗: %@", vcClassName);
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIView *contentView = viewControllerToPresent.view;
                
                // 通用的文本提取逻辑，对两种弹窗都适用
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
                [g_capturedTestDetails addObject:fullDetail];
                EchoLog(@"提取到的内容:\n%@", fullDetail);

                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            });
            %orig(viewControllerToPresent, NO, completion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
// --- 2.3: 核心测试流程 (V2版) ---
(void)performKeChuanDetailExtractionTest_V2 {
    EchoLog(@"--- 开始执行 [课传详情] V2测试 ---");
    g_isTestingKeChuan = YES;
    g_capturedTestDetails = [NSMutableArray array];

    NSMutableArray<UIView *> *clickableItems = [NSMutableArray array];
    NSMutableArray<NSString *> *itemTitles = [NSMutableArray array];

    // --- Part A: 查找三传中的地支和天将 ---
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanViewClass) {
        NSMutableArray *scViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews);
        [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        NSArray *rowTitles = @[@"初传", @"中传", @"末传"];
        for (NSUInteger i = 0; i < scViews.count; i++) {
            NSMutableArray<UILabel *> *labels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], scViews[i], labels);
            [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            // 假设布局是：[六亲, (神煞...), 地支, 天将]
            if (labels.count >= 3) {
                UILabel *dizhiLabel = labels[labels.count - 2];
                UILabel *tianjiangLabel = labels[labels.count - 1];
                
                // 添加地支点击目标
                [clickableItems addObject:dizhiLabel];
                [itemTitles addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                
                // 添加天将点击目标
                [clickableItems addObject:tianjiangLabel];
                [itemTitles addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
            }
        }
        EchoLog(@"在三传中找到 %ld 个点击目标。", (long)itemTitles.count);
    }

    // --- Part B: 查找四课中的地支和天将 ---
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *skViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, skViews);
        if (skViews.count > 0) {
            UIView *siKeContainer = skViews.firstObject;
            NSMutableArray *labels=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], siKeContainer, labels);
            NSMutableDictionary *cols = [NSMutableDictionary dictionary];
            for(UILabel *label in labels){
                NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))];
                if(!cols[key]){ cols[key]=[NSMutableArray array]; } [cols[key] addObject:label];
            }
            if (cols.allKeys.count == 4) {
                NSArray *keys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }];
                NSArray *colTitles = @[@"第四课", @"第三课", @"第二课", @"第一课"];
                for (NSUInteger i = 0; i < keys.count; i++) {
                    NSMutableArray *colLabels = cols[keys[i]];
                    [colLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                    // 布局是 [天将, 地支, 阴神/干支]
                    if (colLabels.count >= 2) {
                        UILabel *tianjiangLabel = colLabels[0];
                        UILabel *dizhiLabel = colLabels[1];
                        
                        // 添加天将点击目标
                        [clickableItems addObject:tianjiangLabel];
                        [itemTitles addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", colTitles[i], tianjiangLabel.text]];
                        
                        // 添加地支点击目标
                        [clickableItems addObject:dizhiLabel];
                        [itemTitles addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", colTitles[i], dizhiLabel.text]];
                    }
                }
                 EchoLog(@"在四课中找到 %ld 个点击目标。", (long)(itemTitles.count - clickableItems.count + [cols allKeys].count*2));
            }
        }
    }

    if (clickableItems.count == 0) {
        // ... 错误处理逻辑 (不变) ...
        EchoLog(@"测试失败: 未找到任何可点击的课传项目。");
        g_isTestingKeChuan = NO;
        // (省略了UIAlertController以保持简洁)
        return;
    }
    
    __block void (^processQueue)(void);
    NSMutableArray *workQueue = [clickableItems mutableCopy];
    NSMutableArray *titleQueue = [itemTitles mutableCopy];

    // --- Part C: 异步队列处理 (不变) ---
    processQueue = ^{
        if (workQueue.count == 0) {
            // --- Part D: 全部完成，显示结果 ---
            EchoLog(@"--- [课传详情] V2测试处理完毕 ---");
            NSMutableString *resultStr = [NSMutableString string];
            for (NSUInteger i = 0; i < g_capturedTestDetails.count; i++) {
                NSString *title = (i < itemTitles.count) ? itemTitles[i] : @"未知项目";
                NSString *detail = g_capturedTestDetails[i];
                [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
            }
            
            // 为了便于调试，我们直接打印到日志，并复制到剪贴板
            EchoLog(@"\n\n======= 最终提取结果 =======\n%@\n==========================", resultStr);
            [UIPasteboard generalPasteboard].string = resultStr;

            UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"V2测试完成" message:@"所有详情已提取并复制到剪贴板。请检查日志获取完整内容。" preferredStyle:UIAlertControllerStyleAlert];
            [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:successAlert animated:YES completion:nil];
            
            g_isTestingKeChuan = NO;
            processQueue = nil;
            return;
        }

        UIView *itemToClick = workQueue.firstObject;
        NSString *itemTitle = titleQueue.firstObject;
        [workQueue removeObjectAtIndex:0];
        [titleQueue removeObjectAtIndex:0];
        
        EchoLog(@"正在处理: %@", itemTitle);
        
        // --- Part E: 模拟点击 ---
        // 这是最直接的方式，既然我们知道了方法名！
        SEL selectorForDizhi = NSSelectorFromString(@"顯示課傳摘要WithSender:");
        SEL selectorForTianjiang = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");

        SEL actionToPerform = nil;
        if ([itemTitle containsString:@"地支"]) {
            actionToPerform = selectorForDizhi;
        } else if ([itemTitle containsString:@"天将"]) {
            actionToPerform = selectorForTianjiang;
        }
        
        BOOL didClick = NO;
        if (actionToPerform && [self respondsToSelector:actionToPerform]) {
             EchoLog(@"直接调用方法: %@", NSStringFromSelector(actionToPerform));
             #pragma clang diagnostic push
             #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
             [self performSelector:actionToPerform withObject:itemToClick];
             #pragma clang diagnostic pop
             didClick = YES;
        }

        if (!didClick) {
            EchoLog(@"警告: 未能为 [%@] 找到并执行对应的点击方法。", itemTitle);
        }

        // 等待弹窗处理，然后进行下一步
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            processQueue();
        });
    };

    // 启动队列
    processQueue();
}
%end
