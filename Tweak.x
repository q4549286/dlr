#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数 (无变化)
// =========================================================================
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_keChuanWorkQueue = nil;
static NSMutableArray *g_keChuanTitleQueue = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)performKeChuanDetailExtractionTest_Truth;
- (void)processNextItemInQueue; // 新的流程控制函数
@end

%hook UIViewController

// --- viewDidLoad: (无变化) ---
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
            [testButton setTitle:@"课传提取(稳定版)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemOrangeColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// --- presentViewController: 【【【逻辑简化】】】 ---
// 现在只负责抓取和关闭，不负责驱动队列
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail && ![viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            viewControllerToPresent.view.alpha = 0.0f; flag = NO;
            
            // 抓取数据并立即关闭
            // 使用 dispatch_async 确保在下一个 runloop 中执行，避免干扰 present 过程
            dispatch_async(dispatch_get_main_queue(), ^{
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
                
                // 关闭窗口，不带任何后续操作
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            });
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
// --- performKeChuanDetailExtractionTest_Truth: (无变化) ---
- (void)performKeChuanDetailExtractionTest_Truth {
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
    
    // Part A: 三传
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanContainerClass) {
        NSMutableArray *containers = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, containers);
        if (containers.count > 0) {
            UIView *sanChuanContainer = containers.firstObject;
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
                            UILabel *dizhiLabel = labels[labels.count-2];
                            UILabel *tianjiangLabel = labels[labels.count-1];
                            
                            [g_keChuanWorkQueue addObject:dizhiLabel];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                            
                            [g_keChuanWorkQueue addObject:tianjiangLabel];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
                        }
                    }
                }
            }
        }
    }
    
    // Part B: 四课 (可按三传逻辑添加)
    
    if (g_keChuanWorkQueue.count == 0) {
        g_isExtractingKeChuanDetail = NO;
        // 可以在这里加个提示说没找到课传
        return;
    }
    
    // 启动流程控制器
    [self processNextItemInQueue];
}

%new
// --- 【【【核心逻辑：回归稳定模式】】】 ---
- (void)processNextItemInQueue {
    // 检查队列是否为空，如果为空，则任务完成
    if (g_keChuanWorkQueue.count == 0) {
        // ... 结束逻辑 (无变化) ...
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"所有详情已复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
        
        g_isExtractingKeChuanDetail = NO;
        g_keChuanWorkQueue = nil;
        g_capturedKeChuanDetailArray = nil;
        g_keChuanTitleQueue = nil;
        return;
    }
    
    // 从队列中取出下一个要点击的UILabel
    UILabel *labelToClick = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    // 模拟真实点击
    BOOL actionTriggered = NO;
    for (UIGestureRecognizer *recognizer in labelToClick.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
            NSArray *targets = [recognizer valueForKey:@"targets"];
            if (targets && targets.count > 0) {
                id gestureTarget = targets.firstObject;
                id target = [gestureTarget valueForKey:@"target"];
                SEL action = NSSelectorFromString([gestureTarget valueForKey:@"action"]);
                if (target && action && [target respondsToSelector:action]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [target performSelector:action withObject:recognizer];
                    #pragma clang diagnostic pop
                    actionTriggered = YES;
                    break;
                }
            }
        }
    }
    
    // 如果没有触发动作，就记录一个错误
    if (!actionTriggered) {
        NSLog(@"[课传提取] 警告: 在Label '%@' 上未找到可触发的Tap手势。跳过此项。", labelToClick.text);
        [g_capturedKeChuanDetailArray addObject:@"[错误: 未能触发点击事件]"];
    }

    // 【关键】无论是否成功触发，都等待一个固定时间，然后处理下一个
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self processNextItemInQueue];
    });
}
%end
