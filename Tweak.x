#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 全局变量及UI
// =========================================================================
static UIView *g_loggerPanel = nil;
static UITextView *g_logTextView = nil;
static BOOL g_isHitTestArmed = NO;
static id g_hitTestHook = nil; // 用于存储我们的Hook

static void LogToScreen(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[TruthV15] %@", message);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_logTextView) {
            NSString *currentText = g_logTextView.text;
            g_logTextView.text = [currentText stringByAppendingFormat:@"%@\n", message];
        }
    });
}

// 递归搜索手势的函数
static void FindGesture(UIView *view) {
    if (!view) return;
    
    LogToScreen(@"\n--- 正在检查视图: %@ ---", [view class]);

    if (view.gestureRecognizers.count > 0) {
        LogToScreen(@"【【【【【 重大发现！！！】】】】】");
        LogToScreen(@"在视图 [%@] 上找到了 %lu 个手势！", [view class], (unsigned long)view.gestureRecognizers.count);
        for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
            LogToScreen(@"\n--- 手势详情 ---");
            LogToScreen(@"手势类型: %@", [gesture class]);
            @try {
                Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
                if (targetsIvar) {
                    NSArray *targets = object_getIvar(gesture, targetsIvar);
                    id targetWrapper = targets.firstObject;
                    id finalTarget = [targetWrapper valueForKey:@"target"];
                    SEL finalAction = NSSelectorFromString([targetWrapper valueForKey:@"description"]); // 更hack的方式获取action
                    if (!finalAction) { // 如果上面失败，换一种方式
                         finalAction = [[targetWrapper valueForKey:@"action"] pointerValue];
                    }
                    LogToScreen(@"手势目标 (Target): %@", finalTarget);
                    LogToScreen(@"响应方法 (Action): %@", NSStringFromSelector(finalAction));
                }
            } @catch (NSException *e) {
                LogToScreen(@"获取手势 Target/Action 时发生错误: %@", e);
            }
        }
        LogToScreen(@"【【【【【 检查结束 】】】】】");
    } else {
         LogToScreen(@"-> 该视图上没有手势。正在检查父视图...");
         FindGesture(view.superview); // 向上递归
    }
}

// =========================================================================
// 主界面和Hook逻辑
// =========================================================================
@interface UIViewController (TruthFinder)
- (void)toggleTruthPanel_V15;
- (void)armHitTest_V15;
- (void)copyLogsAndClose_V15;
@end

%hook UIView
// 这是我们的核心，Hook所有UIView的hitTest
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = %orig; // 先调用原始实现，得到最终的命中视图
    
    if (g_isHitTestArmed && hitView && event.type == UIEventTypeTouches) {
        // 一旦命中，立刻解除武装，防止重复触发
        g_isHitTestArmed = NO; 
        
        dispatch_async(dispatch_get_main_queue(), ^{
            LogToScreen(@"==============================================");
            LogToScreen(@"真相捕获！系统认定的命中视图 (HitView):");
            LogToScreen(@"%@", hitView);
            LogToScreen(@"==============================================");

            // 开始从这个命中视图向上追溯手势
            FindGesture(hitView);

            // 显示日志面板
            if (g_loggerPanel) {
                g_loggerPanel.hidden = NO;
            }
        });
    }
    
    return hitView;
}
%end


%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger buttonTag = 150150;
            if ([keyWindow viewWithTag:buttonTag]) { [[keyWindow viewWithTag:buttonTag] removeFromSuperview]; }
            UIButton *truthButton = [UIButton buttonWithType:UIButtonTypeSystem];
            truthButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            truthButton.tag = buttonTag;
            [truthButton setTitle:@"真相面板" forState:UIControlStateNormal];
            truthButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            truthButton.backgroundColor = [UIColor systemRedColor];
            [truthButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            truthButton.layer.cornerRadius = 8;
            [truthButton addTarget:self action:@selector(toggleTruthPanel_V15) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:truthButton];
        });
    }
}

%new
- (void)toggleTruthPanel_V15 {
    if (g_loggerPanel && g_loggerPanel.superview) {
        [g_loggerPanel removeFromSuperview];
        g_loggerPanel = nil; g_logTextView = nil; g_isHitTestArmed = NO;
        return;
    }
    UIWindow *keyWindow = self.view.window;
    g_loggerPanel = [[UIView alloc] initWithFrame:CGRectMake(10, 100, keyWindow.bounds.size.width - 20, 350)];
    g_loggerPanel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    g_loggerPanel.layer.cornerRadius = 12;

    UIButton *armButton = [UIButton buttonWithType:UIButtonTypeSystem];
    armButton.frame = CGRectMake(10, 10, g_loggerPanel.bounds.size.width - 20, 40);
    [armButton setTitle:@"准备监视 (点击后隐藏)" forState:UIControlStateNormal];
    [armButton addTarget:self action:@selector(armHitTest_V15) forControlEvents:UIControlEventTouchUpInside];
    armButton.backgroundColor = [UIColor systemGreenColor];
    [armButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    armButton.layer.cornerRadius = 8;
    [g_loggerPanel addSubview:armButton];

    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 60, g_loggerPanel.bounds.size.width - 20, g_loggerPanel.bounds.size.height - 120)];
    g_logTextView.backgroundColor = [UIColor blackColor];
    g_logTextView.textColor = [UIColor greenColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO;
    g_logTextView.text = @"请点击上方绿色按钮，然后点击一个【课体】单元格来捕获真相。";
    [g_loggerPanel addSubview:g_logTextView];

    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(10, g_loggerPanel.bounds.size.height - 50, g_loggerPanel.bounds.size.width - 20, 40);
    [copyButton setTitle:@"复制真相并关闭" forState:UIControlStateNormal];
    [copyButton addTarget:self action:@selector(copyLogsAndClose_V15) forControlEvents:UIControlEventTouchUpInside];
    copyButton.backgroundColor = [UIColor systemOrangeColor];
    [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyButton.layer.cornerRadius = 8;
    [g_loggerPanel addSubview:copyButton];

    [keyWindow addSubview:g_loggerPanel];
}

%new
- (void)armHitTest_V15 {
    g_isHitTestArmed = YES;
    if (g_logTextView) { g_logTextView.text = @""; }
    if (g_loggerPanel) { g_loggerPanel.hidden = YES; }
}

%new
- (void)copyLogsAndClose_V15 {
    if (g_logTextView.text.length > 0) { [UIPasteboard generalPasteboard].string = g_logTextView.text; }
    [self toggleTruthPanel_V15];
}

%end
