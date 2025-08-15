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
static const NSInteger kButtonTag_Investigate = 101;
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
        NSLog(@"[EchoMethodScout] %@", message);
    });
}

static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) { frontmostWindow = window; break; }
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
@interface UIViewController (EchoMethodScout)
- (void)createOrShowMainControlPanel;
- (void)handleMasterButtonTap:(UIButton *)sender;
- (void)investigateViewControllerMethods;
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
            UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return; 
            if ([keyWindow viewWithTag:kEchoControlButtonTag]) [[keyWindow viewWithTag:kEchoControlButtonTag] removeFromSuperview]; 
            UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem]; 
            controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36); 
            controlButton.tag = kEchoControlButtonTag; 
            [controlButton setTitle:@"Echo 方法侦察" forState:UIControlStateNormal]; 
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
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, contentView.bounds.size.width, 30)]; titleLabel.text = @"Echo 方法侦察兵"; titleLabel.font = [UIFont boldSystemFontOfSize:22]; titleLabel.textColor = [UIColor whiteColor]; titleLabel.textAlignment = NSTextAlignmentCenter; [contentView addSubview:titleLabel]; 
    UIButton *investigateButton = [UIButton buttonWithType:UIButtonTypeCustom]; [investigateButton setTitle:@"侦察 ViewController 方法" forState:UIControlStateNormal]; investigateButton.tag = kButtonTag_Investigate; investigateButton.backgroundColor = ECHO_COLOR_MAIN_TEAL; [investigateButton addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside]; investigateButton.titleLabel.font = [UIFont boldSystemFontOfSize:18]; investigateButton.layer.cornerRadius = 12; investigateButton.frame = CGRectMake(15, 80, contentView.bounds.size.width - 30, 50); [contentView addSubview:investigateButton]; 
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(0, 150, contentView.bounds.size.width, contentView.bounds.size.height - 210)]; g_logTextView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.7]; g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12]; g_logTextView.editable = NO; g_logTextView.layer.cornerRadius = 8; g_logTextView.textColor = [UIColor whiteColor]; g_logTextView.text = @"[EchoMethodScout]: 就绪。请点击按钮开始侦察。\n"; [contentView addSubview:g_logTextView]; 
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom]; [closeButton setTitle:@"关闭面板" forState:UIControlStateNormal]; closeButton.tag = kButtonTag_ClosePanel; closeButton.backgroundColor = ECHO_COLOR_ACTION_CLOSE; [closeButton addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside]; closeButton.layer.cornerRadius = 10; closeButton.frame = CGRectMake(15, contentView.bounds.size.height - 50, contentView.bounds.size.width - 30, 40); [contentView addSubview:closeButton]; 
    g_mainControlPanelView.alpha = 0; [keyWindow addSubview:g_mainControlPanelView]; [UIView animateWithDuration:0.3 animations:^{ g_mainControlPanelView.alpha = 1.0; }]; 
}
%new 
- (void)handleMasterButtonTap:(UIButton *)sender { 
    switch (sender.tag) { 
        case kButtonTag_Investigate: { 
            [self investigateViewControllerMethods]; 
            break; 
        } 
        case kButtonTag_ClosePanel: 
            [self createOrShowMainControlPanel]; 
            break; 
    } 
}

// =========================================================================
// 3. 核心侦察函数
// =========================================================================
%new
- (void)investigateViewControllerMethods {
    LogMessage(EchoLogTypeTask, @"开始侦察 '六壬大占.ViewController' 的方法...");
    Class vcClass = NSClassFromString(@"六壬大占.ViewController");
    if (![self isKindOfClass:vcClass]) {
        LogMessage(EchoLogError, @"错误: 当前上下文不是 '六壬大占.ViewController'。");
        return;
    }

    unsigned int methodCount;
    Method *methods = class_copyMethodList(vcClass, &methodCount);
    if (!methods) {
        LogMessage(EchoLogError, @"错误: 无法获取方法列表。");
        return;
    }

    LogMessage(EchoLogTypeInfo, @"发现 %d 个方法，开始筛选返回数组且无参数的方法...", methodCount);

    BOOL foundPotentialData = NO;
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        const char *name = sel_getName(selector);
        NSString *methodName = [NSString stringWithUTF8String:name];
        
        // 我们只关心无参数的方法
        if ([methodName containsString:@":"]) continue;

        struct objc_method_description *desc = method_getDescription(method);
        if (desc && desc->types) {
            // 返回值类型是 '@'，代表对象
            if (desc->types[0] == '@') {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                id returnValue = [self performSelector:selector];
                #pragma clang diagnostic pop

                // 如果返回值是数组，就打印出来
                if (returnValue && [returnValue isKindOfClass:[NSArray class]]) {
                    NSArray *arrayValue = (NSArray *)returnValue;
                     // 过滤掉空数组
                    if (arrayValue.count > 0) {
                        LogMessage(EchoLogTypeTask, @"发现方法 '%@' 返回数组 (共 %lu 项)，内容如下:", methodName, (unsigned long)arrayValue.count);
                        LogMessage(EchoLogTypeInfo, @"%@", arrayValue);
                        foundPotentialData = YES;
                    }
                }
            }
        }
    }

    free(methods);

    if (!foundPotentialData) {
        LogMessage(EchoLogTypeWarning, @"侦察完毕，未发现任何返回非空数组的可疑方法。");
    } else {
        LogMessage(EchoLogTypeSuccess, @"侦察完毕！请检查以上日志，寻找包含神煞数据的数组。");
    }
}
%end

%ctor {
    NSLog(@"[EchoMethodScout] 方法侦察脚本已加载。");
}
