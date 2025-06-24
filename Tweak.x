#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog(@"[EchoAI-Test-KCD-V7-Simple] " format, ##__VA_ARGS__)

// --- 全局变量 ---
// 全部移除，不再需要

// --- 辅助函数 ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// --- 声明 ---
@interface UIViewController (EchoAITestAddons)
- (void)performKeChuanDetailTest;
- (NSString *)extractTextFromTopMostPresentedViewController;
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
            [testButton setTitle:@"测试课传V7(极简)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.9 green:0.4 blue:0.1 alpha:1.0]; // 亮橙色
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailTest) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// [核心修改] 不再 hook presentViewController

// =========================================================================
// 新增的功能实现
// =========================================================================
%new
// 3. 核心测试逻辑 (极简版)
- (void)performKeChuanDetailTest {
    EchoLog(@"--- 开始测试 V7 (极简模式) ---");
    
    // 1. 准备任务队列
    NSMutableArray *taskQueue = [NSMutableArray array];
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
    [taskQueue addObjectsFromArray:siKeTasksMutable];

    NSMutableArray *sanChuanTasksMutable = [NSMutableArray array];
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if(sanChuanViewClass){
        FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, sanChuanTasksMutable);
        [sanChuanTasksMutable sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        [taskQueue addObjectsFromArray:sanChuanTasksMutable];
    }
    
    if (taskQueue.count == 0) {
        EchoLog(@"错误：未能获取任何课、传视图。"); return;
    }
    
    EchoLog(@"任务队列准备就绪，总共 %lu 个任务。", (unsigned long)taskQueue.count);
    
    // 2. 使用 dispatch_async 串行执行任务
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *results = [NSMutableArray array];
        
        for (NSUInteger i = 0; i < taskQueue.count; i++) {
            UIView *targetView = taskQueue[i];
            
            // 使用信号量来等待异步操作完成
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                EchoLog(@"处理任务 %lu/%lu... 目标视图: %@", (unsigned long)i + 1, (unsigned long)taskQueue.count, targetView);
                
                // a. 调用显示方法
                SEL selectorToShow = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
                if (![self respondsToSelector:selectorToShow]) {
                    selectorToShow = NSSelectorFromString(@"顯示課傳摘要WithSender:");
                }
                
                if ([self respondsToSelector:selectorToShow]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [self performSelector:selectorToShow withObject:targetView];
                    #pragma clang diagnostic pop
                } else {
                     EchoLog(@"错误! ViewController 不响应摘要显示方法。");
                     dispatch_semaphore_signal(semaphore); // 释放信号，继续下一个
                     return;
                }

                // b. 等待弹窗出现
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    // c. 提取文本
                    NSString *detailText = [self extractTextFromTopMostPresentedViewController];
                    [results addObject:detailText];
                    EchoLog(@"提取到文本，准备关闭。");
                    
                    // d. 关闭当前弹窗
                    [self.presentedViewController dismissViewControllerAnimated:NO completion:^{
                        // e. 弹窗关闭后，释放信号，让循环继续
                        EchoLog(@"弹窗已关闭。");
                        dispatch_semaphore_signal(semaphore);
                    }];
                });
            });
            
            // 等待信号，超时时间设为5秒，防止无限卡死
            dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
        }
        
        // 3. 所有任务完成，回到主线程打印结果
        dispatch_async(dispatch_get_main_queue(), ^{
            EchoLog(@"--- 所有任务处理完毕 ---");
            NSMutableString *finalResult = [NSMutableString string];
            NSArray *titles = @[@"第1课", @"第2课", @"第3课", @"第4课", @"初传", @"中传", @"末传"];
            for (NSUInteger i = 0; i < results.count; i++) {
                NSString *title = (i < titles.count) ? titles[i] : [NSString stringWithFormat:@"项目 %lu", (unsigned long)i+1];
                [finalResult appendFormat:@"\n[%@ 详情]\n%@\n--------------------\n", title, results[i]];
            }
            NSLog(@"%@", finalResult);
            EchoLog(@"--- 测试结束 ---");
        });
    });
}

%new
// 4. 新的提取文本函数，从最顶层VC提取
- (NSString *)extractTextFromTopMostPresentedViewController {
    UIViewController *topVC = self.presentedViewController;
    if (!topVC) {
        EchoLog(@"提取文本失败：找不到 presentedViewController。");
        return @"[提取失败]";
    }

    NSMutableArray *allLabels = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], topVC.view, allLabels);
    
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
