#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog(@"[KeChuan-Test-Truth-V13-Simple] " format, ##__VA_ARGS__)

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

// --- viewDidLoad: 创建按钮 ---
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
            [testButton setTitle:@"课传提取(简洁版)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemGreenColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// --- presentViewController: 捕获弹窗并驱动队列 (最核心的时序控制) ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            
            // 确保弹窗能正常加载，但让它透明且无动画
            viewControllerToPresent.view.alpha = 0.0f;
            flag = NO;
            
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); } // 执行原始的completion

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
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) {
                        [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                
                // 【关键】在关闭弹窗的completion中，触发下一个任务，保证时序
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
// --- performKeChuanDetailExtractionTest_Truth: 构建任务队列 ---
- (void)performKeChuanDetailExtractionTest_Truth {
    EchoLog(@"开始V13简洁版测试...");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
    
    // --- Part A: 三传解析 (使用被验证过的最可靠的识别方法) ---
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanContainerClass) {
        NSMutableArray *sanChuanContainers = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, sanChuanContainers);
        if (sanChuanContainers.count > 0) {
            UIView *sanChuanContainer = sanChuanContainers.firstObject;
            Class chuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
            if (chuanViewClass) {
                NSMutableArray *allChuanViews = [NSMutableArray array];
                for (UIView *subview in sanChuanContainer.subviews) {
                    if ([subview isKindOfClass:chuanViewClass]) { [allChuanViews addObject:subview]; }
                }
                [allChuanViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
                    CGPoint p1 = [v1.superview convertPoint:v1.frame.origin toView:self.view];
                    CGPoint p2 = [v2.superview convertPoint:v2.frame.origin toView:self.view];
                    return [@(p1.y) compare:@(p2.y)];
                }];
                NSArray *rowTitles = @[@"初传", @"中传", @"末传"];
                for (NSUInteger i = 0; i < allChuanViews.count; i++) {
                    if (i >= rowTitles.count) break;
                    UIView *chuanView = allChuanViews[i];
                    NSMutableArray *labels = [NSMutableArray array];
                    FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
                    [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
                    if (labels.count >= 2) {
                        UILabel *dizhiLabel = labels[labels.count - 2];
                        UILabel *tianjiangLabel = labels[labels.count - 1];
                        [g_keChuanWorkQueue addObject:dizhiLabel];
                        [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                        [g_keChuanWorkQueue addObject:tianjiangLabel];
                        [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
                    }
                }
            }
        }
    }

    // --- Part B: 四课解析 (同样使用简单可靠的识别方法) ---
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *skViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, skViews);
        if (skViews.count > 0) {
            UIView *siKeContainer = skViews.firstObject;
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
                        [g_keChuanWorkQueue addObject:dizhiLabel];
                        [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", colTitles[i], dizhiLabel.text]];
                        [g_keChuanWorkQueue addObject:tianjiangLabel];
                        [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", colTitles[i], tianjiangLabel.text]];
                    }
                }
            }
        }
    }
    
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"错误: 未找到任何可点击的项目.");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    
    EchoLog(@"队列构建完成, 共%lu项, 开始处理.", (unsigned long)g_keChuanWorkQueue.count);
    [self processKeChuanQueue_Truth];
}

%new
// --- processKeChuanQueue_Truth: 简单地执行队列中的任务 ---
- (void)processKeChuanQueue_Truth {
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"所有任务完成! 生成结果.");
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"所有课传详情已复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];

        g_isExtractingKeChuanDetail = NO;
        g_keChuanWorkQueue = nil;
        g_capturedKeChuanDetailArray = nil;
        g_keChuanTitleQueue = nil;
        return;
    }
    
    UILabel *itemToClick = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    NSString *title = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];

    // 简单的启发式规则来判断是地支还是天将
    SEL actionToPerform = nil;
    if ([title containsString:@"地支"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    } else if ([title containsString:@"天将"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    }

    if (actionToPerform && [self respondsToSelector:actionToPerform]) {
        EchoLog(@"点击: %@", title);
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:itemToClick];
        #pragma clang diagnostic pop
    } else {
        EchoLog(@"警告: 未找到点击方法 for %@. 跳过.", title);
        [self processKeChuanQueue_Truth]; // 如果失败，直接处理下一个，防止卡住
    }
}
%end
