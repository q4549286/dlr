#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数 (无变化)
// =========================================================================
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray<NSDictionary *> *g_keChuanWorkQueue = nil;
static NSMutableArray<NSString *> *g_keChuanTitleQueue = nil;

static UITextView *g_logTextView = nil;
static UIView *g_controlPanelView = nil;

static void LogMessage(NSString *format, ...) { /* ... */ }
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { /* ... */ }
// 省略 LogMessage 和 FindSubviewsOfClassRecursive 的实现

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)startExtraction_Truth;
- (void)processKeChuanQueue_Truth;
- (void)createOrShowControlPanel_Truth;
- (void)copyAndClose_Truth;
- (void)startKeTiExtraction_Test;
- (void)processKeTiQueue_Test;
@end

%hook UIViewController

// --- viewDidLoad, presentViewController, createOrShowControlPanel_Truth, copyAndClose_Truth (无变化) ---
// 省略这些UI和通用方法的实现

// --- 原有三传+四课提取功能 (无变化) ---
%new
- (void)startExtraction_Truth { /* ... */ }
%new
- (void)processKeChuanQueue_Truth { /* ... */ }
// 省略原有功能的实现

// =========================================================================
// 【【【【【 课体测试模块 - 逻辑修正 】】】】】
// =========================================================================
%new
- (void)startKeTiExtraction_Test {
    if (g_isExtractingKeChuanDetail) { LogMessage(@"错误：提取任务已在进行中。"); return; }
    
    LogMessage(@"--- 开始【课体】独立提取测试 (v2) ---");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
  
    Class ketiViewClass = NSClassFromString(@"六壬大占.課體視圖");
    if (!ketiViewClass) {
        LogMessage(@"【课体测试】错误：找不到 課體視圖 类。");
        g_isExtractingKeChuanDetail = NO; return;
    }

    NSMutableArray *ketiViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(ketiViewClass, self.view, ketiViews);

    if (ketiViews.count == 0) {
        LogMessage(@"【课体测试】错误：在视图层级中找不到 課體視圖 的实例。");
        g_isExtractingKeChuanDetail = NO; return;
    }
    
    UIView *ketiView = ketiViews.firstObject;
    LogMessage(@"【课体测试】成功找到 課體視圖 实例: %@", ketiView);

    // 【新逻辑】遍历所有手势，找到那个正确的
    for (UIGestureRecognizer *gesture in ketiView.gestureRecognizers) {
        // 我们不再关心手势的类型，只要它有目标和动作
        // 使用 runtime 获取手势的所有目标-动作对
        Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
        if (!targetsIvar) {
             LogMessage(@"【课体测试】警告: 无法访问手势的 '_targets' 变量。");
             continue;
        }
        NSArray *targets = object_getIvar(gesture, targetsIvar);
        
        if (targets && targets.count > 0) {
             LogMessage(@"【课体测试】在手势 %@ 上找到 %lu 个目标。", gesture, (unsigned long)targets.count);
             // 遍历所有目标-动作对
             for (id targetWrapper in targets) {
                 // UIGestureRecognizerTarget 是一个私有类，包含 target 和 action
                 SEL action = NULL;
                 id target = nil;
                 // 小心翼翼地从私有对象中取出 target 和 action
                 @try {
                     action = [targetWrapper performSelector:@selector(action)];
                     target = [targetWrapper performSelector:@selector(target)];
                 } @catch (NSException *exception) {
                     LogMessage(@"【课体测试】获取 target/action 失败: %@", exception);
                     continue;
                 }

                 if (target && action) {
                     LogMessage(@"【课体测试】发现目标-动作对! 目标: %@, 动作: %@", target, NSStringFromSelector(action));
                     // 我们找到了一个可行的目标和动作，就用它来创建任务
                     [g_keChuanWorkQueue addObject:@{
                         @"target": target, 
                         @"action": [NSValue valueWithPointer:action], 
                         @"gesture": gesture,
                         @"taskType": @"keTi"
                     }];
                     [g_keChuanTitleQueue addObject:@"课体"];
                     // 假设我们只需要第一个找到的有效目标-动作对
                     goto queue_built;
                 }
             }
        }
    }

queue_built:
    if (g_keChuanWorkQueue.count == 0) {
        LogMessage(@"【课体测试】队列为空，未找到任何可提取的【目标-动作】对。测试结束。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    
    LogMessage(@"【课体测试】任务队列构建完成，总计 %lu 项。", (unsigned long)g_keChuanWorkQueue.count);
    [self processKeTiQueue_Test];
}

%new
- (void)processKeTiQueue_Test {
    if (!g_isExtractingKeChuanDetail || g_keChuanWorkQueue.count == 0) {
        if (g_isExtractingKeChuanDetail) {
            LogMessage(@"---【课体】独立测试处理完毕！---");
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"课体测试完成" message:@"详情已提取，请检查日志和剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
        g_isExtractingKeChuanDetail = NO;
        return;
    }
  
    NSDictionary *task = g_keChuanWorkQueue.firstObject; 
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    NSString *title = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];
    // 【新逻辑】从任务中取出 target, action, 和 gesture
    id target = task[@"target"];
    SEL action = [task[@"action"] pointerValue];
    UIGestureRecognizer *gesture = task[@"gesture"];
    
    LogMessage(@"【课体测试】正在处理: %@", title);
    
    // 【新逻辑】直接调用从手势中获取的 Target-Action
    if (target && action && [target respondsToSelector:action]) {
        LogMessage(@"【课体测试】直接调用 Target-Action: 目标:%@, 动作:%@", target, NSStringFromSelector(action));
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        // 将手势本身作为参数传递，这是标准 Target-Action 模式
        [target performSelector:action withObject:gesture];
        #pragma clang diagnostic pop
    } else {
        LogMessage(@"【课体测试】致命错误！目标(Target)或动作(Action)无效。Target: %@, Action: %@", target, NSStringFromSelector(action));
        [g_capturedKeChuanDetailArray addObject:@"[课体提取失败: Target或Action无效]"];
        [self processKeTiQueue_Test];
    }
}


%end
