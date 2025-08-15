#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量、常量定义与辅助函数
// =========================================================================
#pragma mark - Constants & Colors
#define ECHO_COLOR_MAIN_BLUE    [UIColor colorWithRed:0.17 green:0.31 blue:0.51 alpha:1.0]
#define ECHO_COLOR_MAIN_TEAL    [UIColor colorWithRed:0.23 green:0.49 blue:0.49 alpha:1.0]
#define ECHO_COLOR_ACTION_CLOSE [UIColor colorWithWhite:0.25 alpha:1.0]
#define ECHO_COLOR_SUCCESS      [UIColor colorWithRed:0.4 green:1.0 blue:0.4 alpha:1.0]
#define ECHO_COLOR_LOG_TASK     [UIColor whiteColor]
#define ECHO_COLOR_LOG_INFO     [UIColor lightGrayColor]
#define ECHO_COLOR_LOG_WARN     [UIColor orangeColor]
#define ECHO_COLOR_LOG_ERROR    [UIColor redColor]

static const NSInteger kEchoControlButtonTag = 556699;
static const NSInteger kEchoMainPanelTag = 778899;
static const NSInteger kButtonTag_ExtractShenSha = 101;
static const NSInteger kButtonTag_ClosePanel = 998;

#pragma mark - Global State
static UIView *g_mainControlPanelView = nil;
static UITextView *g_logTextView = nil;

#pragma mark - Helper Functions
typedef NS_ENUM(NSInteger, EchoLogType) { EchoLogTypeInfo, EchoLogTypeTask, EchoLogTypeSuccess, EchoLogTypeWarning, EchoLogError };

static void LogMessage(EchoLogType type, NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
  
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSMutableAttributedString *logLine = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@\n", logPrefix, message]];
        UIColor *color;
        switch (type) {
            case EchoLogTypeTask:    color = ECHO_COLOR_LOG_TASK; break;
            case EchoLogTypeSuccess: color = ECHO_COLOR_SUCCESS; break;
            case EchoLogTypeWarning: color = ECHO_COLOR_LOG_WARN; break;
            case EchoLogError:       color = ECHO_COLOR_LOG_ERROR; break;
            case EchoLogTypeInfo:
            default:                 color = ECHO_COLOR_LOG_INFO; break;
        }
        [logLine addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, logLine.length)];
        [logLine addAttribute:NSFontAttributeName value:g_logTextView.font range:NSMakeRange(0, logLine.length)];
        NSMutableAttributedString *existingText = [[NSMutableAttributedString alloc] initWithAttributedString:g_logTextView.attributedText];
        [logLine appendAttributedString:existingText];
        g_logTextView.attributedText = logLine;
        NSLog(@"[EchoShenShaTest] %@", message);
    });
}

// 该函数已不再需要，故移除
// static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { ... }

static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        frontmostWindow = window;
                        break;
                    }
                }
                if (frontmostWindow) break;
            }
        }
    }
    if (!frontmostWindow) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        frontmostWindow = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
    }
    return frontmostWindow;
}

// =========================================================================
// 2. 接口声明与核心 Hook
// =========================================================================
@interface UIViewController (EchoShenShaTest)
- (void)createOrShowMainControlPanel;
- (void)handleMasterButtonTap:(UIButton *)sender;
- (void)presentAIActionSheetWithReport:(NSString *)report;
- (NSString *)extractShenShaInfo_TheRealFinalSolution;
@end

%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSMutableString *s = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)s, NULL, CFSTR("Hant-Hans"), false); %orig(s); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSMutableAttributedString *s = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)s.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(s); }
%end

%hook UIViewController
- (void)viewDidLoad { 
    %orig; 
    Class targetClass = NSClassFromString(@"六壬大占.ViewController"); 
    if (targetClass && [self isKindOfClass:targetClass]) { 
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ 
            UIWindow *keyWindow = GetFrontmostWindow(); 
            if (!keyWindow) return; 
            if ([keyWindow viewWithTag:kEchoControlButtonTag]) [[keyWindow viewWithTag:kEchoControlButtonTag] removeFromSuperview]; 
            UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem]; 
            controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36); 
            controlButton.tag = kEchoControlButtonTag; 
            [controlButton setTitle:@"Echo 神煞提取" forState:UIControlStateNormal]; 
            controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16]; 
            controlButton.backgroundColor = ECHO_COLOR_MAIN_BLUE; 
            [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; 
            controlButton.layer.cornerRadius = 18; 
            [controlButton addTarget:self action:@selector(createOrShowMainControlPanel) forControlEvents:UIControlEventTouchUpInside]; 
            [keyWindow addSubview:controlButton]; 
        }); 
    } 
}
%new 
- (void)createOrShowMainControlPanel { 
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return; 
    if (g_mainControlPanelView && g_mainControlPanelView.superview) { [g_mainControlPanelView removeFromSuperview]; g_mainControlPanelView = nil; g_logTextView = nil; return; } 
    g_mainControlPanelView = [[UIView alloc] initWithFrame:keyWindow.bounds]; g_mainControlPanelView.tag = kEchoMainPanelTag; 
    if (@available(iOS 8.0, *)) { UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]]; blurView.frame = g_mainControlPanelView.bounds; [g_mainControlPanelView addSubview:blurView]; } else { g_mainControlPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9]; } 
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(10, 60, g_mainControlPanelView.bounds.size.width - 20, g_mainControlPanelView.bounds.size.height - 80)]; [g_mainControlPanelView addSubview:contentView]; 
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, contentView.bounds.size.width, 30)]; titleLabel.text = @"Echo 神煞提取 (最终决战)"; titleLabel.font = [UIFont boldSystemFontOfSize:22]; titleLabel.textColor = [UIColor whiteColor]; titleLabel.textAlignment = NSTextAlignmentCenter; [contentView addSubview:titleLabel]; 
    UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeCustom]; [extractButton setTitle:@"提取全部神煞信息" forState:UIControlStateNormal]; extractButton.tag = kButtonTag_ExtractShenSha; extractButton.backgroundColor = ECHO_COLOR_MAIN_TEAL; [extractButton addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside]; extractButton.titleLabel.font = [UIFont boldSystemFontOfSize:18]; extractButton.layer.cornerRadius = 12; extractButton.frame = CGRectMake(15, 80, contentView.bounds.size.width - 30, 50); [contentView addSubview:extractButton]; 
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(0, 150, contentView.bounds.size.width, contentView.bounds.size.height - 210)]; g_logTextView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.7]; g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12]; g_logTextView.editable = NO; g_logTextView.layer.cornerRadius = 8; g_logTextView.textColor = [UIColor whiteColor]; g_logTextView.text = @"[EchoShenShaTest]: 就绪。\n"; [contentView addSubview:g_logTextView]; 
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom]; [closeButton setTitle:@"关闭面板" forState:UIControlStateNormal]; closeButton.tag = kButtonTag_ClosePanel; closeButton.backgroundColor = ECHO_COLOR_ACTION_CLOSE; [closeButton addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside]; closeButton.layer.cornerRadius = 10; closeButton.frame = CGRectMake(15, contentView.bounds.size.height - 50, contentView.bounds.size.width - 30, 40); [contentView addSubview:closeButton]; 
    g_mainControlPanelView.alpha = 0; [keyWindow addSubview:g_mainControlPanelView]; [UIView animateWithDuration:0.3 animations:^{ g_mainControlPanelView.alpha = 1.0; }]; 
}
%new 
- (void)handleMasterButtonTap:(UIButton *)sender { 
    switch (sender.tag) { 
        case kButtonTag_ExtractShenSha: { 
            LogMessage(EchoLogTypeTask, @"[任务] 开始从ViewController->神煞行年->列表提取..."); 
            NSString *shenShaResult = [self extractShenShaInfo_TheRealFinalSolution]; 
            if (shenShaResult && shenShaResult.length > 0) { NSString *finalReport = [NSString stringWithFormat:@"// 神煞详情 (所有分类)\n%@", shenShaResult]; [self presentAIActionSheetWithReport:finalReport]; } else { LogMessage(EchoLogTypeWarning, @"[结果] 神煞信息为空或提取失败。"); } 
            break; 
        } 
        case kButtonTag_ClosePanel: [self createOrShowMainControlPanel]; break; 
    } 
}
%new 
- (void)presentAIActionSheetWithReport:(NSString *)report { if (!report || report.length == 0) { LogMessage(EchoLogError, @"报告为空，无法执行后续操作。"); return; } [UIPasteboard generalPasteboard].string = report; UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"神煞提取结果" message:@"内容已复制到剪贴板" preferredStyle:UIAlertControllerStyleActionSheet]; UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"确认 (已复制)" style:UIAlertActionStyleDefault handler:nil]; [actionSheet addAction:copyAction]; UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]; [actionSheet addAction:cancelAction]; if (actionSheet.popoverPresentationController) { actionSheet.popoverPresentationController.sourceView = self.view; actionSheet.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height, 1.0, 1.0); } [self presentViewController:actionSheet animated:YES completion:nil]; }


// =========================================================================
// 3. 核心提取函数 (最终决战版 - 跨对象读取变量)
// =========================================================================
%new
- (NSString *)extractShenShaInfo_TheRealFinalSolution {
    // 1. 获取主 ViewController 实例
    Class viewControllerClass = NSClassFromString(@"六壬大占.ViewController");
    if (![self isKindOfClass:viewControllerClass]) {
        LogMessage(EchoLogError, @"[神煞] 错误: 当前上下文不是 '六壬大占.ViewController'。");
        return @"[提取失败: 上下文错误]";
    }

    // 2. 从 ViewController 中获取名为 "神煞行年" 的实例变量
    Ivar ivar_shenShaContainer = class_getInstanceVariable(viewControllerClass, "神煞行年");
     if (!ivar_shenShaContainer) {
        ivar_shenShaContainer = class_getInstanceVariable(viewControllerClass, "_神煞行年");
    }
    if (!ivar_shenShaContainer) {
        LogMessage(EchoLogError, @"[神煞] 致命错误: 在 ViewController 中找不到 '神煞行年' 成员变量。");
        return @"[提取失败: 找不到'神煞行年'容器]";
    }
    id shenShaContainerObject = object_getIvar(self, ivar_shenShaContainer);
    if (!shenShaContainerObject) {
        LogMessage(EchoLogError, @"[神煞] 错误: '神煞行年' 变量值为 nil。请确保神煞视图已加载。");
        return @"[提取失败: '神煞行年'为nil]";
    }

    // 3. 从 "神煞行年" 对象中获取名为 "列表" 的实例变量
    Class containerViewClass = [shenShaContainerObject class];
    Ivar ivar_list = class_getInstanceVariable(containerViewClass, "列表");
    if (!ivar_list) {
        ivar_list = class_getInstanceVariable(containerViewClass, "_列表");
    }
    if (!ivar_list) {
        LogMessage(EchoLogError, @"[神煞] 致命错误: 在 '%@' 中找不到 '列表' 成员变量。", NSStringFromClass(containerViewClass));
        return @"[提取失败: 找不到数据源'列表']";
    }
    
    id dataSourceList = object_getIvar(shenShaContainerObject, ivar_list);
    if (!dataSourceList || ![dataSourceList isKindOfClass:[NSArray class]]) {
        LogMessage(EchoLogError, @"[神煞] 错误: '列表'变量不是一个有效的数组，或当前值为nil。");
        return @"[提取失败: 数据源'列表'无效]";
    }
    
    NSArray *categories = (NSArray *)dataSourceList;
    LogMessage(EchoLogTypeInfo, @"[神煞] 成功从 VC->神煞行年->列表 获取数据源，共 %lu 个分类。", (unsigned long)categories.count);

    // 4. 遍历数据源并解析
    NSMutableString *finalResultString = [NSMutableString string];
    for (id categoryObject in categories) {
        if (![categoryObject isKindOfClass:[NSObject class]]) continue;
        
        NSString *categoryTitle = [categoryObject valueForKey:@"标题"];
        NSArray *items = [categoryObject valueForKey:@"列表"];
        
        if (!categoryTitle || !items) {
            LogMessage(EchoLogTypeWarning, @"[神煞] 警告: 无法从分类对象中获取'标题'或'列表'属性。");
            continue;
        }

        [finalResultString appendFormat:@"\n// %@\n", categoryTitle];

        NSMutableString *categoryContent = [NSMutableString string];
        for (NSUInteger j = 0; j < items.count; j++) {
            id itemObject = items[j];
            if (![itemObject isKindOfClass:[NSObject class]]) continue;
            
            NSString *nameText = [itemObject valueForKey:@"名"];
            NSString *weiText = [itemObject valueForKey:@"位"];

            if (!nameText) nameText = @"?";
            if (!weiText) weiText = @"";

            if (j > 0) { [categoryContent appendString:@" |"]; }
            
            if (weiText.length > 0) {
                [categoryContent appendFormat:@" %@(%@)", nameText, weiText];
            } else {
                [categoryContent appendFormat:@" %@", nameText];
            }
        }
        [finalResultString appendString:[categoryContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
        [finalResultString appendString:@"\n"];
    }
    
    LogMessage(EchoLogTypeSuccess, @"[神煞] 所有分类通过数据源'列表'变量完整提取成功！");
    return [finalResultString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
%end

%ctor {
    NSLog(@"[EchoShenShaTest v_real_final_fixed] 最终决战版脚本已加载。");
}
