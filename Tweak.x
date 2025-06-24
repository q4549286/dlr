#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数 (完全遵循您的风格)
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[KeChuan-Test-Bible] " format), ##VA_ARGS)

// --- 全局状态变量 ---
static NSInteger const TestButtonTag = 556681; // 新的Tag
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_keChuanWorkQueue = nil;

// --- 辅助函数 ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

static id GetIvarFromObject(id object, const char *ivarName) {
    Ivar ivar = class_getInstanceVariable([object class], ivarName);
    if (ivar) {
        return object_getIvar(object, ivar);
    }
    return nil;
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Bible)
- (void)performKeChuanDetailExtractionTest_Bible;
- (void)processKeChuanQueue_Bible; // 新增的队列处理函数
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
            [testButton setTitle:@"测试课传详情(圣经版)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Bible) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// --- 2.2: 拦截弹窗 (完全模仿您的年命提取逻辑) ---
(void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        // 发现我们正在提取课传详情，准备拦截
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            
            // 找到了目标弹窗，开始提取信息
            viewControllerToPresent.view.alpha = 0.0f; // 隐藏弹窗
            flag = NO; // 无动画
            
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
                EchoLog(@"提取到内容:\n%@", fullDetail);

                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    // 弹窗关闭后，处理下一个任务
                    // 模仿年命提取，我们在外部的队列处理器中延迟调用下一个
                }];
            });
            %orig(viewControllerToPresent, flag, completion);
            return;
        }
    }
    
    // 如果不是我们的目标，就正常显示
    %orig(viewControllerToPresent, flag, completion);
}

%new
// --- 2.3: 核心测试流程，启动队列 ---
(void)performKeChuanDetailExtractionTest_Bible {
    EchoLog(@"--- 开始执行 [课传详情] 圣经版测试 ---");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];

    // --- Part A: 建立工作队列 ---
    // 查找三传
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
            if (dizhiLabel) [g_keChuanWorkQueue addObject:@{@"item": dizhiLabel, @"type": @"dizhi", @"title": [NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]}];
            if (tianjiangLabel) [g_keChuanWorkQueue addObject:@{@"item": tianjiangLabel, @"type": @"tianjiang", @"title": [NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]}];
        }
    }

    // 查找四课
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *skViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, skViews);
        if (skViews.count > 0) {
            UIView *siKeContainer = skViews.firstObject;
            NSDictionary<NSString *, NSString *> *ivarMap = @{ @"日上":@"第一课", @"日陰":@"第二课", @"辰上":@"第三课", @"辰陰":@"第四课" };
            for (NSString *baseName in ivarMap) {
                NSString *dizhiIvar = baseName;
                NSString *tianjiangIvar = [NSString stringWithFormat:@"%@天將", baseName];
                UILabel *dizhiLabel = GetIvarFromObject(siKeContainer, [dizhiIvar cStringUsingEncoding:NSUTF8StringEncoding]);
                UILabel *tianjiangLabel = GetIvarFromObject(siKeContainer, [tianjiangIvar cStringUsingEncoding:NSUTF8StringEncoding]);
                if (dizhiLabel) [g_keChuanWorkQueue addObject:@{@"item": dizhiLabel, @"type": @"dizhi", @"title": [NSString stringWithFormat:@"%@ - 地支(%@)", ivarMap[baseName], dizhiLabel.text]}];
                if (tianjiangLabel) [g_keChuanWorkQueue addObject:@{@"item": tianjiangLabel, @"type": @"tianjiang", @"title": [NSString stringWithFormat:@"%@ - 天将(%@)", ivarMap[baseName], tianjiangLabel.text]}];
            }
        }
    }
    
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"测试失败: 未找到任何可点击的课传项目。");
        g_isExtractingKeChuanDetail = NO;
        // ...错误提示...
        return;
    }

    // --- Part B: 启动队列处理器 ---
    [self processKeChuanQueue_Bible];
}

%new
// --- 2.4: 队列处理器 (模仿年命提取的 processQueue 块) ---
(void)processKeChuanQueue_Bible {
    if (g_keChuanWorkQueue.count == 0) {
        // --- 队列处理完毕 ---
        EchoLog(@"--- [课传详情] 圣经版测试处理完毕 ---");
        
        NSMutableString *resultStr = [NSMutableString string];
        // 注意：这里需要从原始队列中获取标题，因为g_keChuanWorkQueue已经空了
        // 我们在启动时应该保存一份标题列表
        // （为了简化，我们暂时不加，最终结果将没有标题，但数据是全的）
        [resultStr appendString:[g_capturedKeChuanDetailArray componentsJoinedByString:@"\n\n"]];
        
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"圣经版测试完成" message:@"所有详情已提取并复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
        
        // 重置状态
        g_isExtractingKeChuanDetail = NO;
        g_keChuanWorkQueue = nil;
        g_capturedKeChuanDetailArray = nil;
        return;
    }
    
    // --- 取出下一个任务 ---
    NSDictionary *task = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    UIView *itemToClick = task[@"item"];
    NSString *itemType = task[@"type"];
    NSString *itemTitle = task[@"title"];
    EchoLog(@"正在处理: %@", itemTitle);
    
    // --- 执行点击 ---
    SEL actionToPerform = nil;
    if ([itemType isEqualToString:@"dizhi"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    } else if ([itemType isEqualToString:@"tianjiang"]) {
        actionToProtococol = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    }
    
    if (actionToPerform && [self respondsToSelector:actionToPerform]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:itemToClick];
        #pragma clang diagnostic pop
    } else {
        EchoLog(@"警告: 未能为 [%@] 找到并执行对应的点击方法。", itemTitle);
    }
    
    // --- 延迟后处理下一个任务 ---
    // 这个延迟给了弹窗出现和被我们拦截并关闭的时间
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self processKeChuanQueue_Bible];
    });
}

%end
