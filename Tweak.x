#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog(@"[EchoAI-Test-KCD-V3] " format, ##__VA_ARGS__)

// --- 全局状态变量 ---
static BOOL g_isTestingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
// 新增一个锁，防止并发问题
static BOOL g_isProcessingDetailView = NO;

// --- 辅助函数 ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}

// --- 声明 ---
@interface UIViewController (EchoAITestAddons)
- (void)performKeChuanDetailTest;
- (NSString *)extractTextFromView:(UIView *)view;
- (void)triggerTapOnView:(UIView *)view;
- (void)expandAndExtractFromDetailView:(UIViewController *)detailVC;
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
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            NSInteger testButtonTag = 999111;
            if ([keyWindow viewWithTag:testButtonTag]) {
                [[keyWindow viewWithTag:testButtonTag] removeFromSuperview];
            }
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 90, 140, 36);
            testButton.tag = testButtonTag;
            [testButton setTitle:@"终极测试" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailTest) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// 2. 拦截弹窗 - V3版，引入锁和展开逻辑
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingKeChuanDetail && !g_isProcessingDetailView) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName isEqualToString:@"六壬大占.課傳摘要視圖"]) {
            g_isProcessingDetailView = YES; // 上锁
            EchoLog(@"捕获到详情视图，开始执行展开和提取流程...");
            
            // 使用一个延迟执行的 completion block，确保 present 动画完成
            void (^newCompletion)(void) = ^{
                if (completion) {
                    completion();
                }
                // 在 present 完成后，执行我们的展开和提取
                [self expandAndExtractFromDetailView:viewControllerToPresent];
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
// 3. 核心测试逻辑 - V3版，增加延迟
- (void)performKeChuanDetailTest {
    EchoLog(@"--- 开始终极测试 ---");
    g_isTestingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];

    NSMutableArray *taskQueue = [NSMutableArray array];
    NSMutableArray *siKeTasksMutable = [NSMutableArray array];
    
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *siKeViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews);
        if (siKeViews.count > 0) {
            UIView *siKeContainer = siKeViews.firstObject;
            [siKeTasksMutable addObjectsFromArray:siKeContainer.subviews];
        }
    }
    
    NSMutableArray *sanChuanTasksMutable = [NSMutableArray array];
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if(sanChuanViewClass){
        NSMutableArray *scViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews);
        [sanChuanTasksMutable addObjectsFromArray:scViews];
    }

    if (siKeTasksMutable.count == 0 && sanChuanTasksMutable.count == 0) {
        EchoLog(@"错误：未能找到任何四课或三传的可点击视图。");
        g_isTestingKeChuanDetail = NO;
        return;
    }
    
    [siKeTasksMutable sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v2.frame.origin.x) compare:@(v1.frame.origin.x)]; }];
    [sanChuanTasksMutable sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];

    [taskQueue addObjectsFromArray:siKeTasksMutable];
    [taskQueue addObjectsFromArray:sanChuanTasksMutable];

    __block NSInteger totalTasks = taskQueue.count;
    EchoLog(@"总任务数: %ld", (long)totalTasks);

    __block void (^processQueue)(void);
    __weak typeof(self) weakSelf = self;

    processQueue = [^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || taskQueue.count == 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                EchoLog(@"--- 所有任务执行完毕 ---");
                
                NSArray *titles = @[@"第1课", @"第2课", @"第3课", @"第4课", @"初传", @"中传", @"末传"];
                NSMutableString *finalResult = [NSMutableString string];
                for (NSUInteger i = 0; i < g_capturedKeChuanDetailArray.count; i++) {
                    NSString *title = (i < titles.count) ? titles[i] : [NSString stringWithFormat:@"项目 %lu", (unsigned long)i+1];
                    NSString *detail = g_capturedKeChuanDetailArray[i];
                    [finalResult appendFormat:@"\n[%@ 详情]\n%@\n\n--------------------\n", title, detail];
                }
                NSLog(@"%@", finalResult);
                
                EchoLog(@"--- 测试结束 ---");
                g_isTestingKeChuanDetail = NO;
                processQueue = nil;
            });
            return;
        }

        UIView *targetView = taskQueue.firstObject;
        [taskQueue removeObjectAtIndex:0];
        NSInteger currentTaskNum = totalTasks - taskQueue.count;
        EchoLog(@"即将处理任务 %ld/%ld...", (long)currentTaskNum, (long)totalTasks);

        [strongSelf triggerTapOnView:targetView];
        
        // **关键改动**: 增加显著延迟，等待下一个任务
        double delayInSeconds = 2.0; // 增加到2秒，确保所有动画完成
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            processQueue();
        });
    } copy];

    processQueue();
}

%new
// 4. 暴力展开并提取文本
- (void)expandAndExtractFromDetailView:(UIViewController *)detailVC {
    UIView *contentView = detailVC.view;
    EchoLog(@"开始暴力展开...");

    // 找到所有的 TableView
    Class tableViewClass = NSClassFromString(@"六壬大占.IntrinsicTableView");
    if (!tableViewClass) {
        tableViewClass = [UITableView class];
    }
    NSMutableArray *tableViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(tableViewClass, contentView, tableViews);
    
    if (tableViews.count > 0) {
        EchoLog(@"找到 %lu 个TableView，开始模拟点击所有行...", (unsigned long)tableViews.count);
        for (UITableView *tableView in tableViews) {
            if ([tableView.delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)] && tableView.dataSource) {
                id<UITableViewDelegate> delegate = tableView.delegate;
                id<UITableViewDataSource> dataSource = tableView.dataSource;
                NSInteger sections = [dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)] ? [dataSource numberOfSectionsInTableView:tableView] : 1;
                for (NSInteger section = 0; section < sections; section++) {
                    NSInteger rows = [dataSource tableView:tableView numberOfRowsInSection:section];
                    for (NSInteger row = 0; row < rows; row++) {
                        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                        // 模拟点击
                        [delegate tableView:tableView didSelectRowAtIndexPath:indexPath];
                    }
                }
            }
        }
    } else {
        EchoLog(@"未找到可展开的TableView。");
    }

    // 在暴力展开后，等待UI刷新
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        EchoLog(@"展开完成，开始提取文本。");
        NSString *detailText = [self extractTextFromView:contentView];
        [g_capturedKeChuanDetailArray addObject:detailText];
        
        // 关闭详情页，并解锁
        [detailVC dismissViewControllerAnimated:NO completion:^{
             EchoLog(@"详情视图已关闭。");
             g_isProcessingDetailView = NO; // 解锁
        }];
    });
}

%new
// 5. 模拟点击手势
- (void)triggerTapOnView:(UIView *)view {
    if (!view) return;
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
            [recognizer setState:UIGestureRecognizerStateEnded];
            return;
        }
    }
    for(UIView *subview in view.subviews) {
        for (UIGestureRecognizer *recognizer in subview.gestureRecognizers) {
            if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
                [recognizer setState:UIGestureRecognizerStateEnded];
                return;
            }
        }
    }
}

%new
// 6. 通用文本提取函数
- (NSString *)extractTextFromView:(UIView *)view {
    NSMutableArray *allLabels = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], view, allLabels);

    [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
        CGPoint p1 = [l1.superview convertPoint:l1.frame.origin toView:nil];
        CGPoint p2 = [l2.superview convertPoint:l2.frame.origin toView:nil];
        if (fabs(p1.y - p2.y) > 5) { // Y坐标差异大，按Y排
            return p1.y < p2.y ? NSOrderedAscending : NSOrderedDescending;
        } else { // Y坐标相近，按X排
            return p1.x < p2.x ? NSOrderedAscending : NSOrderedDescending;
        }
    }];
    
    NSMutableArray *textParts = [NSMutableArray array];
    for (UILabel *label in allLabels) {
         if (label.text && label.text.length > 0) {
            NSString *trimmedText = [label.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (![textParts.lastObject isEqualToString:trimmedText]) {
                [textParts addObject:trimmedText];
            }
        }
    }

    NSString *rawText = [textParts componentsJoinedByString:@"\n"];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\n{2,}" options:0 error:nil];
    return [regex stringByReplacingMatchesInString:rawText options:0 range:NSMakeRange(0, rawText.length) withTemplate:@"\n"];
}

%end
