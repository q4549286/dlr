#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <substrate.h>

// =======================================================================================
//
//  Echo 奇门遁甲提取器 v4.0 (终极毕业版)
//
//  - [终极修复] 修正了所有已知的数据源和UI组件访问方式，确保不再闪退。
//  - [成品] 这是经过所有调试和修正的最终稳定版本。
//
// =======================================================================================


#pragma mark - Constants, Colors & Tags
static const NSInteger kEchoControlButtonTag    = 556699;
static const NSInteger kEchoMainPanelTag        = 778899;
static const NSInteger kEchoProgressHUDTag      = 556677;

static const NSInteger kButtonTag_StandardReport    = 101;
static const NSInteger kButtonTag_ClearInput        = 999;
static const NSInteger kButtonTag_ClosePanel        = 998;
static const NSInteger kButtonTag_SendLastReportToAI = 997;
static const NSInteger kButtonTag_AIPromptToggle    = 996;
static const NSInteger kButtonTag_BenMingToggle     = 995;

#define ECHO_COLOR_MAIN_BLUE        [UIColor colorWithRed:0.17 green:0.31 blue:0.51 alpha:1.0]
#define ECHO_COLOR_MAIN_TEAL        [UIColor colorWithRed:0.23 green:0.49 blue:0.49 alpha:1.0]
#define ECHO_COLOR_AUX_GREY         [UIColor colorWithWhite:0.3 alpha:1.0]
#define ECHO_COLOR_SWITCH_OFF       [UIColor colorWithWhite:0.25 alpha:1.0]
#define ECHO_COLOR_ACTION_CLOSE     [UIColor colorWithWhite:0.25 alpha:1.0]
#define ECHO_COLOR_ACTION_AI        [UIColor colorWithRed:0.22 green:0.59 blue:0.85 alpha:1.0]
#define ECHO_COLOR_SUCCESS          [UIColor colorWithRed:0.4 green:1.0 blue:0.4 alpha:1.0]
#define ECHO_COLOR_PROMPT_ON        [UIColor colorWithRed:0.2 green:0.6 blue:0.35 alpha:1.0]
#define ECHO_COLOR_LOG_TASK         [UIColor whiteColor]
#define ECHO_COLOR_LOG_INFO         [UIColor lightGrayColor]
#define ECHO_COLOR_LOG_WARN         [UIColor orangeColor]
#define ECHO_COLOR_LOG_ERROR        [UIColor redColor]
#define ECHO_COLOR_BACKGROUND_DARK  [UIColor colorWithWhite:0.15 alpha:1.0]
#define ECHO_COLOR_CARD_BG          [UIColor colorWithWhite:0.2 alpha:1.0]

#pragma mark - Global State & Flags
static UIView *g_mainControlPanelView = nil;
static UITextView *g_logTextView = nil;
static __weak UIViewController *g_mainViewController = nil;
static BOOL g_isExtracting = NO;
static NSString *g_lastGeneratedReport = nil;
static UITextView *g_questionTextView = nil;
static UIButton *g_clearInputButton = nil;
static BOOL g_shouldIncludeAIPromptHeader = YES;
static BOOL g_isSomeToggleOn = NO;

#pragma mark - Macros
#define SafeString(str) (str ?: @"")

#pragma mark - Helper Functions
typedef NS_ENUM(NSInteger, EchoLogType) { EchoLogTypeInfo, EchoLogTypeTask, EchoLogTypeSuccess, EchoLogTypeWarning, EchoLogError };
static void LogMessage(EchoLogType type, NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args; va_start(args, format); NSString *message = [[NSString alloc] initWithFormat:format arguments:args]; va_end(args);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init]; [formatter setDateFormat:@"HH:mm:ss"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSMutableAttributedString *logLine = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@\n", logPrefix, message]];
        UIColor *color;
        switch (type) {
            case EchoLogTypeTask:       color = ECHO_COLOR_LOG_TASK; break;
            case EchoLogTypeSuccess:    color = ECHO_COLOR_SUCCESS; break;
            case EchoLogTypeWarning:    color = ECHO_COLOR_LOG_WARN; break;
            case EchoLogError:          color = ECHO_COLOR_LOG_ERROR; break;
            case EchoLogTypeInfo:
            default:                    color = ECHO_COLOR_LOG_INFO; break;
        }
        [logLine addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, logLine.length)];
        [logLine addAttribute:NSFontAttributeName value:g_logTextView.font range:NSMakeRange(0, logLine.length)];
        NSMutableAttributedString *existingText = [[NSMutableAttributedString alloc] initWithAttributedString:g_logTextView.attributedText];
        [logLine appendAttributedString:existingText]; g_logTextView.attributedText = logLine;
        NSLog(@"[Echo框架] %@", message);
    });
}
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if (!view || !storage) return; if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }
static UIWindow* GetFrontmostWindow() { UIWindow *frontmostWindow = nil; if (@available(iOS 13.0, *)) { for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) { if (scene.activationState == UISceneActivationStateForegroundActive) { for (UIWindow *window in scene.windows) { if (window.isKeyWindow) { frontmostWindow = window; break; } } if (frontmostWindow) break; } } } if (!frontmostWindow) { \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"") \
    frontmostWindow = [UIApplication sharedApplication].keyWindow; \
    _Pragma("clang diagnostic pop") \
    } return frontmostWindow; }


__attribute__((unused)) static NSString *getAIPromptHeader() {
    return @""; // 返回空字符串，不添加头部
}

static NSString* formatFinalReport(NSString* reportContent) {
    NSString *userQuestion = (g_questionTextView && g_questionTextView.text.length > 0 && ![g_questionTextView.text isEqualToString:@"选填：输入您想问的具体问题"]) ? g_questionTextView.text : @"";
    if (userQuestion.length > 0) {
        return [NSString stringWithFormat:@"问事: %@\n\n%@", userQuestion, reportContent];
    }
    return SafeString(reportContent);
}

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

@interface UIViewController (EchoAnalysisEngine) <UITextViewDelegate>
- (void)createOrShowMainControlPanel;
- (void)handleMasterButtonTap:(UIButton *)sender;
- (void)handleToolButtonTap:(UIButton *)sender;
- (void)buttonTouchDown:(UIButton *)sender;
- (void)buttonTouchUp:(UIButton *)sender;
- (void)showProgressHUD:(NSString *)text;
- (void)hideProgressHUD;
- (void)showEchoNotificationWithTitle:(NSString *)title message:(NSString *)message;
- (void)startStandardExtraction;
- (NSString *)findTextInViewWithClassName:(NSString *)className separator:(NSString *)separator;
- (void)presentAIActionSheetWithReport:(NSString *)report;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"CZQMHomeViewController"); 
    if (targetClass && [self isKindOfClass:targetClass]) {
        if (g_mainViewController) return;
        g_mainViewController = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = GetFrontmostWindow();
            if (!keyWindow) return;
            if ([keyWindow viewWithTag:kEchoControlButtonTag]) {
                [[keyWindow viewWithTag:kEchoControlButtonTag] removeFromSuperview];
            }
            UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
            controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            controlButton.tag = kEchoControlButtonTag;
            [controlButton setTitle:@"Echo 面板" forState:UIControlStateNormal];
            controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            controlButton.backgroundColor = ECHO_COLOR_MAIN_BLUE;
            [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            controlButton.layer.cornerRadius = 18;
            controlButton.layer.shadowColor = [UIColor blackColor].CGColor;
            controlButton.layer.shadowOffset = CGSizeMake(0, 2);
            controlButton.layer.shadowOpacity = 0.4;
            controlButton.layer.shadowRadius = 3;
            [controlButton addTarget:self action:@selector(createOrShowMainControlPanel) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:controlButton];
        });
    }
}

%new
- (void)createOrShowMainControlPanel {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    if (g_mainControlPanelView && g_mainControlPanelView.superview) {
        [UIView animateWithDuration:0.3 animations:^{ g_mainControlPanelView.alpha = 0; } completion:^(BOOL finished) {
            [g_mainControlPanelView removeFromSuperview];
            g_mainControlPanelView = nil; g_logTextView = nil; g_questionTextView = nil; g_clearInputButton = nil;
        }];
        return;
    }
    g_mainControlPanelView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    g_mainControlPanelView.tag = kEchoMainPanelTag;
    g_mainControlPanelView.backgroundColor = [UIColor clearColor];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blurView.frame = g_mainControlPanelView.bounds;
    [g_mainControlPanelView addSubview:blurView];
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(10, 45, g_mainControlPanelView.bounds.size.width - 20, g_mainControlPanelView.bounds.size.height - 65)];
    [g_mainControlPanelView addSubview:contentView];
    CGFloat padding = 15.0;
    UIButton* (^createButton)(NSString*, NSString*, NSInteger, UIColor*) = ^(NSString* title, NSString* iconName, NSInteger tag, UIColor* color) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.backgroundColor = color; btn.tag = tag;
        if (tag >= 200 && tag < 900) { [btn addTarget:self action:@selector(handleToolButtonTap:) forControlEvents:UIControlEventTouchUpInside]; }
        else {[btn addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside];}
        [btn addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
        [btn addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchDragExit | UIControlEventTouchCancel];
        btn.layer.cornerRadius = 12; [btn setTitle:title forState:UIControlStateNormal];
        if (iconName && [UIImage respondsToSelector:@selector(systemImageNamed:)]) {
            [btn setImage:[UIImage systemImageNamed:iconName] forState:UIControlStateNormal];
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            btn.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, -8);
            btn.imageEdgeInsets = UIEdgeInsetsMake(0, -8, 0, 8);
            #pragma clang diagnostic pop
        }
        btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; btn.tintColor = [UIColor whiteColor];
        return btn;
    };
    UILabel* (^createSectionTitle)(NSString*) = ^(NSString* title) {
        UILabel *label = [[UILabel alloc] init]; label.text = title;
        label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        label.textColor = [UIColor lightGrayColor]; return label;
    };
    CGFloat currentY = 15.0;
    NSMutableAttributedString *titleString = [[NSMutableAttributedString alloc] initWithString:@"Echo 奇门提取器 "];
    [titleString addAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:22 weight:UIFontWeightBold], NSForegroundColorAttributeName: [UIColor whiteColor]} range:NSMakeRange(0, titleString.length)];
    NSAttributedString *versionString = [[NSAttributedString alloc] initWithString:@"v4.0" attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightRegular], NSForegroundColorAttributeName: [UIColor lightGrayColor]}];
    [titleString appendAttributedString:versionString];
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, currentY, contentView.bounds.size.width - 2*padding, 30)];
    titleLabel.attributedText = titleString; titleLabel.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:titleLabel];
    currentY += 30 + 20;
    CGFloat compactButtonHeight = 40.0, innerPadding = 10.0;
    CGFloat cardContentWidth = contentView.bounds.size.width - 2 * padding;
    CGFloat compactBtnWidth = (cardContentWidth - innerPadding) / 2.0;
    NSString *promptTitle = [NSString stringWithFormat:@"Prompt: %@", g_shouldIncludeAIPromptHeader ? @"开启" : @"关闭"];
    UIButton *promptButton = createButton(promptTitle, @"wand.and.stars.inverse", kButtonTag_AIPromptToggle, g_shouldIncludeAIPromptHeader ? ECHO_COLOR_PROMPT_ON : ECHO_COLOR_SWITCH_OFF);
    promptButton.frame = CGRectMake(padding, currentY, compactBtnWidth, compactButtonHeight);
    [contentView addSubview:promptButton];
    NSString *toggleTitle = [NSString stringWithFormat:@"开关: %@", g_isSomeToggleOn ? @"开启" : @"关闭"];
    UIButton *toggleButton = createButton(toggleTitle, @"switch.2", kButtonTag_BenMingToggle, g_isSomeToggleOn ? ECHO_COLOR_PROMPT_ON : ECHO_COLOR_SWITCH_OFF);
    toggleButton.frame = CGRectMake(padding + compactBtnWidth + innerPadding, currentY, compactBtnWidth, compactButtonHeight);
    [contentView addSubview:toggleButton];
    currentY += compactButtonHeight + 15;
    UIView *textViewContainer = [[UIView alloc] initWithFrame:CGRectMake(padding, currentY, contentView.bounds.size.width - 2*padding, 110)];
    textViewContainer.backgroundColor = ECHO_COLOR_CARD_BG; textViewContainer.layer.cornerRadius = 12;
    [contentView addSubview:textViewContainer];
    g_questionTextView = [[UITextView alloc] initWithFrame:CGRectMake(padding, 0, textViewContainer.bounds.size.width - 2*padding - 40, 110)];
    g_questionTextView.backgroundColor = [UIColor clearColor]; g_questionTextView.font = [UIFont systemFontOfSize:14];
    g_questionTextView.textContainerInset = UIEdgeInsetsMake(10, 0, 10, 0); g_questionTextView.delegate = (id<UITextViewDelegate>)self;
    g_questionTextView.returnKeyType = UIReturnKeyDone; g_questionTextView.text = @"选填：输入您想问的具体问题";
    g_questionTextView.textColor = [UIColor lightGrayColor];
    [textViewContainer addSubview:g_questionTextView];
    g_clearInputButton = [UIButton buttonWithType:UIButtonTypeSystem];
    if (@available(iOS 13.0, *)) { [g_clearInputButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal]; }
    g_clearInputButton.frame = CGRectMake(textViewContainer.bounds.size.width - padding - 25, 10, 25, 25);
    g_clearInputButton.tintColor = [UIColor grayColor]; g_clearInputButton.tag = kButtonTag_ClearInput; g_clearInputButton.alpha = 0;
    [g_clearInputButton addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    [textViewContainer addSubview:g_clearInputButton];
    currentY += 110 + 20;
    UIView *card1 = [[UIView alloc] initWithFrame:CGRectMake(padding, currentY, contentView.bounds.size.width - 2*padding, 0)];
    card1.backgroundColor = ECHO_COLOR_CARD_BG; card1.layer.cornerRadius = 12;
    [contentView addSubview:card1];
    CGFloat card1InnerY = 15;
    UILabel *sec1Title = createSectionTitle(@"核心功能");
    sec1Title.frame = CGRectMake(padding, card1InnerY, card1.bounds.size.width - 2*padding, 22);
    [card1 addSubview:sec1Title];
    card1InnerY += 22 + 10;
    UIButton *stdButton = createButton(@"提取奇门盘", @"doc.text.fill", kButtonTag_StandardReport, ECHO_COLOR_MAIN_TEAL);
    stdButton.frame = CGRectMake(padding, card1InnerY, card1.bounds.size.width - 2*padding, 48);
    [card1 addSubview:stdButton];
    card1InnerY += 48 + 15;
    card1.frame = CGRectMake(padding, currentY, card1.bounds.size.width, card1InnerY);
    currentY += card1.frame.size.height + 20;
    CGFloat bottomButtonsHeight = 40, bottomAreaPadding = 10, logTopPadding = 20;
    CGFloat bottomButtonsY = contentView.bounds.size.height - bottomButtonsHeight - bottomAreaPadding;
    CGFloat logViewY = currentY + logTopPadding;
    CGFloat logViewHeight = bottomButtonsY - logViewY - bottomAreaPadding;
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(padding, logViewY, contentView.bounds.size.width - 2*padding, logViewHeight)];
    g_logTextView.backgroundColor = ECHO_COLOR_CARD_BG; g_logTextView.layer.cornerRadius = 12;
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12];
    g_logTextView.editable = NO; g_logTextView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    g_logTextView.attributedText = [[NSAttributedString alloc] initWithString:@"[Echo奇门提取器]：就绪。\n" attributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: g_logTextView.font}];
    [contentView addSubview:g_logTextView];
    CGFloat bottomBtnWidth = (contentView.bounds.size.width - 2*padding - padding) / 2.0;
    UIButton *closeButton = createButton(@"关闭", @"xmark.circle", kButtonTag_ClosePanel, ECHO_COLOR_ACTION_CLOSE);
    closeButton.frame = CGRectMake(padding, bottomButtonsY, bottomBtnWidth, bottomButtonsHeight);
    [contentView addSubview:closeButton];
    UIButton *sendLastReportButton = createButton(@"发送数据", @"arrow.up.forward.app", kButtonTag_SendLastReportToAI, ECHO_COLOR_ACTION_AI);
    sendLastReportButton.frame = CGRectMake(padding + bottomBtnWidth + padding, bottomButtonsY, bottomBtnWidth, bottomButtonsHeight);
    [contentView addSubview:sendLastReportButton];
    g_mainControlPanelView.alpha = 0; g_mainControlPanelView.transform = CGAffineTransformMakeScale(1.05, 1.05);
    [keyWindow addSubview:g_mainControlPanelView];
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.2 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        g_mainControlPanelView.alpha = 1.0; g_mainControlPanelView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

%new
- (void)handleMasterButtonTap:(UIButton *)sender {
    [self buttonTouchUp:sender];
    if (g_isExtracting && sender.tag != kButtonTag_ClosePanel) {
        LogMessage(EchoLogError, @"[错误] 提取任务进行中..."); return;
    }
    switch (sender.tag) {
        case kButtonTag_StandardReport: [self startStandardExtraction]; break;
        case kButtonTag_ClearInput: { g_questionTextView.text = @""; [self textViewDidEndEditing:g_questionTextView]; [g_questionTextView resignFirstResponder]; break; }
        case kButtonTag_ClosePanel: [self createOrShowMainControlPanel]; break;
        case kButtonTag_SendLastReportToAI: {
            if (g_lastGeneratedReport.length > 0) { [self presentAIActionSheetWithReport:g_lastGeneratedReport]; } 
            else { LogMessage(EchoLogTypeWarning, @"无缓存数据。"); [self showEchoNotificationWithTitle:@"操作无效" message:@"请先提取数据。"]; }
            break;
        }
        case kButtonTag_AIPromptToggle:{
            g_shouldIncludeAIPromptHeader = !g_shouldIncludeAIPromptHeader;
            NSString *status = g_shouldIncludeAIPromptHeader ? @"开启" : @"关闭";
            [sender setTitle:[NSString stringWithFormat:@"AI Prompt: %@", status] forState:UIControlStateNormal];
            sender.backgroundColor = g_shouldIncludeAIPromptHeader ? ECHO_COLOR_PROMPT_ON : ECHO_COLOR_SWITCH_OFF;
            LogMessage(EchoLogTypeInfo, @"[设置] Prompt 已 %@。", status); break;
        }
        case kButtonTag_BenMingToggle: {
            g_isSomeToggleOn = !g_isSomeToggleOn;
            NSString *status = g_isSomeToggleOn ? @"开启" : @"关闭";
            [sender setTitle:[NSString stringWithFormat:@"开关: %@", status] forState:UIControlStateNormal];
            sender.backgroundColor = g_isSomeToggleOn ? ECHO_COLOR_PROMPT_ON : ECHO_COLOR_SWITCH_OFF;
            LogMessage(EchoLogTypeInfo, @"[设置] 通用开关已 %@。", status); break;
        }
    }
}

%new
- (void)handleToolButtonTap:(UIButton *)sender {
    [self buttonTouchUp:sender];
    LogMessage(EchoLogTypeInfo, @"[提示] 工具按钮在此版本中未分配功能。");
    [self showEchoNotificationWithTitle:@"无操作" message:@"此按钮为框架占位符"];
}

%new
- (void)startStandardExtraction {
    if (g_isExtracting) return;
    LogMessage(EchoLogTypeTask, @"[奇门] v4.0 提取任务启动 (终极毕业版)...");
    g_isExtracting = YES;
    [self showProgressHUD:@"正在精准提取..."];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSMutableString *reportContent = [NSMutableString string];
        [reportContent appendString:@"// 奇门盘信息\n"];
        
        // --- 1. 提取顶部概览 ---
        @try {
            Class juShiViewClass = NSClassFromString(@"CZJuShiView");
            Class baziViewClass = NSClassFromString(@"CZShowBaZiView");
            if(juShiViewClass && baziViewClass) {
                NSMutableArray *juShiViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(juShiViewClass, self.view, juShiViews);
                UIView *juShiView = (juShiViews.count > 0) ? juShiViews.firstObject : nil;
                NSMutableArray *baziViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(baziViewClass, self.view, baziViews);
                UIView *baziView = (baziViews.count > 0) ? baziViews.firstObject : nil;
                if (juShiView && baziView) {
                    NSDate *dateUse = [juShiView valueForKey:@"dateUse"];
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init]; [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                    NSString *timeStr = [formatter stringFromDate:dateUse];
                    
                    Ivar baZiIvar = class_getInstanceVariable(baziViewClass, "_baZi");
                    id baZiModel = object_getIvar(baziView, baZiIvar);
                    NSString *nianZhu = [NSString stringWithFormat:@"%@%@", SafeString([baZiModel valueForKey:@"nianGan"]), SafeString([baZiModel valueForKey:@"nianZhi"])];
                    NSString *yueZhu = [NSString stringWithFormat:@"%@%@", SafeString([baZiModel valueForKey:@"yueGan"]), SafeString([baZiModel valueForKey:@"yueZhi"])];
                    NSString *riZhu = [NSString stringWithFormat:@"%@%@", SafeString([baZiModel valueForKey:@"riGan"]), SafeString([baZiModel valueForKey:@"riZhi"])];
                    NSString *shiZhu = [NSString stringWithFormat:@"%@%@", SafeString([baZiModel valueForKey:@"shiGan"]), SafeString([baZiModel valueForKey:@"shiZhi"])];
                    
                    Ivar juTouIvar = class_getInstanceVariable(baziViewClass, "_juTou");
                    id juTouModel = object_getIvar(baziView, juTouIvar);
                    NSString *xunStr = SafeString([juTouModel valueForKey:@"xunStr"]);

                    NSString *juStr = SafeString([[baziView valueForKey:@"labelJu"] text]);
                    NSString *YinYangStr = SafeString([[baziView valueForKey:@"labelYinYang"] text]);
                    NSString *zhiFu = SafeString([[baziView valueForKey:@"labelZhiFu"] text]);
                    NSString *zhiShi = SafeString([[baziView valueForKey:@"labelZhiShi"] text]);
                    
                    NSString *起局方式 = @"时家拆补"; 
NSMutableString *geJuStr = [NSMutableString string];
Class geJuViewClass = NSClassFromString(@"CZShowShiJianGeView"); // [修复] 使用正确的View类名
if(geJuViewClass) {
     NSMutableArray *geJuViews = [NSMutableArray array]; 
     FindSubviewsOfClassRecursive(geJuViewClass, self.view, geJuViews);
     for(UIView* view in geJuViews) {
        // 直接从这个View里找UILabel
        NSMutableArray *labels = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], view, labels);
        if (labels.count > 0) {
            // 假设每个View里只有一个Label显示格局名称
            [geJuStr appendFormat:@"%@ ", ((UILabel*)labels.firstObject).text];
        }
     }
}
                    [reportContent appendFormat:@"%@ | %@ | %@%@ | %@ | %@\n", timeStr, 起局方式, YinYangStr, juStr, [NSString stringWithFormat:@"%@旬", xunStr], [geJuStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                    [reportContent appendFormat:@"值符: %@ | 值使: %@\n", zhiFu, zhiShi];
[reportContent appendFormat:@"四柱: %@ %@ %@ %@\n", nianZhu, yueZhu, riZhu, shiZhu];                }
            }
        } @catch (NSException *exception) { [reportContent appendString:@"[顶部提取失败]\n"]; LogMessage(EchoLogError, @"[CRASH-DEBUG] 顶部提取失败: %@", exception); }
        
        // --- 2. 提取附加信息 (年命, 时空) ---
        @try {
            Class bottomContainerClass = NSClassFromString(@"CZShowNianMingRiShiKongView");
            if (bottomContainerClass) {
                NSMutableArray *containerViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(bottomContainerClass, self.view, containerViews);
                if (containerViews.count > 0) {
                    UIView *container = containerViews.firstObject;
                    UILabel *nianMingLabel = [container valueForKey:@"labelNianMing"];
                    UILabel *shiKongLabel = [container valueForKey:@"labelShiKong"];
                    if (nianMingLabel) [reportContent appendFormat:@"%@\n", SafeString(nianMingLabel.text)];
                    if (shiKongLabel) [reportContent appendFormat:@"%@\n", SafeString(shiKongLabel.text)];
                } else { [reportContent appendString:@"[附加信息提取失败: 未找到容器]\n"]; }
            } else { [reportContent appendString:@"[附加信息提取失败: 找不到类]\n"]; }
        } @catch (NSException *exception) { [reportContent appendString:@"[附加信息提取失败]\n"]; LogMessage(EchoLogError, @"[CRASH-DEBUG] 附加信息提取失败: %@", exception); }
        [reportContent appendString:@"\n"];

        // --- 3. 提取九宫格详情 ---
        Class cellClass = NSClassFromString(@"CZGongChuanRenThemeCollectionViewCell");
        if (!cellClass) {
            [reportContent appendString:@"[提取失败: 找不到九宫格Cell类]\n"];
        } else {
            NSMutableArray *allCells = [NSMutableArray array]; FindSubviewsOfClassRecursive(cellClass, self.view, allCells);
            if (allCells.count >= 9) {
                Ivar gongIvar = class_getInstanceVariable(cellClass, "_gong");
                if (gongIvar) {
                    NSMutableArray *gongItems = [NSMutableArray array];
                    for (UIView *cell in allCells) {
                        id model = object_getIvar(cell, gongIvar);
                        if (model) { [gongItems addObject:@{@"model": model, @"cell": cell}]; }
                    }
                    NSDictionary *sortOrder = @{@"坎":@1, @"坤":@2, @"震":@3, @"巽":@4, @"中":@5, @"乾":@6, @"兑":@7, @"艮":@8, @"离":@9};
                    [gongItems sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
                         NSString *gongName1 = [obj1[@"model"] valueForKey:@"gongHouTianNameStr"];
                         NSString *gongName2 = [obj2[@"model"] valueForKey:@"gongHouTianNameStr"];
                         if (!gongName1 || gongName1.length < 1 || !gongName2 || gongName2.length < 1) return NSOrderedSame;
                         NSNumber *order1 = sortOrder[[gongName1 substringToIndex:1]];
                         NSNumber *order2 = sortOrder[[gongName2 substringToIndex:1]];
                         return [order1 compare:order2 ? order2 : @(99)];
                    }];
                    for (NSDictionary *item in gongItems) {
                        @try {
                            id model = item[@"model"];
                            UIView *cell = item[@"cell"];
                            NSString *gongName = SafeString([model valueForKey:@"gongHouTianNameStr"]);
                            if ([gongName containsString:@"中5宫"]) { [reportContent appendString:@"{中宫||中|地盘己|}\n"]; continue; }
                            NSString *tianPanGan = SafeString([model valueForKey:@"tianPanGanStr"]);
                            NSString *diPanGan = SafeString([model valueForKey:@"diPanGanStr"]);
                            NSString *baShen = SafeString([model valueForKey:@"baShenStr"]);
                            NSString *jiuXing = SafeString([model valueForKey:@"jiuXingStr"]);
                            NSString *baMen = SafeString([model valueForKey:@"baMenStr"]);
                            BOOL isMaXing = [[model valueForKey:@"isMaXing"] boolValue];
                            BOOL isKongWang = [[model valueForKey:@"isKongWang"] boolValue];
                            NSString *yinGan = SafeString([model valueForKey:@"yinGanStr"]);
                            NSString *tianPanJiGan = SafeString([model valueForKey:@"tianPanJiGanStr"]);
                            NSString *diPanJiGan = SafeString([model valueForKey:@"diPanJiGanStr"]);
                            NSString *xingWangShuai = [SafeString([[cell valueForKey:@"labelXingWangShuai"] text]) stringByReplacingOccurrencesOfString:@"`" withString:@""];
                            NSString *menWangShuai = [SafeString([[cell valueForKey:@"labelMenWangShuai"] text]) stringByReplacingOccurrencesOfString:@"`" withString:@""];
                            NSString *tianPan12 = SafeString([[cell valueForKey:@"labelTianPanGan12ZhangSheng"] text]);
                            NSString *diPan12 = SafeString([[cell valueForKey:@"labelDiPanGan12ZhangSheng"] text]);
                            NSString *tianPanJiGan12 = SafeString([[cell valueForKey:@"labelTianPanJiGan12ZhangSheng"] text]);
                            NSString *diPanJiGan12 = SafeString([[cell valueForKey:@"labelDiPanJiGan12ZhangSheng"] text]);
                            NSString *gongGua = SafeString([[cell valueForKey:@"labelGongGuaShuNeiWaiPan"] text]);
                            NSString *gongWangShuai = @"";
                            NSArray *gongGuaParts = [gongGua componentsSeparatedByString:@" "];
                            if (gongGuaParts.count > 2) { gongWangShuai = gongGuaParts[2]; }
                            
                            NSMutableString *xingPart = [NSMutableString stringWithFormat:@"%@(落宫%@)", jiuXing, xingWangShuai];
                            NSMutableString *menPart = [NSMutableString stringWithFormat:@"%@(落宫%@)", baMen, menWangShuai];
                            
                            NSMutableString *tiandiPart = [NSMutableString string];
                            [tiandiPart appendFormat:@"天盘%@(%@)", tianPanGan, tianPan12];
                            if (tianPanJiGan.length > 0) [tiandiPart appendFormat:@" 寄天盘干%@(%@)", tianPanJiGan, tianPanJiGan12];
                            [tiandiPart appendString:@" | "];
                            [tiandiPart appendFormat:@"地盘%@(%@)", diPanGan, diPan12];
                            if (diPanJiGan.length > 0) [tiandiPart appendFormat:@" 寄地盘干%@(%@)", diPanJiGan, diPanJiGan12];

                            NSMutableString *otherPart = [NSMutableString string];
                            if(isKongWang) [otherPart appendString:@"时空 "];
                            if(yinGan.length > 0) [otherPart appendFormat:@"暗干%@ ", yinGan];
                            if(isMaXing) [otherPart appendString:@"马星"];
                            
                            [reportContent appendFormat:@"{%@(%@)|%@|%@|%@|%@|%@}\n",
                                gongName, gongWangShuai, xingPart, baShen, menPart, tiandiPart, [otherPart stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
                            ];
                        } @catch (NSException *exception) {
                            LogMessage(EchoLogError, @"[CRASH-DEBUG] 宫位提取失败: %@", exception);
                            continue;
                        }
                    }
                }
            }
        }
        
        g_lastGeneratedReport = formatFinalReport(reportContent);
        [self hideProgressHUD];
        [self showEchoNotificationWithTitle:@"提取完成" message:@"专家格式报告已生成"];
        [self presentAIActionSheetWithReport:g_lastGeneratedReport];
        LogMessage(EchoLogTypeSuccess, @"[奇门] v4.0 提取任务完成。");
        g_isExtracting = NO;
    });
}

%new
- (NSString *)findTextInViewWithClassName:(NSString *)className separator:(NSString *)separator {
    Class targetClass = NSClassFromString(className);
    if (!targetClass) return [NSString stringWithFormat:@"[错误: 找不到类 %@]", className];
    NSMutableArray *targetViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(targetClass, self.view, targetViews);
    if (targetViews.count == 0) return [NSString stringWithFormat:@"[提取失败: 未找到 %@ 视图]", className];
    UIView *container = targetViews.firstObject;
    NSMutableArray *labels = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], container, labels);
    [labels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
        if (roundf(l1.frame.origin.y) < roundf(l2.frame.origin.y)) return NSOrderedAscending;
        if (roundf(l1.frame.origin.y) > roundf(l2.frame.origin.y)) return NSOrderedDescending;
        return [@(l1.frame.origin.x) compare:@(l1.frame.origin.x)];
    }];
    NSMutableArray *textParts = [NSMutableArray array];
    for (UILabel *label in labels) {
        if (label.text.length > 0 && !label.isHidden) {
            [textParts addObject:label.text];
        }
    }
    return [textParts componentsJoinedByString:separator];
}

%new
- (void)textViewDidChange:(UITextView *)textView {
    BOOL hasText = textView.text.length > 0 && ![textView.text isEqualToString:@"选填：输入您想问的具体问题"];
    [UIView animateWithDuration:0.2 animations:^{ g_clearInputButton.alpha = hasText ? 1.0 : 0.0; }];
}
%new
- (void)textViewDidBeginEditing:(UITextView *)textView {
    if ([textView.text isEqualToString:@"选填：输入您想问的具体问题"]) {
        textView.text = @""; textView.textColor = [UIColor whiteColor];
    } [self textViewDidChange:textView];
}
%new
- (void)textViewDidEndEditing:(UITextView *)textView {
    if ([textView.text isEqualToString:@""]) {
        textView.text = @"选填：输入您想问的具体问题"; textView.textColor = [UIColor lightGrayColor];
    } [self textViewDidChange:textView];
}
%new
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ([text isEqualToString:@"\n"]) { [textView resignFirstResponder]; return NO; } return YES;
}
%new
- (void)buttonTouchDown:(UIButton *)sender { [UIView animateWithDuration:0.15 animations:^{ sender.transform = CGAffineTransformMakeScale(0.95, 0.95); sender.alpha = 0.8; }]; }
%new
- (void)buttonTouchUp:(UIButton *)sender { [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseInOut animations:^{ sender.transform = CGAffineTransformIdentity; sender.alpha = 1.0; } completion:nil]; }
%new
- (void)presentAIActionSheetWithReport:(NSString *)report {
    if (!report || report.length == 0) { LogMessage(EchoLogError, @"数据为空。"); return; }
    [UIPasteboard generalPasteboard].string = report;
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"发送数据至AI助手" message:@"数据已复制到剪贴板" preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *encodedReport = [report stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSArray *aiApps = @[ @{@"name": @"DeepSeek", @"scheme": @"deepseek://", @"format": @"deepseek://send?text=%@"}, @{@"name": @"ChatGPT", @"scheme": @"chatgpt://", @"format": @"chatgpt://"}, ];
    int availableApps = 0;
    for (NSDictionary *appInfo in aiApps) {
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:appInfo[@"scheme"]]]) {
            [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"发送到 %@", appInfo[@"name"]] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSString *urlString = [NSString stringWithFormat:appInfo[@"format"], encodedReport];
                if ([appInfo[@"name"] isEqualToString:@"ChatGPT"]) { urlString = appInfo[@"scheme"]; }
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString] options:@{} completionHandler:nil];
            }]];
            availableApps++;
        }
    }
    if (availableApps == 0) { actionSheet.message = @"未检测到AI App。\n数据已复制。"; }
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"仅复制" style:UIAlertActionStyleDefault handler:nil]];
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    if (actionSheet.popoverPresentationController) {
        actionSheet.popoverPresentationController.sourceView = self.view;
        actionSheet.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2.0, self.view.bounds.size.height, 1.0, 1.0);
    }
    [self presentViewController:actionSheet animated:YES completion:nil];
}
%new
- (void)showProgressHUD:(NSString *)text {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    if([keyWindow viewWithTag:kEchoProgressHUDTag]) [[keyWindow viewWithTag:kEchoProgressHUDTag] removeFromSuperview];
    UIView *progressView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 120)];
    progressView.center = keyWindow.center; progressView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    progressView.layer.cornerRadius = 10; progressView.tag = kEchoProgressHUDTag;
    UIActivityIndicatorView *spinner;
    if (@available(iOS 13.0, *)) { spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge]; spinner.color = [UIColor whiteColor]; } 
    else { _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"") spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge]; _Pragma("clang diagnostic pop") }
    spinner.center = CGPointMake(110, 50); [spinner startAnimating]; [progressView addSubview:spinner];
    UILabel *progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 85, 200, 30)];
    progressLabel.textColor = [UIColor whiteColor]; progressLabel.textAlignment = NSTextAlignmentCenter;
    progressLabel.font = [UIFont systemFontOfSize:14]; progressLabel.text = text; [progressView addSubview:progressLabel];
    [keyWindow addSubview:progressView];
}
%new
- (void)hideProgressHUD {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    UIView *progressView = [keyWindow viewWithTag:kEchoProgressHUDTag];
    if (progressView) {
        [UIView animateWithDuration:0.3 animations:^{ progressView.alpha = 0; } completion:^(BOOL finished) { [progressView removeFromSuperview]; }];
    }
}
%new
- (void)showEchoNotificationWithTitle:(NSString *)title message:(NSString *)message {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    CGFloat topPadding;
    if (@available(iOS 11.0, *)) { topPadding = keyWindow.safeAreaInsets.top; } else { topPadding = 20; };
    topPadding = topPadding > 0 ? topPadding : 20;
    CGFloat bannerWidth = keyWindow.bounds.size.width - 32;
    UIView *bannerView = [[UIView alloc] initWithFrame:CGRectMake(16, -100, bannerWidth, 60)];
    bannerView.layer.cornerRadius = 12; bannerView.clipsToBounds = YES;
    UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleProminent]];
    blurEffectView.frame = bannerView.bounds; [bannerView addSubview:blurEffectView];
    UIView *containerForLabels = blurEffectView.contentView;
    UILabel *iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 20, 20, 20)];
    iconLabel.text = @"✓"; iconLabel.textColor = [UIColor colorWithRed:0.2 green:0.78 blue:0.35 alpha:1.0];
    iconLabel.font = [UIFont boldSystemFontOfSize:16]; [containerForLabels addSubview:iconLabel];
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(45, 12, bannerWidth-55, 20)];
    titleLabel.text = title; titleLabel.font = [UIFont boldSystemFontOfSize:15];
    if (@available(iOS 13.0, *)) { titleLabel.textColor = [UIColor labelColor]; } else { titleLabel.textColor = [UIColor blackColor];}
    [containerForLabels addSubview:titleLabel];
    UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(45, 32, bannerWidth-55, 16)];
    messageLabel.text = message; messageLabel.font = [UIFont systemFontOfSize:13];
    if (@available(iOS 13.0, *)) { messageLabel.textColor = [UIColor secondaryLabelColor]; } else { messageLabel.textColor = [UIColor darkGrayColor]; }
    [containerForLabels addSubview:messageLabel];
    [keyWindow addSubview:bannerView];
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        bannerView.frame = CGRectMake(16, topPadding, bannerWidth, 60);
    } completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{ bannerView.alpha = 0; bannerView.transform = CGAffineTransformMakeScale(0.9, 0.9); } completion:^(BOOL finished) { [bannerView removeFromSuperview]; }];
    });
}
%end

%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[Echo奇门提取器] v4.0 (终极毕业版) 已加载。");
    }
}






