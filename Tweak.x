#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量、常量定义与辅助函数
// =========================================================================
#pragma mark - Constants & Colors
static const NSInteger kEchoControlButtonTag    = 556699;
static const NSInteger kEchoMainPanelTag        = 778899;
#define ECHO_COLOR_MAIN_BLUE        [UIColor colorWithRed:0.17 green:0.31 blue:0.51 alpha:1.0]
#define ECHO_COLOR_MAIN_TEAL        [UIColor colorWithRed:0.23 green:0.49 blue:0.49 alpha:1.0]
#define ECHO_COLOR_LOG_INFO         [UIColor lightGrayColor]
#define ECHO_COLOR_LOG_ERROR        [UIColor redColor]
#define ECHO_COLOR_LOG_SUCCESS      [UIColor colorWithRed:0.4 green:1.0 blue:0.4 alpha:1.0]
#define ECHO_COLOR_LOG_DEBUG        [UIColor orangeColor]
#define ECHO_COLOR_CARD_BG          [UIColor colorWithWhite:0.2 alpha:1.0]

#pragma mark - Global State & Flags
static UIView *g_mainControlPanelView = nil;
static UITextView *g_logTextView = nil;
static BOOL g_isExtractingTianDiPanDetail = NO;
static NSMutableArray *g_tianDiPan_workQueue = nil;
static NSMutableArray<NSString *> *g_tianDiPan_resultsArray = nil;
static void (^g_tianDiPan_completion_handler)(NSString *result) = nil;

#pragma mark - Coordinate Database (V2.1 - 精准微调版)
static NSArray *g_tianDiPan_fixedCoordinates = nil;

static void initializeTianDiPanCoordinates() {
    if (g_tianDiPan_fixedCoordinates) return;
    g_tianDiPan_fixedCoordinates = @[
        @{@"name": @"天将-午位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(180.38, 108.57)]},
        @{@"name": @"天将-巳位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(144.48, 118.19)]},
        @{@"name": @"天将-辰位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(118.19, 144.48)]},
        @{@"name": @"天将-卯位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(108.57, 180.39)]},
        @{@"name": @"天将-寅位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(118.19, 216.29)]},
        @{@"name": @"天将-丑位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(144.48, 242.58)]},
        @{@"name": @"天将-子位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(180.38, 252.20)]},
        @{@"name": @"天将-亥位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(216.29, 242.58)]},
        @{@"name": @"天将-戌位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(242.58, 216.29)]},
        @{@"name": @"天将-酉位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(252.20, 180.38)]},
        @{@"name": @"天将-申位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(242.58, 144.48)]},
        @{@"name": @"天将-未位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(216.29, 118.19)]},
        @{@"name": @"上神-午位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(180.38, 134.00)]},
        @{@"name": @"上神-巳位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(154.00, 145.00)]},
        @{@"name": @"上神-辰位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(142.00, 168.00)]},
        @{@"name": @"上神-卯位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(134.00, 180.39)]},
        @{@"name": @"上神-寅位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(142.00, 200.00)]},
        @{@"name": @"上神-丑位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(154.00, 220.00)]},
        @{@"name": @"上神-子位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(180.38, 226.00)]},
        @{@"name": @"上神-亥位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(208.00, 220.00)]},
        @{@"name": @"上神-戌位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(220.00, 200.00)]},
        @{@"name": @"上神-酉位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(226.00, 180.39)]},
        @{@"name": @"上神-申位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(220.00, 168.00)]},
        @{@"name": @"上神-未位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(208.00, 145.00)]},
    ];
}


#pragma mark - Helpers
typedef NS_ENUM(NSInteger, EchoLogType) { EchoLogTypeInfo, EchoLogTypeSuccess, EchoLogError, EchoLogTypeDebug };
static void LogMessage(EchoLogType type, NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    // Also print to system log for crash analysis
    NSLog(@"[Echo-Debug] %@", message);

    if (!g_logTextView) return;
  
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSMutableAttributedString *logLine = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@\n", logPrefix, message]];
        UIColor *color;
        switch (type) {
            case EchoLogTypeSuccess: color = ECHO_COLOR_SUCCESS; break;
            case EchoLogError:       color = ECHO_COLOR_LOG_ERROR; break;
            case EchoLogTypeDebug:   color = ECHO_COLOR_LOG_DEBUG; break;
            case EchoLogTypeInfo:
            default:                 color = ECHO_COLOR_LOG_INFO; break;
        }
        [logLine addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, logLine.length)];
        if (g_logTextView.font) {
            [logLine addAttribute:NSFontAttributeName value:g_logTextView.font range:NSMakeRange(0, logLine.length)];
        }
        NSMutableAttributedString *existingText = [[NSMutableAttributedString alloc] initWithAttributedString:g_logTextView.attributedText];
        [logLine appendAttributedString:existingText];
        g_logTextView.attributedText = logLine;
    });
}
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if (!view || !storage) return; if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }
static UIWindow* GetFrontmostWindow() { UIWindow *frontmostWindow = nil; if (@available(iOS 13.0, *)) { for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) { if (scene.activationState == UISceneActivationStateForegroundActive) { for (UIWindow *window in scene.windows) { if (window.isKeyWindow) { frontmostWindow = window; break; } } if (frontmostWindow) break; } } } if (!frontmostWindow) { \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"") \
    frontmostWindow = [UIApplication sharedApplication].keyWindow; \
    _Pragma("clang diagnostic pop") \
    } return frontmostWindow; }
static NSString* extractDataFromStackViewPopup(UIView *contentView) { return @"DEBUG MODE: Data extraction skipped."; }

// =========================================================================
// 2. 接口声明与核心Hook
// =========================================================================
@interface UIViewController (EchoTDP)
- (void)createOrShowTDPPanel;
- (void)startExtraction_TianDiPan_WithCompletion:(void (^)(NSString *result))completion;
- (void)processTianDiPanQueue;
@end

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    if (g_isExtractingTianDiPanDetail) {
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
        LogMessage(EchoLogTypeDebug, @"[HOOK] Intercepted presentViewController: %@", vcClassName);
        if ([vcClassName isEqualToString:@"六壬大占.天將摘要視圖"] || 
            [vcClassName isEqualToString:@"六壬大占.天地盤宮位摘要視圖"]) {
            
            LogMessage(EchoLogTypeDebug, @"[HOOK] Matched target VC. Making it invisible.");
            vcToPresent.view.alpha = 0.0f;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                LogMessage(EchoLogTypeDebug, @"[HOOK] Extracting data from invisible VC...");
                NSString *extractedText = extractDataFromStackViewPopup(vcToPresent.view);
                [g_tianDiPan_resultsArray addObject:extractedText];
                
                LogMessage(EchoLogTypeDebug, @"[HOOK] Dismissing invisible VC...");
                [vcToPresent dismissViewControllerAnimated:NO completion:^{
                    LogMessage(EchoLogTypeDebug, @"[HOOK] Dismiss complete. Processing next in queue.");
                    [self processTianDiPanQueue];
                }];
            });

            Original_presentViewController(self, _cmd, vcToPresent, NO, completion);
            LogMessage(EchoLogTypeDebug, @"[HOOK] Original presentViewController called for invisible VC.");
            return; 
        }
    }
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

%hook UIViewController

- (void)viewDidLoad { %orig; Class c=NSClassFromString(@"六壬大占.ViewController"); if(c&&[self isKindOfClass:c]){ dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ UIWindow *w=GetFrontmostWindow();if(!w||[w viewWithTag:kEchoControlButtonTag])return; UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];b.frame=CGRectMake(w.bounds.size.width-150,45,140,36);b.tag=kEchoControlButtonTag;[b setTitle:@"推衍课盘" forState:UIControlStateNormal];b.backgroundColor=ECHO_COLOR_MAIN_BLUE;[b setTitleColor:[UIColor whiteColor]forState:UIControlStateNormal];b.layer.cornerRadius=18;[b addTarget:self action:@selector(createOrShowTDPPanel)forControlEvents:UIControlEventTouchUpInside];[w addSubview:b];});}}

%new
- (void)createOrShowTDPPanel {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    if (g_mainControlPanelView) { [g_mainControlPanelView removeFromSuperview]; g_mainControlPanelView = nil; g_logTextView = nil; return; }
    g_mainControlPanelView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    g_mainControlPanelView.tag = kEchoMainPanelTag;
    g_mainControlPanelView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    [keyWindow addSubview:g_mainControlPanelView];
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, keyWindow.bounds.size.width - 40, 500)];
    contentView.center = g_mainControlPanelView.center;
    contentView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    contentView.layer.cornerRadius = 20;
    [g_mainControlPanelView addSubview:contentView];
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    startButton.frame = CGRectMake(20, 20, contentView.bounds.size.width - 40, 50);
    [startButton setTitle:@"推衍天地盘详情 (Debug Mode)" forState:UIControlStateNormal];
    startButton.backgroundColor = [UIColor orangeColor];
    [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    startButton.layer.cornerRadius = 10;
    [startButton addTarget:self action:@selector(startExtraction_TianDiPan_WithCompletion:) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:startButton];
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 80, contentView.bounds.size.width - 40, contentView.bounds.size.height - 100)];
    g_logTextView.backgroundColor = ECHO_COLOR_CARD_BG;
    g_logTextView.layer.cornerRadius = 12;
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO;
    g_logTextView.text = @"[DEBUG MODE] Ready. Awaiting command...\n";
    [contentView addSubview:g_logTextView];
}

%new
- (void)startExtraction_TianDiPan_WithCompletion:(void (^)(NSString *))completion {
    LogMessage(EchoLogTypeDebug, @"[START] Extraction process initiated.");
    if (g_isExtractingTianDiPanDetail) {
        LogMessage(EchoLogError, @"[START] Error: Extraction already in progress.");
        return;
    }
    g_isExtractingTianDiPanDetail = YES;
    g_tianDiPan_completion_handler = [completion copy];
    g_tianDiPan_workQueue = [g_tianDiPan_fixedCoordinates mutableCopy];
    g_tianDiPan_resultsArray = [NSMutableArray array];
    LogMessage(EchoLogTypeDebug, @"[START] Work queue created with %lu items.", (unsigned long)g_tianDiPan_workQueue.count);
    [self processTianDiPanQueue];
}

%new
- (void)processTianDiPanQueue {
    if (![NSThread isMainThread]) {
        LogMessage(EchoLogError, @"CRITICAL ERROR: processTianDiPanQueue called on a background thread! Aborting.");
        return;
    }
    
    LogMessage(EchoLogTypeInfo, @"[QUEUE] Entering processTianDiPanQueue...");
    if (g_tianDiPan_workQueue.count == 0) {
        LogMessage(EchoLogTypeSuccess, @"[QUEUE] All tasks complete. Finalizing...");
        g_isExtractingTianDiPanDetail = NO;
        // Final report generation is skipped in debug mode.
        return;
    }

    NSDictionary *task = g_tianDiPan_workQueue.firstObject;
    [g_tianDiPan_workQueue removeObjectAtIndex:0];
    
    NSString *name = task[@"name"];
    CGPoint point = [task[@"point"] CGPointValue];
    LogMessage(EchoLogTypeInfo, @"[QUEUE] Processing task: %@ at (%.0f, %.0f)", name, point.x, point.y);

    LogMessage(EchoLogTypeDebug, @"[Step 1] Finding plate view...");
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖");
    NSMutableArray *plateViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);
    if (plateViews.count == 0) { LogMessage(EchoLogError,@"Step 1 FAILED: Cannot find 天地盤視圖 instance."); [self processTianDiPanQueue]; return; }
    UIView *plateView = plateViews.firstObject;
    LogMessage(EchoLogTypeDebug, @"[Step 1] SUCCESS: Found plate view at <%p>", plateView);

    LogMessage(EchoLogTypeDebug, @"[Step 2] Finding tap gesture recognizer...");
    UITapGestureRecognizer *singleTapGesture = nil;
    for (UIGestureRecognizer *gesture in plateView.gestureRecognizers) {
        if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
            singleTapGesture = (UITapGestureRecognizer *)gesture;
            break;
        }
    }
    if (!singleTapGesture) { LogMessage(EchoLogError,@"Step 2 FAILED: Cannot find tap gesture."); [self processTianDiPanQueue]; return; }
    LogMessage(EchoLogTypeDebug, @"[Step 2] SUCCESS: Found tap gesture at <%p>", singleTapGesture);
    
    LogMessage(EchoLogTypeDebug, @"[Step 3] Injecting coordinate into gesture...");
    @try {
        [singleTapGesture setValue:[NSValue valueWithCGPoint:point] forKey:@"_locationInView"];
    } @catch (NSException *exception) {
        LogMessage(EchoLogError, @"Step 3 FAILED: setValue:forKey: crashed: %@", exception.reason);
        [self processTianDiPanQueue];
        return;
    }
    LogMessage(EchoLogTypeDebug, @"[Step 3] SUCCESS: Injected (%.0f, %.0f).", point.x, point.y);

    id target = self;
    SEL action = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
    LogMessage(EchoLogTypeDebug, @"[Step 4] Identifying target and action...");
    LogMessage(EchoLogTypeDebug, @"[Step 4] Target is 'self' at <%p>", target);
    LogMessage(EchoLogTypeDebug, @"[Step 4] Action is '%@'", NSStringFromSelector(action));

    LogMessage(EchoLogTypeDebug, @"[Step 5] Checking if target responds to action...");
    if ([target respondsToSelector:action]) {
        LogMessage(EchoLogTypeDebug, @"[Step 5] SUCCESS: Target responds.");
        
        LogMessage(EchoLogTypeDebug, @"[Step 6] DANGER ZONE: About to performSelector. If crash occurs, it's this next line.");
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [target performSelector:action withObject:singleTapGesture];
        #pragma clang diagnostic pop
        LogMessage(EchoLogTypeDebug, @"[Step 6] SURVIVED: performSelector did not crash immediately.");

    } else {
        LogMessage(EchoLogError, @"Step 5 FAILED: Target does NOT respond to selector.");
        [self processTianDiPanQueue];
    }
}

%end

%ctor {
    @autoreleasepool {
        initializeTianDiPanCoordinates();
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[Echo-Debug] Tweak (Full Debug Mode) Loaded.");
    }
}
