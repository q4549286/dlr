#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog(@"[EchoAI-Test-KCD-V5-SafeMode] " format, ##__VA_ARGS__)

// 全局变量等保持不变...
static BOOL g_isTestingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_keChuanTaskQueue = nil;
static void (^g_processQueueBlock)(void) = nil;

// 辅助函数等保持不变...
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

@interface UIViewController (EchoAITestAddons)
- (void)performKeChuanDetailTest;
- (NSString *)extractTextFromViewHierachy:(UIView *)view;
- (void)triggerTapOnView:(UIView *)view;
@end


%hook UIViewController

// viewDidLoad 和 presentViewController 保持V4版本不变
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
            [testButton setTitle:@"测试课传V5(安全)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor grayColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailTest) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName isEqualToString:@"六壬大占.課傳摘要視圖"]) {
            EchoLog(@"捕获到 '課傳摘要視圖'...");
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                EchoLog(@"'課傳摘要視圖' 已显示，开始提取...");
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    UIView *contentView = viewControllerToPresent.view;
                    // ... 内部展开和提取逻辑保持不变 ...
                    Class tableViewClass = NSClassFromString(@"六壬大占.天將摘要視圖") ?: NSClassFromString(@"六壬大占.IntrinsicTableView") ?: [UITableView class];
                    NSMutableArray *tableViews = [NSMutableArray array];
                    FindSubviewsOfClassRecursive(tableViewClass, contentView, tableViews);
                    if (tableViews.count > 0) {
                         EchoLog(@"找到 %lu 个 TableView，尝试展开...", (unsigned long)tableViews.count);
                         for (UITableView *theTableView in tableViews) {
                            if ([theTableView.delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)] && theTableView.dataSource) {
                                id<UITableViewDelegate> delegate = theTableView.delegate; id<UITableViewDataSource> dataSource = theTableView.dataSource;
                                NSInteger sections = [dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)] ? [dataSource numberOfSectionsInTableView:theTableView] : 1;
                                for (NSInteger section = 0; section < sections; section++) {
                                    NSInteger rows = [dataSource tableView:theTableView numberOfRowsInSection:section];
                                    for (NSInteger row = 0; row < rows; row++) {
                                        [delegate tableView:theTableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
                                    }
                                }
                            }
                         }
                    }
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        NSString *detailText = [self extractTextFromViewHierachy:contentView];
                        [g_capturedKeChuanDetailArray addObject:detailText];
                        EchoLog(@"内容提取完成，关闭详情页。");
                        [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                             if (g_processQueueBlock) { g_processQueueBlock(); }
                        }];
                    });
                });
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}


%new
// 3. 核心测试逻辑 (安全模式)
- (void)performKeChuanDetailTest {
    @try {
        EchoLog(@"--- 开始测试 V5 (安全模式) ---");
        g_isTestingKeChuanDetail = YES;
        g_capturedKeChuanDetailArray = [NSMutableArray array];
        g_keChuanTaskQueue = [NSMutableArray array];

        // --- [核心修改] 回归到查找 subviews，避免硬编码ivar导致闪退 ---
        NSMutableArray *siKeTasksMutable = [NSMutableArray array];
        Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
        if (siKeViewClass) {
            NSMutableArray *siKeViews = [NSMutableArray array]; 
            FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews);
            if (siKeViews.count > 0) {
                UIView *siKeContainer = siKeViews.firstObject;
                [siKeTasksMutable addObjectsFromArray:siKeContainer.subviews];
                EchoLog(@"找到四课容器，获取了 %lu 个子视图作为任务。", (unsigned long)siKeTasksMutable.count);
                // 按X坐标排序
                [siKeTasksMutable sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v2.frame.origin.x) compare:@(v1.frame.origin.x)]; }];
                [g_keChuanTaskQueue addObjectsFromArray:siKeTasksMutable];
            } else {
                 EchoLog(@"警告：未能找到四课容器视图。");
            }
        }

        // --- 三传部分保持不变 ---
        NSMutableArray *sanChuanTasksMutable = [NSMutableArray array];
        Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
        if(sanChuanViewClass){
            FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, sanChuanTasksMutable);
            [sanChuanTasksMutable sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
            [g_keChuanTaskQueue addObjectsFromArray:sanChuanTasksMutable];
        }
        
        if (g_keChuanTaskQueue.count == 0) {
            EchoLog(@"错误：未能获取任何课、传视图。"); g_isTestingKeChuanDetail = NO; return;
        }
        
        EchoLog(@"任务队列准备就绪，总共 %lu 个任务。", (unsigned long)g_keChuanTaskQueue.count);

        __weak typeof(self) weakSelf = self;
        g_processQueueBlock = [^{
            // ... 任务处理循环，保持不变 ...
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf || g_keChuanTaskQueue.count == 0) {
                EchoLog(@"--- 所有任务处理完毕 ---");
                // ... 打印结果 ...
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
            EchoLog(@"处理任务... 目标视图: %@, 剩余 %lu 个", targetView, (unsigned long)g_keChuanTaskQueue.count);
            [strongSelf triggerTapOnView:targetView];
        } copy];

        g_processQueueBlock();

    } @catch (NSException *exception) {
        EchoLog(@"!!!!!! 发生严重异常，导致闪退: %@ !!!!!!", exception);
        EchoLog(@"Call Stack: %@", [exception callStackSymbols]);
        g_isTestingKeChuanDetail = NO;
    }
}

%new
// 4. 模拟点击手势 (安全模式)
- (void)triggerTapOnView:(UIView *)view {
    if (!view) { EchoLog(@"triggerTapOnView: 目标视图为nil"); return; }
    
    EchoLog(@"尝试为视图 %@ 触发点击", view);
    UIGestureRecognizer *tapRecognizer = nil;
    
    // 优先检查视图本身
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
            tapRecognizer = recognizer;
            break;
        }
    }
    
    // 如果没有，检查子视图
    if (!tapRecognizer) {
        for(UIView *subview in view.subviews) {
             for (UIGestureRecognizer *recognizer in subview.gestureRecognizers) {
                if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
                    tapRecognizer = recognizer;
                    break;
                }
            }
            if(tapRecognizer) break;
        }
    }

    if(tapRecognizer) {
        EchoLog(@"找到Tap手势: %@. 使用安全方式触发。", tapRecognizer);
        // [核心修改] 使用更安全的方式，它不完美，但几乎不会闪退
        if(tapRecognizer.state != UIGestureRecognizerStatePossible) {
            [tapRecognizer setState:UIGestureRecognizerStateCancelled];
        }
        [tapRecognizer setState:UIGestureRecognizerStateBegan];
        [tapRecognizer setState:UIGestureRecognizerStateEnded];
    } else {
        EchoLog(@"警告: 未能在视图 %@ 及其子视图上找到Tap手势。", view);
    }
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
            [textParts addObject:[label.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        }
    }

    NSString *rawText = [textParts componentsJoinedByString:@"\n"];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\n{2,}" options:0 error:nil];
    return [regex stringByReplacingMatchesInString:rawText options:0 range:NSMakeRange(0, rawText.length) withTemplate:@"\n"];
}

%end
