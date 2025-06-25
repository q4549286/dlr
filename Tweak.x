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

static void LogMessage(NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss.SSS"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSString *fullMessage = [logPrefix stringByAppendingString:message];
        g_logTextView.text = [NSString stringWithFormat:@"%@\n%@", fullMessage, g_logTextView.text];
        NSLog(@"[KeChuanExtractor] %@", message);
    });
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)startExtraction_Truth;
- (void)processKeChuanQueue_Truth;
- (void)createOrShowControlPanel_Truth;
- (void)copyAndClose_Truth;
- (void)startKeTiExtraction_Test;
@end

%hook UIViewController

// --- viewDidLoad, presentViewController, createOrShowControlPanel_Truth, copyAndClose_Truth 等UI相关代码保持原样，此处省略以保持清晰 ---

// --- 原有三传+四课提取功能 (无变化，此处省略以保持清晰) ---

// =========================================================================
// 【【【【【 新增的独立测试模块 - 等待指令版 】】】】】
// =========================================================================
%new
- (void)startKeTiExtraction_Test {
    if (g_isExtractingKeChuanDetail) { LogMessage(@"错误：提取任务已在进行中。"); return; }
    
    LogMessage(@"--- 开始【课体】侦察任务 ---");
    
    Class ketiViewClass = NSClassFromString(@"六壬大占.課體視圖");
    if (!ketiViewClass) {
        LogMessage(@"【课体侦察】错误：找不到 課體視圖 类。");
        return;
    }

    NSMutableArray *ketiViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(ketiViewClass, self.view, ketiViews);

    if (ketiViews.count == 0) {
        LogMessage(@"【课体侦察】错误：在视图层级中找不到 課體視圖 的实例。");
        return;
    }
    
    UIView *ketiView = ketiViews.firstObject;
    LogMessage(@"【课体侦察】成功找到 課體視圖 实例: %@", ketiView);

    BOOL foundGesture = NO;
    for (UIGestureRecognizer *gesture in ketiView.gestureRecognizers) {
        if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
            LogMessage(@"【课体侦察】在 課體視圖 上找到一个点击手势: %@", gesture);
            LogMessage(@"【行动指令】请在Flex中检查这个手势的 'target' 和 'action'。特别是它的 target 对象（例如 UIMultiSelectInteraction）的 delegate 是谁，以及它有什么方法。");
            foundGesture = YES;
        }
    }

    if (!foundGesture) {
        LogMessage(@"【课体侦察】警告：在 課體視圖 上未找到任何点击手势(UITapGestureRecognizer)。");
    }
    
    LogMessage(@"---【课体】侦察任务结束。等待您的进一步情报。---");
}

%end
