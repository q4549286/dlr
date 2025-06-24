#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// [最终修正] 彻底解决编译警告和错误
#define EchoLog(format, ...) NSLog(@"[EchoAI-Test-KCD] " format, ##__VA_ARGS__)

// --- 全局状态变量 ---
static BOOL g_isTestingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;

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
- (NSString *)extractTextFromKeChuanDetailView:(UIView *)detailView;
- (void)triggerTapOnView:(UIView *)view;
@end


// =========================================================================
// 主 Hook
// =========================================================================
%hook UIViewController

// 1. 添加一个测试按钮
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
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 90, 140, 36); // y=90
            testButton.tag = testButtonTag;
            [testButton setTitle:@"测试课传详情" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.8 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailTest) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// 2. 拦截弹出的详情窗口
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName isEqualToString:@"六壬大占.課傳摘要視圖"]) {
            EchoLog(@"[课传详情] 捕获到详情视图，开始提取...");
            flag = NO;
            viewControllerToPresent.view.alpha = 0.0f;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *detailText = [self extractTextFromKeChuanDetailView:viewControllerToPresent.view];
                [g_capturedKeChuanDetailArray addObject:detailText];
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            });
        }
        %orig(viewControllerToPresent, flag, completion);
        return;
    }
    %orig(viewControllerToPresent, flag, completion);
}

// =========================================================================
// 新增的功能实现
// =========================================================================
%new
// 3. 核心测试逻辑
- (void)performKeChuanDetailTest {
    EchoLog(@"--- 开始测试四课三传详情提取 ---");
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
            EchoLog(@"找到了四课视图，包含 %lu 个可点击区域。", (unsigned long)siKeTasksMutable.count);
        }
    }
    
    NSMutableArray *sanChuanTasksMutable = [NSMutableArray array];
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if(sanChuanViewClass){
        NSMutableArray *scViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews);
        [sanChuanTasksMutable addObjectsFromArray:scViews];
        EchoLog(@"找到了三传视图，包含 %lu 个可点击区域。", (unsigned long)sanChuanTasksMutable.count);
    }

    if (siKeTasksMutable.count == 0 && sanChuanTasksMutable.count == 0) {
        EchoLog(@"错误：未能找到任何四课或三传的可点击视图。测试中止。");
        g_isTestingKeChuanDetail = NO;
        return;
    }
    
    [siKeTasksMutable sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
        return [@(v2.frame.origin.x) compare:@(v1.frame.origin.x)];
    }];

    [sanChuanTasksMutable sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) {
        return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];
    }];

    [taskQueue addObjectsFromArray:siKeTasksMutable];
    [taskQueue addObjectsFromArray:sanChuanTasksMutable];

    __block NSInteger totalTasks = taskQueue.count;
    EchoLog(@"总任务数: %ld", (long)totalTasks);

    __block void (^processQueue)(void);
    __weak typeof(self) weakSelf = self;

    processQueue = [^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || taskQueue.count == 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                EchoLog(@"--- 所有课传详情提取完毕 ---");
                EchoLog(@"--- 结果 ---");
                
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
        EchoLog(@"正在处理任务 %ld/%ld...", (long)currentTaskNum, (long)totalTasks);

        [strongSelf triggerTapOnView:targetView];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            processQueue();
        });
    } copy];

    processQueue();
}

%new
// 4. 模拟点击手势 (已优化)
- (void)triggerTapOnView:(UIView *)view {
    if (!view) return;
    
    // 遍历视图上的所有手势识别器
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
            // 直接将手势状态设置为END，这通常会触发其action
            [recognizer setState:UIGestureRecognizerStateEnded];
             return; // 找到并触发后就返回
        }
    }
    // 如果视图本身没有，检查其子视图
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
// 5. 从详情视图中提取文本 (已优化)
- (NSString *)extractTextFromKeChuanDetailView:(UIView *)detailView {
    NSMutableArray *allTextParts = [NSMutableArray array];

    NSMutableArray *stackViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UIStackView class], detailView, stackViews);

    if (stackViews.count > 0) {
        UIStackView *mainStackView = stackViews.firstObject;
        
        for (UIView *arrangedSubview in mainStackView.arrangedSubviews) {
            NSMutableArray *subLabels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], arrangedSubview, subLabels);
            
            // 使用视图在父视图中的绝对坐标进行排序，更可靠
            [subLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
                CGPoint p1 = [l1.superview convertPoint:l1.frame.origin toView:nil];
                CGPoint p2 = [l2.superview convertPoint:l2.frame.origin toView:nil];

                if (roundf(p1.y) < roundf(p2.y)) return NSOrderedAscending;
                if (roundf(p1.y) > roundf(p2.y)) return NSOrderedDescending;
                if (roundf(p1.x) < roundf(p2.x)) return NSOrderedAscending;
                if (roundf(p1.x) > roundf(p2.x)) return NSOrderedDescending;
                return NSOrderedSame;
            }];
                
            for (UILabel *subLabel in subLabels) {
                 if (subLabel.text && subLabel.text.length > 0) {
                    NSString *trimmedText = [subLabel.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    // 防止重复添加完全相同的文本
                    if (![allTextParts.lastObject isEqualToString:trimmedText]) {
                        [allTextParts addObject:trimmedText];
                    }
                }
            }
        }
    }

    NSString *rawText = [allTextParts componentsJoinedByString:@"\n"];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\n{2,}" options:0 error:nil];
    NSString *cleanedText = [regex stringByReplacingMatchesInString:rawText options:0 range:NSMakeRange(0, rawText.length) withTemplate:@"\n"];
    return cleanedText;
}

%end
