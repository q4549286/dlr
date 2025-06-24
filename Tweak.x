#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 宏定义、全局变量与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[KeChuan-Test-Final] " format), ##VA_ARGS)

// --- 全局状态变量 for this test ---
static NSInteger const TestButtonTag = 556680; // Use a new tag
static BOOL g_isTestingKeChuan = NO;
static NSMutableArray *g_capturedTestDetails = nil;

// --- 辅助函数 ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// 新增一个更强大的 ivar 获取函数，因为有些 ivar 可能在父类中
static id GetIvarFromObject(id object, const char *ivarName) {
    Ivar ivar = class_getInstanceVariable([object class], ivarName);
    if (ivar) {
        return object_getIvar(object, ivar);
    }
    return nil;
}

// =========================================================================
// 2. 主功能区：创建测试入口和核心逻辑
// =========================================================================
@interface UIViewController (EchoAITestAddons_Final)
- (void)performKeChuanDetailExtractionTest_Final;
@end

%hook UIViewController

// --- 2.1: 添加独立的测试按钮 ---
(void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            if ([keyWindow viewWithTag:TestButtonTag]) { [[keyWindow viewWithTag:TestButtonTag] removeFromSuperview]; }
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"测试课传详情(终)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.6 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Final) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// --- 2.2: 拦截弹窗 (保持不变，已很稳定) ---
(void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingKeChuan) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; } }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedTestDetails addObject:fullDetail];
            });
            %orig(viewControllerToPresent, NO, completion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
// --- 2.3: 核心测试流程 (终极版) ---
(void)performKeChuanDetailExtractionTest_Final {
    EchoLog(@"--- 开始执行 [课传详情] 最终版测试 ---");
    g_isTestingKeChuan = YES;
    g_capturedTestDetails = [NSMutableArray array];

    NSMutableArray<UIView *> *clickableItems = [NSMutableArray array];
    NSMutableArray<NSString *> *itemTitles = [NSMutableArray array];
    
    // --- Part A: 直接从三传View的ivars中获取UILabel ---
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanViewClass) {
        NSMutableArray *scViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews);
        [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        NSArray *rowTitles = @[@"初传", @"中传", @"末传"];
        for (NSUInteger i = 0; i < scViews.count; i++) {
            UIView *chuanView = scViews[i];
            
            UILabel *dizhiLabel = GetIvarFromObject(chuanView, "傳神字");
            UILabel *tianjiangLabel = GetIvarFromObject(chuanView, "傳乘將");

            if (dizhiLabel) {
                [clickableItems addObject:dizhiLabel];
                [itemTitles addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
            }
            if (tianjiangLabel) {
                [clickableItems addObject:tianjiangLabel];
                [itemTitles addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
            }
        }
        EchoLog(@"在三传中通过ivars找到 %ld 个点击目标。", (long)itemTitles.count);
    }

    // --- Part B: 直接从四课View的ivars中获取UILabel ---
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *skViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, skViews);
        if (skViews.count > 0) {
            UIView *siKeContainer = skViews.firstObject;
            // 定义我们要查找的ivar名称和对应的标题
            NSDictionary<NSString *, NSString *> *ivarMap = @{
                // 第一课 (日上)
                @"日上": @"第一课 - 地支",
                @"日上天將": @"第一课 - 天将",
                // 第二课 (日阴)
                @"日陰": @"第二课 - 地支",
                @"日陰天將": @"第二课 - 天将",
                // 第三课 (辰上)
                @"辰上": @"第三课 - 地支",
                @"辰上天將": @"第三课 - 天将",
                // 第四课 (辰阴)
                @"辰陰": @"第四课 - 地支",
                @"辰陰天將": @"第四课 - 天将",
            };

            for (NSString *ivarName in ivarMap) {
                UILabel *label = GetIvarFromObject(siKeContainer, [ivarName cStringUsingEncoding:NSUTF8StringEncoding]);
                if (label && [label isKindOfClass:[UILabel class]]) {
                    [clickableItems addObject:label];
                    [itemTitles addObject:[NSString stringWithFormat:@"%@(%@)", ivarMap[ivarName], label.text]];
                }
            }
            EchoLog(@"在四课中通过ivars找到 %ld 个点击目标。", (long)8);
        }
    }

    if (clickableItems.count == 0) { /* ... 错误处理 ... */ return; }
    
    __block void (^processQueue)(void);
    NSMutableArray *workQueue = [clickableItems mutableCopy];
    NSMutableArray *titleQueue = [itemTitles mutableCopy];

    // --- Part C: 异步队列处理 (与V2版完全相同) ---
    processQueue = ^{
        if (workQueue.count == 0) {
            EchoLog(@"--- [课传详情] 最终版测试处理完毕 ---");
            NSMutableString *resultStr = [NSMutableString string];
            for (NSUInteger i = 0; i < itemTitles.count; i++) {
                NSString *title = itemTitles[i];
                NSString *detail = (i < g_capturedTestDetails.count) ? g_capturedTestDetails[i] : @"[信息提取失败]";
                [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
            }
            EchoLog(@"\n\n======= 最终提取结果 =======\n%@\n==========================", resultStr);
            [UIPasteboard generalPasteboard].string = resultStr;
            UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"最终版测试完成" message:@"所有详情已提取并复制到剪贴板。请检查日志获取完整内容。" preferredStyle:UIAlertControllerStyleAlert];
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
        
        // 直接调用方法，逻辑不变
        SEL selectorForDizhi = NSSelectorFromString(@"顯示課傳摘要WithSender:");
        SEL selectorForTianjiang = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
        SEL actionToPerform = nil;
        if ([itemTitle containsString:@"地支"]) actionToPerform = selectorForDizhi;
        else if ([itemTitle containsString:@"天将"]) actionToPerform = selectorForTianjiang;
        
        if (actionToPerform && [self respondsToSelector:actionToPerform]) {
             #pragma clang diagnostic push
             #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
             [self performSelector:actionToPerform withObject:itemToClick];
             #pragma clang diagnostic pop
        } else {
            EchoLog(@"警告: 未能为 [%@] 找到并执行对应的点击方法。", itemTitle);
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            processQueue();
        });
    };

    processQueue();
}
%end
