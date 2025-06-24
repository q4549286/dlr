#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog(@"[EchoAI-Test-KCD-V9-StateMachine] " format, ##__VA_ARGS__)

// --- 全局变量 ---
static BOOL g_isTestingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
// [核心修改] 使用任务列表和索引来驱动流程
static NSMutableArray *g_taskViews = nil;
static int g_currentTaskIndex = 0;

// --- 辅助函数 ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// --- 声明 ---
@interface UIViewController (EchoAITestAddons)
- (void)performKeChuanDetailTest;
- (void)processSingleKeChuanTask; // [新增] 处理单个任务的函数
- (NSString *)extractTextFromViewHierachy:(UIView *)view;
- (void)顯示課傳摘要WithSender:(id)sender;
- (void)顯示課傳天將摘要WithSender:(id)sender;
@end


// =========================================================================
// 主 Hook
// =========================================================================
%hook UIViewController

// 1. 添加测试按钮
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
            NSInteger testButtonTag = 999111; if ([keyWindow viewWithTag:testButtonTag]) { [[keyWindow viewWithTag:testButtonTag] removeFromSuperview]; }
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 90, 140, 36);
            testButton.tag = testButtonTag;
            [testButton setTitle:@"测试课传V9(状态机)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor orangeColor];
            [testButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailTest) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// 2. 拦截详情窗口 (全新状态驱动逻辑)
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName isEqualToString:@"六壬大占.課傳摘要視圖"]) {
            EchoLog(@"捕获到 '課傳摘要視圖'...");
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                EchoLog(@"'課傳摘要視圖' 已显示，提取文本...");
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    NSString *detailText = [self extractTextFromViewHierachy:viewControllerToPresent.view];
                    if (g_capturedKeChuanDetailArray) {
                        [g_capturedKeChuanDetailArray addObject:detailText];
                    }
                    EchoLog(@"提取完成，关闭详情页。");
                    [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                        EchoLog(@"详情页已关闭，准备处理下一个任务。");
                        // [核心修改] 在这里驱动下一个任务
                        [self processSingleKeChuanTask];
                    }];
                });
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

// =========================================================================
// 新增的功能实现
// =========================================================================
%new
// 3. 核心测试逻辑 (初始化并启动)
- (void)performKeChuanDetailTest {
    EchoLog(@"--- 开始测试 V9 (状态机模式) ---");
    g_isTestingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_taskViews = [NSMutableArray array];
    g_currentTaskIndex = 0;

    // 准备任务列表
    NSMutableArray *siKeTasksMutable = [NSMutableArray array];
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *siKeViews = [NSMutableArray array]; 
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews);
        if (siKeViews.count > 0) {
            UIView *siKeContainer = siKeViews.firstObject;
            [siKeTasksMutable addObjectsFromArray:siKeContainer.subviews];
            [siKeTasksMutable sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v2.frame.origin.x) compare:@(v1.frame.origin.x)]; }];
        }
    }
    [g_taskViews addObjectsFromArray:siKeTasksMutable];

    NSMutableArray *sanChuanTasksMutable = [NSMutableArray array];
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if(sanChuanViewClass){
        FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, sanChuanTasksMutable);
        [sanChuanTasksMutable sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        [g_taskViews addObjectsFromArray:sanChuanTasksMutable];
    }
    
    if (g_taskViews.count == 0) {
        EchoLog(@"错误：未能获取任何课、传视图。");
        g_isTestingKeChuanDetail = NO;
        return;
    }
    EchoLog(@"获取到 %lu 个任务视图。", (unsigned long)g_taskViews.count);
    
    // 启动第一个任务
    [self processSingleKeChuanTask];
}

%new
// 4. [新增] 处理单个任务的函数
- (void)processSingleKeChuanTask {
    // 检查是否所有任务都已完成
    if (g_currentTaskIndex >= g_taskViews.count) {
        EchoLog(@"--- 所有任务处理完毕，开始汇总结果 ---");
        NSMutableString *finalResult = [NSMutableString string];
        NSArray *titles = @[@"第1课", @"第2课", @"第3课", @"第4课", @"初传", @"中传", @"末传"];
        for (NSUInteger i = 0; i < g_capturedKeChuanDetailArray.count; i++) {
            NSString *title = (i < titles.count) ? titles[i] : [NSString stringWithFormat:@"项目 %lu", (unsigned long)i+1];
            NSString *detail = g_capturedKeChuanDetailArray[i];
            [finalResult appendFormat:@"\n[%@ 详情]\n%@\n--------------------\n", title, detail];
        }
        NSLog(@"%@", finalResult);
        
        EchoLog(@"--- 测试结束 ---");
        g_isTestingKeChuanDetail = NO;
        g_capturedKeChuanDetailArray = nil;
        g_taskViews = nil;
        g_currentTaskIndex = 0;
        return;
    }

    // 获取当前任务视图并执行
    UIView *targetView = g_taskViews[g_currentTaskIndex];
    EchoLog(@"处理任务 %d/%lu -> 目标视图: %@", g_currentTaskIndex + 1, (unsigned long)g_taskViews.count, targetView);
    
    SEL selectorToShow = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    if (![self respondsToSelector:selectorToShow]) {
        selectorToShow = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    }
    
    if ([self respondsToSelector:selectorToShow]) {
        EchoLog(@"调用方法: %@", NSStringFromSelector(selectorToShow));
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:selectorToShow withObject:targetView];
        #pragma clang diagnostic pop
    } else {
        EchoLog(@"错误! ViewController 不响应摘要显示方法。跳到下一个任务。");
        // 如果调用失败，也要手动推进到下一个任务
        g_currentTaskIndex++;
        [self processSingleKeChuanTask];
    }
    // 关键：这里不主动推进索引，等待dismiss的回调来推进
    g_currentTaskIndex++;
}

%new
// 5. 提取文本函数 (保持不变)
- (NSString *)extractTextFromViewHierachy:(UIView *)view {
    NSMutableArray *allLabels = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], view, allLabels);
    [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
        CGPoint p1 = [l1.superview convertPoint:l1.frame.origin toView:nil];
        CGPoint p2 = [l2.superview convertPoint:l2.frame.origin toView:nil];
        if (p1.y < p2.y - 2) return NSOrderedAscending;
        if (p1.y > p2.y + 2) return NSOrderedDescending;
        if (p1.x < p2.x) return NSOrderedAscending;
        if (p1.x > p2.x) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSMutableArray *textParts = [NSMutableArray array];
    for (UILabel *label in allLabels) {
         if (label.text && label.text.length > 0) {
            NSString *trimmedText = [label.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (![textParts containsObject:trimmedText]) {
                 [textParts addObject:trimmedText];
            }
        }
    }
    NSString *rawText = [textParts componentsJoinedByString:@"\n"];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\n{2,}" options:0 error:nil];
    return [regex stringByReplacingMatchesInString:rawText options:0 range:NSMakeRange(0, rawText.length) withTemplate:@"\n"];
}

%end
