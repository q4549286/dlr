// Filename: EchoUltimateMonitorExtractor.x

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 全局变量与UI元素
// =========================================================================

static BOOL g_isGestureMonitoring = NO;
static BOOL g_isDetailExtracting = NO;

static UIView *g_panelView = nil;
static UITextView *g_logView = nil;
static UITextField *g_actionTextField = nil; // 用于输入函数名
static void (^g_completionHandler)(NSString *result);

// =========================================================================
// 2. 辅助函数
// =========================================================================

// 统一日志输出
static void PanelLog(NSString *format, ...) {
    if (!g_logView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
        NSString *newText = [NSString stringWithFormat:@"[%@] %@\n%@", timestamp, message, g_logView.text];
        if (newText.length > 3000) { // 防止日志过长
            newText = [newText substringToIndex:3000];
        }
        g_logView.text = newText;
        NSLog(@"[EchoUltimate] %@", message);
    });
}

// 递归查找子视图
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view) return;
    if ([view isKindOfClass:aClass]) [storage addObject:view];
    for (UIView *subview in view.subviews) FindSubviewsOfClassRecursive(aClass, subview, storage);
}

// =========================================================================
// 3. UIViewController 分类接口
// =========================================================================
@interface UIViewController (EchoUltimate)
- (void)setupUltimatePanel;
- (void)toggleGestureMonitoring:(UIButton *)sender;
- (void)startExtractionWithProvidedAction;
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer;
- (void)dismissKeyboard;
@end


// =========================================================================
// 4. Logos Hooks
// =========================================================================

%hook UIGestureRecognizer
// 手势监控的Hook
- (void)addTarget:(id)target action:(SEL)action {
    %orig;
    if (g_isGestureMonitoring && self.view) {
        NSString *logMessage = [NSString stringWithFormat:@"View: %@\nTarget: %@\nAction: %@",
                                  NSStringFromClass([self.view class]),
                                  NSStringFromClass([target class]),
                                  NSStringFromSelector(action)];
        PanelLog(@"--- GESTURE DETECTED ---\n%@\n-------------------------", logMessage);
        
        // 自动将找到的函数名填入输入框
        dispatch_async(dispatch_get_main_queue(), ^{
            if (g_actionTextField) {
                g_actionTextField.text = NSStringFromSelector(action);
                 PanelLog(@"已将函数名 '%@' 自动填入输入框。", NSStringFromSelector(action));
            }
        });
    }
}
%end

%hook UIViewController

// 弹窗拦截的Hook
- (void)presentViewController:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isDetailExtracting) {
        NSString *vcClassName = NSStringFromClass([vc class]);
        if ([vcClassName containsString:@"摘要視圖"] || (vc.title && vc.title.length > 0)) {
            PanelLog(@"成功捕获到目标弹窗: %@", vc);
            vc.view.alpha = 0.0f;
            void (^newCompletion)(void) = ^{
                if (completion) completion();
                NSMutableArray<UILabel *> *labels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], vc.view, labels);
                [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];
                }];
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in labels) {
                    if (label.text.length > 0) {
                        NSString *cleanedText = [[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        [textParts addObject:cleanedText];
                    }
                }
                NSString *extractedText = [textParts componentsJoinedByString:@"\n"];
                [vc dismissViewControllerAnimated:NO completion:^{
                    PanelLog(@"弹窗已关闭，准备回调。");
                    g_isDetailExtracting = NO;
                    if (g_completionHandler) {
                        g_completionHandler(extractedText);
                        g_completionHandler = nil;
                    }
                }];
            };
            %orig(vc, NO, newCompletion);
            return;
        }
    }
    %orig(vc, flag, completion);
}

// UI注入点
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupUltimatePanel];
        });
    }
}

// =========================================================================
// 5. 新方法实现 (%new)
// =========================================================================

%new
- (void)setupUltimatePanel {
    UIWindow *keyWindow = self.view.window;
    if (!keyWindow || [keyWindow viewWithTag:998877]) return;

    g_panelView = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 300, 350)];
    g_panelView.tag = 998877;
    g_panelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    g_panelView.layer.cornerRadius = 12;
    g_panelView.layer.borderColor = [UIColor yellowColor].CGColor;
    g_panelView.layer.borderWidth = 1.0;
    g_panelView.clipsToBounds = YES;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [g_panelView addGestureRecognizer:pan];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [g_panelView addGestureRecognizer:tap];
    
    // --- 控件布局 ---
    CGFloat yPos = 10.0;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, yPos, 300, 20)];
    titleLabel.text = @"终极监控提取器";
    titleLabel.textColor = [UIColor yellowColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [g_panelView addSubview:titleLabel];
    yPos += 30;

    // 监控按钮
    UIButton *monitorButton = [UIButton buttonWithType:UIButtonTypeSystem];
    monitorButton.frame = CGRectMake(15, yPos, 270, 35);
    [monitorButton setTitle:@"1. 开始监控手势" forState:UIControlStateNormal];
    [monitorButton addTarget:self action:@selector(toggleGestureMonitoring:) forControlEvents:UIControlEventTouchUpInside];
    monitorButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:1.0];
    [monitorButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    monitorButton.layer.cornerRadius = 5;
    [g_panelView addSubview:monitorButton];
    yPos += 45;

    // 函数名输入框
    g_actionTextField = [[UITextField alloc] initWithFrame:CGRectMake(15, yPos, 270, 35)];
    g_actionTextField.placeholder = @"监控到的函数名将显示在此";
    g_actionTextField.borderStyle = UITextBorderStyleRoundedRect;
    g_actionTextField.font = [UIFont systemFontOfSize:14];
    g_actionTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    g_actionTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    g_actionTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [g_panelView addSubview:g_actionTextField];
    yPos += 45;

    // 提取按钮
    UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
    extractButton.frame = CGRectMake(15, yPos, 270, 35);
    [extractButton setTitle:@"2. 用此函数名提取" forState:UIControlStateNormal];
    [extractButton addTarget:self action:@selector(startExtractionWithProvidedAction) forControlEvents:UIControlEventTouchUpInside];
    extractButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.4 alpha:1.0];
    [extractButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    extractButton.layer.cornerRadius = 5;
    [g_panelView addSubview:extractButton];
    yPos += 45;

    // 日志视图
    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, yPos, 280, g_panelView.bounds.size.height - yPos - 10)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor greenColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = NO;
    g_logView.text = @"请按步骤操作：\n1. 点击'开始监控'。\n2. 点击App界面上的'课体'。\n3. 函数名会自动填入上方。\n4. 点击'用此函数名提取'。";
    g_logView.layer.cornerRadius = 5;
    [g_panelView addSubview:g_logView];

    [keyWindow addSubview:g_panelView];
}

%new
- (void)toggleGestureMonitoring:(UIButton *)sender {
    g_isGestureMonitoring = !g_isGestureMonitoring;
    if (g_isGestureMonitoring) {
        [sender setTitle:@"监控中... (再次点击停止)" forState:UIControlStateNormal];
        sender.backgroundColor = [UIColor redColor];
        PanelLog(@"手势监控已开始，请点击目标UI元素...");
    } else {
        [sender setTitle:@"1. 开始监控手势" forState:UIControlStateNormal];
        sender.backgroundColor = [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:1.0];
        PanelLog(@"手势监控已停止。");
    }
}

%new
- (void)startExtractionWithProvidedAction {
    [self dismissKeyboard];
    NSString *actionName = g_actionTextField.text;
    if (!actionName || actionName.length == 0) {
        PanelLog(@"错误：函数名输入框为空！");
        return;
    }
    
    if (g_isDetailExtracting) {
        PanelLog(@"警告：提取任务已在进行中。");
        return;
    }

    PanelLog(@"准备使用函数 '%@' 进行提取...", actionName);

    // 找到课体视图
    Class keTiViewClass = NSClassFromString(@"六壬大占.課體視圖");
    if (!keTiViewClass) {
        PanelLog(@"错误: 找不到 '六壬大占.課體視圖' 类。");
        return;
    }
    NSMutableArray *targetViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(keTiViewClass, self.view, targetViews);
    if (targetViews.count == 0) {
        PanelLog(@"错误: 未找到课体视图实例。");
        return;
    }
    UIView *keTiView = targetViews.firstObject;

    UIGestureRecognizer *gestureToTrigger = keTiView.gestureRecognizers.firstObject;
    if (!gestureToTrigger) {
        PanelLog(@"错误: 课体视图上没有找到手势。");
        return;
    }

    SEL actionToPerform = NSSelectorFromString(actionName);
    if ([self respondsToSelector:actionToPerform]) {
        PanelLog(@"确认控制器响应方法 '%@'，准备触发...", actionName);
        g_isDetailExtracting = YES;
        g_completionHandler = [^(NSString *result) {
            PanelLog(@"--- EXTRACTION SUCCESS ---\n%@\n--------------------------", result);
            [UIPasteboard generalPasteboard].string = result;
            PanelLog(@"结果已复制到剪贴板！");
        } copy];

        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:gestureToTrigger];
        #pragma clang diagnostic pop
        PanelLog(@"方法已调用，等待弹窗被Hook拦截...");
    } else {
        PanelLog(@"错误: 控制器不响应方法 '%@'。请检查函数名是否正确。", actionName);
    }
}

%new
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:g_panelView.superview];
    g_panelView.center = CGPointMake(g_panelView.center.x + translation.x, g_panelView.center.y + translation.y);
    [recognizer setTranslation:CGPointZero inView:g_panelView.superview];
}

%new
- (void)dismissKeyboard {
    [g_actionTextField resignFirstResponder];
}

%end
