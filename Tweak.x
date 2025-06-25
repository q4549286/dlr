// Filename: EchoUltimateSafeDetector_v3.x

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 全局变量与UI元素
// =========================================================================

static BOOL g_isDetailExtracting = NO;

static UIView *g_panelView = nil;
static UITextView *g_logView = nil;
static UITextField *g_actionTextField = nil;
static void (^g_completionHandler)(NSString *result);

// =========================================================================
// 2. 辅助函数
// =========================================================================

static void PanelLog(NSString *format, ...) {
    if (!g_logView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
        NSString *newText = [NSString stringWithFormat:@"[%@] %@\n%@", timestamp, message, g_logView.text];
        if (newText.length > 3000) { newText = [newText substringToIndex:3000]; }
        g_logView.text = newText;
        NSLog(@"[EchoSafeDetector] %@", message);
    });
}

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
- (void)safeDetectGestureActions;
- (void)startExtractionWithProvidedAction;
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer;
- (void)dismissKeyboard;
@end

// =========================================================================
// 4. Logos Hooks
// =========================================================================

%hook UIViewController

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
                [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
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
    g_panelView.layer.borderColor = [UIColor systemGreenColor].CGColor;
    g_panelView.layer.borderWidth = 1.0;
    g_panelView.clipsToBounds = YES;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [g_panelView addGestureRecognizer:pan];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [g_panelView addGestureRecognizer:tap];
    
    // --- 控件布局 ---
    CGFloat yPos = 10.0;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, yPos, 300, 20)];
    titleLabel.text = @"安全探测提取器 v3";
    titleLabel.textColor = [UIColor systemGreenColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [g_panelView addSubview:titleLabel];
    yPos += 30;

    UIButton *detectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    detectButton.frame = CGRectMake(15, yPos, 270, 35);
    [detectButton setTitle:@"1. 探测'课体'手势" forState:UIControlStateNormal];
    [detectButton addTarget:self action:@selector(safeDetectGestureActions) forControlEvents:UIControlEventTouchUpInside];
    detectButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:1.0];
    [detectButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    detectButton.layer.cornerRadius = 5;
    [g_panelView addSubview:detectButton];
    yPos += 45;

    g_actionTextField = [[UITextField alloc] initWithFrame:CGRectMake(15, yPos, 270, 35)];
    g_actionTextField.placeholder = @"根据探测结果, 在此输入函数名";
    g_actionTextField.borderStyle = UITextBorderStyleRoundedRect;
    g_actionTextField.font = [UIFont systemFontOfSize:14];
    g_actionTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    g_actionTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    g_actionTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    [g_panelView addSubview:g_actionTextField];
    yPos += 45;

    UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
    extractButton.frame = CGRectMake(15, yPos, 270, 35);
    [extractButton setTitle:@"2. 用此函数名提取" forState:UIControlStateNormal];
    [extractButton addTarget:self action:@selector(startExtractionWithProvidedAction) forControlEvents:UIControlEventTouchUpInside];
    extractButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.4 alpha:1.0];
    [extractButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    extractButton.layer.cornerRadius = 5;
    [g_panelView addSubview:extractButton];
    yPos += 45;

    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, yPos, 280, g_panelView.bounds.size.height - yPos - 10)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor greenColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = NO;
    g_logView.text = @"说明:\n1. 点击'探测手势'按钮。\n2. 日志会显示手势的目标类名。\n3. 根据类名和App命名习惯，在上方输入框填入可能的函数名 (例如 顯示課體摘要WithSender:)\n4. 点击'提取'按钮验证。";
    g_logView.layer.cornerRadius = 5;
    [g_panelView addSubview:g_logView];

    [keyWindow addSubview:g_panelView];
}

%new
- (void)safeDetectGestureActions {
    [self dismissKeyboard];
    PanelLog(@"开始安全探测'课体'视图...");

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
    PanelLog(@"成功找到'课体'视图: %@", keTiView);

    if (keTiView.gestureRecognizers.count == 0) {
        PanelLog(@"错误: '课体'视图上没有任何手势识别器。");
        return;
    }

    // *** 这是最安全的方法 ***
    // 它无法直接读取action，但可以帮助我们推断
    PanelLog(@"--- 安全探测结果 ---");
    int i = 0;
    for (UIGestureRecognizer *gesture in keTiView.gestureRecognizers) {
        PanelLog(@"手势 #%d: %@", i++, [gesture class]);
        // 由于无法安全地读取target和action，我们转而关注手势的持有者
        // 通常，手势的目标就是视图所在的ViewController
        // 我们可以通过响应者链来找到它
        UIResponder *responder = keTiView;
        while (responder) {
            if ([responder isKindOfClass:[UIViewController class]]) {
                PanelLog(@"  => 找到可能的响应者(Target): %@", [responder class]);
                // 我们可以基于此做出有根据的猜测
                NSString *probableAction = @"顯示課體摘要WithSender:";
                g_actionTextField.text = probableAction;
                PanelLog(@"  => 已预填一个最可能的函数名: %@", probableAction);
                PanelLog(@"  => 请验证或根据App习惯修改。");
                break; // 找到了就跳出
            }
            responder = [responder nextResponder];
        }
    }
    PanelLog(@"--------------------");
    PanelLog(@"探测完成。请检查日志，确认函数名后点击提取。");
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
    
    // 关键：我们从探测中知道了target是谁，就是当前的ViewController
    if ([self respondsToSelector:actionToPerform]) {
        PanelLog(@"确认当前控制器响应方法 '%@'，准备触发...", actionName);
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
        PanelLog(@"错误: 当前控制器不响应方法 '%@'。请检查函数名是否正确。", actionName);
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
