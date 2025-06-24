#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog(@"[EchoAI-Test-KCD-V7-Stable] " format, ##__VA_ARGS__)

// --- 全局变量 ---
static BOOL g_isTestingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;

// --- 辅助函数 ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// --- 声明 ---
@interface UIViewController (EchoAITestAddons)
- (void)performKeChuanDetailTest;
- (NSString *)extractTextFromViewHierachy:(UIView *)view;
// App自带的方法
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
            [testButton setTitle:@"测试课传V7(稳定)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0]; // 亮绿色
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailTest) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// 2. 拦截详情窗口
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName isEqualToString:@"六壬大占.課傳摘要視圖"]) {
            EchoLog(@"捕获到 '課傳摘要視圖'，提取文本...");
            flag = NO; // 禁用动画，加快处理
            viewControllerToPresent.view.alpha = 0.0f;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *detailText = [self extractTextFromViewHierachy:viewControllerToPresent.view];
                if (g_capturedKeChuanDetailArray) {
                    [g_capturedKeChuanDetailArray addObject:detailText];
                }
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            });
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

// =========================================================================
// 新增的功能实现
// =========================================================================
%new
// 3. 核心测试逻辑 (返璞归真版)
- (void)performKeChuanDetailTest {
    EchoLog(@"--- 开始测试 V7 (稳定模式) ---");
    g_isTestingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];

    __weak typeof(self) weakSelf = self;

    // 在后台线程中执行整个流程，避免阻塞UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        // 1. 在主线程获取所有需要点击的视图
        NSMutableArray *taskViews = [NSMutableArray array];
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSMutableArray *siKeTasksMutable = [NSMutableArray array];
            Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
            if (siKeViewClass) {
                NSMutableArray *siKeViews = [NSMutableArray array]; 
                FindSubviewsOfClassRecursive(siKeViewClass, strongSelf.view, siKeViews);
                if (siKeViews.count > 0) {
                    UIView *siKeContainer = siKeViews.firstObject;
                    [siKeTasksMutable addObjectsFromArray:siKeContainer.subviews];
                    [siKeTasksMutable sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
                        return [@(v2.frame.origin.x) compare:@(v1.frame.origin.x)];
                    }];
                }
            }
            [taskViews addObjectsFromArray:siKeTasksMutable];

            NSMutableArray *sanChuanTasksMutable = [NSMutableArray array];
            Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
            if(sanChuanViewClass){
                FindSubviewsOfClassRecursive(sanChuanViewClass, strongSelf.view, sanChuanTasksMutable);
                [sanChuanTasksMutable sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                [taskViews addObjectsFromArray:sanChuanTasksMutable];
            }
        });
        
        if (taskViews.count == 0) {
            EchoLog(@"错误：未能获取任何课、传视图。");
            g_isTestingKeChuanDetail = NO;
            return;
        }
        EchoLog(@"获取到 %lu 个任务视图。", (unsigned long)taskViews.count);

        // 2. 依次处理每个视图
        for (UIView *targetView in taskViews) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                // 优先调用显示天将的那个方法
                SEL selectorToShow = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
                if (![strongSelf respondsToSelector:selectorToShow]) {
                    selectorToShow = NSSelectorFromString(@"顯示課傳摘要WithSender:");
                }
                
                if ([strongSelf respondsToSelector:selectorToShow]) {
                    EchoLog(@"调用方法: %@ withSender: %@", NSStringFromSelector(selectorToShow), targetView);
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [strongSelf performSelector:selectorToShow withObject:targetView];
                    #pragma clang diagnostic pop
                } else {
                    EchoLog(@"错误! ViewController 不响应任何摘要显示方法。");
                }
            });
            // 关键：给一个固定的延迟，让弹窗和提取有时间完成
            [NSThread sleepForTimeInterval:0.4];
        }

        // 3. 所有任务都已触发，回到主线程汇总结果
        dispatch_async(dispatch_get_main_queue(), ^{
            EchoLog(@"--- 所有任务触发完毕，开始汇总结果 ---");
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
        });
    });
}

%new
// 提取文本函数
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
