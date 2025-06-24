#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil; // 将存储最终格式化的 "标题+详情" 字符串
static NSMutableArray *g_keChuanWorkQueue = nil;            // 待点击的UILabel队列
static NSMutableArray *g_keChuanTitleQueue = nil;           // 与UILabel对应的标题队列

// 递归查找指定类的所有子视图
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)performKeChuanDetailExtractionTest_Truth;
- (void)processKeChuanQueue_Truth;
@end

%hook UIViewController

// --- viewDidLoad: 创建功能按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger TestButtonTag = 556690;
            if ([keyWindow viewWithTag:TestButtonTag]) { [[keyWindow viewWithTag:TestButtonTag] removeFromSuperview]; }
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"课传提取(修正版)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemBlueColor]; // 换个颜色以示区别
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// --- presentViewController: 捕获弹窗内容并驱动队列 ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // 仅在我们的提取任务进行时才拦截
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        // 判断是否是我们想要捕获的目标弹窗
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            // 隐藏弹窗动画，加快处理速度
            viewControllerToPresent.view.alpha = 0.0f; flag = NO;
            
            // 创建一个新的completion block来执行我们的提取逻辑
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); } // 如果原始的completion存在，先执行它
                
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                
                // 按从上到下、从左到右的顺序排序Label
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                
                // 提取所有Label的文本
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) {
                        [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                NSString *detailText = [textParts componentsJoinedByString:@"\n"];
                
                // 【【【关键修正 1】】】
                // 我们不再是添加一个新元素，而是将提取到的详情追加到结果数组的最后一个元素（即刚刚添加的标题）后面。
                if (g_capturedKeChuanDetailArray.count > 0) {
                    NSString *lastObject = [g_capturedKeChuanDetailArray lastObject];
                    NSString *updatedObject = [NSString stringWithFormat:@"%@\n%@", lastObject, detailText];
                    [g_capturedKeChuanDetailArray replaceObjectAtIndex:(g_capturedKeChuanDetailArray.count - 1) withObject:updatedObject];
                }

                // 无动画地关闭弹窗，并立即处理队列中的下一个任务
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    [self processKeChuanQueue_Truth];
                }];
            };
            
            %orig(viewControllerToPresent, flag, newCompletion); // 使用我们注入逻辑的completion来调用原始方法
            return;
        }
    }
    // 如果不是提取任务，或者不是目标弹窗，则正常执行
    %orig(viewControllerToPresent, flag, completion);
}

%new
// --- performKeChuanDetailExtractionTest_Truth: 点击按钮后，构建任务队列 ---
- (void)performKeChuanDetailExtractionTest_Truth {
    // 初始化全局状态
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
    
    // Part A: 提取三传信息
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanContainerClass) {
        NSMutableArray *containers = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, containers);
        if (containers.count > 0) {
            UIView *sanChuanContainer = containers.firstObject;
            
            // 使用正确的繁体中文ivar名
            const char *ivarNames[] = {"初傳", "中傳", "末傳", NULL};
            NSString *rowTitles[] = {@"初传", @"中传", @"末传"};
            
            for (int i = 0; ivarNames[i] != NULL; ++i) {
                Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, ivarNames[i]);
                if (ivar) {
                    UIView *chuanView = object_getIvar(sanChuanContainer, ivar);
                    if (chuanView) {
                        NSMutableArray *labels = [NSMutableArray array];
                        FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
                        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
                        
                        if(labels.count >= 2) {
                            // 通常地支在前，天将在后
                            UILabel *dizhiLabel = labels[labels.count-2];
                            UILabel *tianjiangLabel = labels[labels.count-1];
                            
                            // 将UILabel本身存入工作队列
                            [g_keChuanWorkQueue addObject:dizhiLabel];
                            // 将对应的标题存入标题队列
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                            
                            [g_keChuanWorkQueue addObject:tianjiangLabel];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
                        }
                    }
                }
            }
        }
    }
    
    // Part B: 四课 (为简化，暂时省略)

    if (g_keChuanWorkQueue.count == 0) {
        // 如果没有找到任何可点击的项，重置状态
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    
    // 开始处理队列
    [self processKeChuanQueue_Truth];
}

%new
// --- processKeChuanQueue_Truth: 队列处理器，核心逻辑 ---
- (void)processKeChuanQueue_Truth {
    // 结束条件：当工作队列为空时，所有任务完成
    if (g_keChuanWorkQueue.count == 0) {
        // 将最终结果拼接成一个字符串
        NSString *resultStr = [g_capturedKeChuanDetailArray componentsJoinedByString:@"\n\n"];
        
        // 复制到剪贴板并提示用户
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"所有课传详情已复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
        
        // 清理全局变量，重置状态
        g_isExtractingKeChuanDetail = NO;
        g_keChuanWorkQueue = nil;
        g_capturedKeChuanDetailArray = nil;
        g_keChuanTitleQueue = nil;
        return;
    }
    
    // 【【【关键修正 2】】】
    // 同步地从两个队列的头部取出当前任务项（UILabel和其标题）
    UILabel *itemToClick = g_keChuanWorkQueue.firstObject;
    NSString *title = g_keChuanTitleQueue.firstObject;
    
    // 立即将它们从队列中移除，确保下次调用时处理的是下一对任务。这是解决循环问题的关键！
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    [g_keChuanTitleQueue removeObjectAtIndex:0];
    
    // 在触发点击事件前，先把标题添加到结果数组中
    [g_capturedKeChuanDetailArray addObject:[NSString stringWithFormat:@"--- %@ ---", title]];

    // 根据标题内容决定要调用哪个方法
    SEL actionToPerform = nil;
    if ([title containsString:@"地支"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    } else {
        actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    }
    
    // 执行点击动作
    if ([self respondsToSelector:actionToPerform]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:itemToClick];
        #pragma clang diagnostic pop
    } else {
        // 如果因为某种原因，方法不存在，我们跳过这个任务，直接处理下一个，防止队列卡住
        NSLog(@"[TweakLog] Warning: Selector %@ not found. Skipping.", NSStringFromSelector(actionToPerform));
        // 从结果数组中移除刚刚添加的无效标题
        [g_capturedKeChuanDetailArray removeLastObject]; 
        [self processKeChuanQueue_Truth];
    }
}
%end
