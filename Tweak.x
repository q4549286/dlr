#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-KCD] " format), ##VA_ARGS)

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
            
            // 使用一个独特的tag，避免与主脚本冲突
            NSInteger testButtonTag = 999111;
            if ([keyWindow viewWithTag:testButtonTag]) {
                [[keyWindow viewWithTag:testButtonTag] removeFromSuperview];
            }
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            testButton.tag = testButtonTag;
            [testButton setTitle:@"测试课传详情" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.8 alpha:1.0]; // 蓝色以区分
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
        // 目标视图控制器名称是 "六壬大占.課傳摘要視圖"
        if ([vcClassName isEqualToString:@"六壬大占.課傳摘要視圖"]) {
            EchoLog(@"[课传详情] 捕获到详情视图，开始提取...");
            flag = NO; // 阻止动画
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

    // 找到四课视图并获取其可点击区域
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *siKeViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews);
        if (siKeViews.count > 0) {
            UIView *siKeContainer = siKeViews.firstObject;
            // 假设四课视图的直接子视图就是4个可点击的课容器
            NSArray *keViews = siKeContainer.subviews;
            [taskQueue addObjectsFromArray:keViews];
             EchoLog(@"找到了四课视图，包含 %lu 个可点击区域。", (unsigned long)keViews.count);
        }
    }
    
    // 找到三传视图并获取其可点击区域
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if(sanChuanViewClass){
        NSMutableArray *scViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews);
        // 按Y坐标排序，确保是初传、中传、末传的顺序
        [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) {
            return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];
        }];
        [taskQueue addObjectsFromArray:scViews];
        EchoLog(@"找到了三传视图，包含 %lu 个可点击区域。", (unsigned long)scViews.count);
    }

    if (taskQueue.count == 0) {
        EchoLog(@"错误：未能找到任何四课或三传的可点击视图。测试中止。");
        g_isTestingKeChuanDetail = NO;
        return;
    }
    
    // 按X坐标排序，确保四课是从右到左（第一课到第四课）
    // 假设三传视图已经按Y坐标排好序了
    NSRange siKeRange = NSMakeRange(0, taskQueue.count - 3); // 假设最后三个是三传
    NSArray *siKeTasks = [taskQueue subarrayWithRange:siKeRange];
    NSArray *sanChuanTasks = [taskQueue subarrayWithRange:NSMakeRange(siKeRange.length, 3)];

    siKeTasks = [siKeTasks sortedArrayUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
        // X坐标越大越靠右，是第一课
        return [@(v2.frame.origin.x) compare:@(v1.frame.origin.x)];
    }];

    taskQueue = [[siKeTasks arrayByAddingObjectsFromArray:sanChuanTasks] mutableCopy];

    __block NSInteger totalTasks = taskQueue.count;
    EchoLog(@"总任务数: %ld", (long)totalTasks);

    __block void (^processQueue)(void);
    __weak typeof(self) weakSelf = self;

    processQueue = [^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || taskQueue.count == 0) {
            // 所有任务完成
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
        
        // 设置一个延迟以等待弹窗出现和处理
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            processQueue();
        });
    } copy];

    processQueue();
}

%new
// 4. 模拟点击手势
- (void)triggerTapOnView:(UIView *)view {
    if (!view) return;
    
    // 遍历视图上的所有手势识别器
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
            // 找到目标和动作
            unsigned int count;
            Ivar ivar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
            id targets = object_getIvar(recognizer, ivar);
            
            if (targets && [targets count] > 0) {
                // 通常只有一个target
                id targetContainer = [targets firstObject];
                // UIGestureRecognizerTarget is a private class.
                id target = [targetContainer valueForKey:@"_target"];
                SEL action = NSSelectorFromString([targetContainer valueForKey:@"_action"]);
                
                if (target && action && [target respondsToSelector:action]) {
                    // 模拟执行
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [target performSelector:action withObject:recognizer];
                    #pragma clang diagnostic pop
                    return; // 找到并触发后就返回
                }
            }
        }
    }
     // 如果没有找到手势，可能是在父视图上，或者需要其他点击方式
     // 这里可以添加备用方案，但目前先假设手势在视图本身上
}


%new
// 5. 从详情视图中提取文本
- (NSString *)extractTextFromKeChuanDetailView:(UIView *)detailView {
    NSMutableArray *allTextParts = [NSMutableArray array];

    // 找到最外层的UIStackView
    NSMutableArray *stackViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UIStackView class], detailView, stackViews);

    if (stackViews.count > 0) {
        UIStackView *mainStackView = stackViews.firstObject; // 假设第一个是主堆栈视图
        
        // 遍历堆栈视图中的所有子视图
        for (UIView *arrangedSubview in mainStackView.arrangedSubviews) {
            if ([arrangedSubview isKindOfClass:[UILabel class]]) {
                // 如果是UILabel，直接获取文本
                UILabel *label = (UILabel *)arrangedSubview;
                if (label.text && label.text.length > 0) {
                    [allTextParts addObject:[label.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                }
            } else {
                // 如果不是UILabel（可能是包含其他内容的UIView，比如UITableView）
                // 我们就递归地查找它内部所有的UILabel
                NSMutableArray *subLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], arrangedSubview, subLabels);
                
                // 按y, x坐标排序，确保文本顺序正确
                [subLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
                    if (roundf(l1.frame.origin.y) < roundf(l2.frame.origin.y)) return NSOrderedAscending;
                    if (roundf(l1.frame.origin.y) > roundf(l2.frame.origin.y)) return NSOrderedDescending;
                    return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)];
                }];
                
                for (UILabel *subLabel in subLabels) {
                     if (subLabel.text && subLabel.text.length > 0) {
                        [allTextParts addObject:[subLabel.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                    }
                }
            }
        }
    }

    // 将所有文本片段合并成一个字符串，用换行符分隔
    // 并进行一些清理，移除连续的空行
    NSString *rawText = [allTextParts componentsJoinedByString:@"\n"];
    return [rawText stringByReplacingOccurrencesOfString:@"\n\n" withString:@"\n"];
}

%end
