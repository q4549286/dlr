#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog(@"[EchoAI-Test-KCD-V6-DirectCall] " format, ##__VA_ARGS__)

// --- 全局变量 ---
static BOOL g_isTestingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_keChuanTaskQueue = nil;
static void (^g_processQueueBlock)(void) = nil;


// --- 辅助函数 ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}
static id GetIvarView(id object, const char *ivarName) {
    Ivar ivar = class_getInstanceVariable([object class], ivarName);
    if (ivar) { return object_getIvar(object, ivar); }
    return nil;
}

// --- 声明 ---
@interface UIViewController (EchoAITestAddons)
- (void)performKeChuanDetailTest;
- (NSString *)extractTextFromViewHierachy:(UIView *)view;
// 这两个是App自带的方法，我们只是声明一下以便调用
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
            [testButton setTitle:@"测试课传V6(直调)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.8 alpha:1.0]; // 蓝色
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailTest) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// 2. 拦截详情窗口 (逻辑不变)
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName isEqualToString:@"六壬大占.課傳摘要視圖"]) {
            EchoLog(@"捕获到 '課傳摘要視圖'...");
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                EchoLog(@"'課傳摘要視圖' 已显示，开始提取(不再需要模拟展开)...");
                // 因为是直接调用显示方法，理论上内容已经完全了，无需再模拟点击展开
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    NSString *detailText = [self extractTextFromViewHierachy:viewControllerToPresent.view];
                    [g_capturedKeChuanDetailArray addObject:detailText];
                    EchoLog(@"内容提取完成，关闭详情页。");
                    [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                         if (g_processQueueBlock) { g_processQueueBlock(); }
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
// 3. 核心测试逻辑 (终极版 - 直接调用)
- (void)performKeChuanDetailTest {
    EchoLog(@"--- 开始测试 V6 (直接调用) ---");
    g_isTestingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanTaskQueue = [NSMutableArray array];

    // --- 精确获取四课视图 ---
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *siKeViews = [NSMutableArray array]; 
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews);
        if (siKeViews.count > 0) {
            id siKeViewInstance = siKeViews.firstObject;
            // 这里的日辰需要动态获取，我们暂时用一个占位符方法
            // 先用一个通用但不精确的方法获取四课的点击视图
            [g_keChuanTaskQueue addObjectsFromArray:((UIView *)siKeViewInstance).subviews];
            // 排序确保顺序
             [(NSMutableArray *)g_keChuanTaskQueue sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
                return [@(v2.frame.origin.x) compare:@(v1.frame.origin.x)];
            }];
        }
    }
    
    // --- 精确获取三传视图 ---
    NSMutableArray *sanChuanTasksMutable = [NSMutableArray array];
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if(sanChuanViewClass){
        FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, sanChuanTasksMutable);
        [sanChuanTasksMutable sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        [g_keChuanTaskQueue addObjectsFromArray:sanChuanTasksMutable];
    }
    
    if (g_keChuanTaskQueue.count == 0) {
        EchoLog(@"错误：未能获取任何可点击的课、传视图。"); g_isTestingKeChuanDetail = NO; return;
    }
    EchoLog(@"任务队列准备就绪，总共 %lu 个任务。", (unsigned long)g_keChuanTaskQueue.count);

    __weak typeof(self) weakSelf = self;
    g_processQueueBlock = [^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || g_keChuanTaskQueue.count == 0) {
            // ... 结束逻辑 ...
            EchoLog(@"--- 所有任务处理完毕 ---");
            NSMutableString *finalResult = [NSMutableString string];
            NSArray *titles = @[@"第1课", @"第2课", @"第3课", @"第4课", @"初传", @"中传", @"末传"];
            for (NSUInteger i = 0; i < g_capturedKeChuanDetailArray.count; i++) {
                NSString *title = (i < titles.count) ? titles[i] : [NSString stringWithFormat:@"项目 %lu", (unsigned long)i+1];
                [finalResult appendFormat:@"\n[%@ 详情]\n%@\n--------------------\n", title, g_capturedKeChuanDetailArray[i]];
            }
            NSLog(@"%@", finalResult);
            EchoLog(@"--- 测试结束 ---");
            g_isTestingKeChuanDetail = NO; g_processQueueBlock = nil; g_keChuanTaskQueue = nil;
            return;
        }

        UIView *targetView = g_keChuanTaskQueue.firstObject;
        [g_keChuanTaskQueue removeObjectAtIndex:0];
        EchoLog(@"处理任务... 目标视图: %@", targetView);

        // [核心修改] 直接调用ViewController的方法，不再模拟手势
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
            EchoLog(@"错误! ViewController 不响应任何一个摘要显示方法。跳过此任务。");
            if (g_processQueueBlock) { g_processQueueBlock(); }
        }
    } copy];

    g_processQueueBlock();
}

%new
// 5. 提取文本 (保持不变)
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
             // 防止详情页里的标题和外部重复
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
