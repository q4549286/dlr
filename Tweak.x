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
#define ECHO_COLOR_SUCCESS          [UIColor colorWithRed:0.4 green:1.0 blue:0.4 alpha:1.0]
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
    va_list args; va_start(args, format); NSString *message = [[NSString alloc] initWithFormat:format arguments:args]; va_end(args);
    NSLog(@"[Echo-Final-Debug] %@", message);
    if (!g_logTextView) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init]; [formatter setDateFormat:@"HH:mm:ss"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSMutableAttributedString *logLine = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@\n", logPrefix, message]];
        UIColor *color;
        switch (type) {
            case EchoLogTypeSuccess: color = ECHO_COLOR_SUCCESS; break; case EchoLogError: color = ECHO_COLOR_LOG_ERROR; break;
            case EchoLogTypeDebug: color = ECHO_COLOR_LOG_DEBUG; break; case EchoLogTypeInfo: default: color = ECHO_COLOR_LOG_INFO; break;
        }
        [logLine addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, logLine.length)];
        if (g_logTextView.font) { [logLine addAttribute:NSFontAttributeName value:g_logTextView.font range:NSMakeRange(0, logLine.length)]; }
        NSMutableAttributedString *existingText = [[NSMutableAttributedString alloc] initWithAttributedString:g_logTextView.attributedText];
        [logLine appendAttributedString:existingText]; g_logTextView.attributedText = logLine;
    });
}
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if (!view || !storage) return; if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }
static UIWindow* GetFrontmostWindow() { UIWindow *frontmostWindow = nil; if (@available(iOS 13.0, *)) { for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) { if (scene.activationState == UISceneActivationStateForegroundActive) { for (UIWindow *window in scene.windows) { if (window.isKeyWindow) { frontmostWindow = window; break; } } if (frontmostWindow) break; } } } if (!frontmostWindow) { \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"") \
    frontmostWindow = [UIApplication sharedApplication].keyWindow; \
    _Pragma("clang diagnostic pop") \
    } return frontmostWindow; }
static NSString* extractDataFromStackViewPopup(UIView *contentView) {
    NSMutableArray<NSString *> *finalTextParts = [NSMutableArray array];
    NSMutableArray *allStackViews = [NSMutableArray array]; FindSubviewsOfClassRecursive([UIStackView class], contentView, allStackViews);
    if (allStackViews.count > 0) {
        UIStackView *mainStackView = allStackViews.firstObject;
        for (UIView *subview in mainStackView.arrangedSubviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                NSString *text = ((UILabel *)subview).text; if (text && text.length > 0) [finalTextParts addObject:text];
            } else if ([subview isKindOfClass:NSClassFromString(@"六壬大占.IntrinsicTableView")]) {
                UITableView *tableView = (UITableView *)subview; id<UITableViewDataSource> dataSource = tableView.dataSource;
                if (dataSource) {
                    NSInteger rows = [dataSource tableView:tableView numberOfRowsInSection:0];
                    for (NSInteger row = 0; row < rows; row++) {
                        UITableViewCell *cell = [dataSource tableView:tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
                        if(cell) {
                            NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labels);
                            NSMutableArray<NSString *> *cellTexts = [NSMutableArray array]; for(UILabel *l in labels) { if(l.text.length > 0) [cellTexts addObject:l.text]; }
                            if(cellTexts.count > 0) [finalTextParts addObject:[cellTexts componentsJoinedByString:@" "]];
                        }
                    }
                }
            }
        }
    } else { return @"[提取失败: 未找到StackView]"; }
    return [finalTextParts componentsJoinedByString:@"\n"];
}

// =========================================================================
// 2. 接口声明与核心Hook
// =========================================================================
@interface UIViewController (EchoTDP)
- (void)createOrShowTDPPanel;
- (void)handleTDPExtractionButtonTap:(UIButton *)sender;
- (void)startTDPExtractionWithCompletion:(void (^)(NSString *result))completion;
- (void)processTianDiPanQueue;
- (void)presentAIActionSheetWithReport:(NSString *)report;
@end

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    if (g_isExtractingTianDiPanDetail) {
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
        if ([vcClassName isEqualToString:@"六壬大占.天將摘要視圖"] || [vcClassName isEqualToString:@"六壬大占.天地盤宮位摘要視圖"]) {
            vcToPresent.view.alpha = 0.0f;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *extractedText = extractDataFromStackViewPopup(vcToPresent.view);
                [g_tianDiPan_resultsArray addObject:extractedText];
                [vcToPresent dismissViewControllerAnimated:NO completion:^{ [self processTianDiPanQueue]; }];
            });
            Original_presentViewController(self, _cmd, vcToPresent, NO, completion);
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
    g_mainControlPanelView = [[UIView alloc] initWithFrame:keyWindow.bounds]; g_mainControlPanelView.tag = kEchoMainPanelTag; g_mainControlPanelView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7]; [keyWindow addSubview:g_mainControlPanelView];
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, keyWindow.bounds.size.width - 40, 500)]; contentView.center = g_mainControlPanelView.center; contentView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0]; contentView.layer.cornerRadius = 20; [g_mainControlPanelView addSubview:contentView];
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem]; startButton.frame = CGRectMake(20, 20, contentView.bounds.size.width - 40, 50); [startButton setTitle:@"推衍天地盘详情" forState:UIControlStateNormal]; startButton.backgroundColor = ECHO_COLOR_MAIN_TEAL; [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; startButton.layer.cornerRadius = 10; [startButton addTarget:self action:@selector(handleTDPExtractionButtonTap:) forControlEvents:UIControlEventTouchUpInside]; [contentView addSubview:startButton];
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 80, contentView.bounds.size.width - 40, contentView.bounds.size.height - 100)]; g_logTextView.backgroundColor = ECHO_COLOR_CARD_BG; g_logTextView.layer.cornerRadius = 12; g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12]; g_logTextView.editable = NO; g_logTextView.text = @"[就绪] 等待指令...\n"; [contentView addSubview:g_logTextView];
}

%new
- (void)handleTDPExtractionButtonTap:(UIButton *)sender { [self startTDPExtractionWithCompletion:nil]; }

%new
- (void)startTDPExtractionWithCompletion:(void (^)(NSString *))completion {
    if (g_isExtractingTianDiPanDetail) { LogMessage(EchoLogError, @"错误: 提取任务已在进行中。"); return; }
    LogMessage(EchoLogTypeInfo, @"任务启动: 推衍天地盘详情...");
    g_isExtractingTianDiPanDetail = YES; g_tianDiPan_completion_handler = [completion copy]; g_tianDiPan_workQueue = [g_tianDiPan_fixedCoordinates mutableCopy]; g_tianDiPan_resultsArray = [NSMutableArray array];
    if (!g_tianDiPan_workQueue || g_tianDiPan_workQueue.count == 0) { LogMessage(EchoLogError, @"错误: 坐标数据库为空或加载失败。"); g_isExtractingTianDiPanDetail = NO; return; }
    [self processTianDiPanQueue];
}

%new
- (void)processTianDiPanQueue {
    if (g_tianDiPan_workQueue.count == 0) {
        LogMessage(EchoLogTypeSuccess, @"完成: 所有天地盘详情提取完毕。");
        NSMutableString *finalReport = [NSMutableString string];
        [finalReport appendString:@"// 天地盘详情 (完整版)\n\n"];
        for (NSUInteger i = 0; i < g_tianDiPan_fixedCoordinates.count; i++) {
            NSDictionary *itemInfo = g_tianDiPan_fixedCoordinates[i]; NSString *itemName = itemInfo[@"name"];
            NSString *itemType = [itemInfo[@"type"] isEqualToString:@"tianJiang"] ? @"天将详情" : @"上神详情";
            NSString *itemData = (i < g_tianDiPan_resultsArray.count) ? g_tianDiPan_resultsArray[i] : @"[数据提取失败]";
            NSMutableString *simplifiedData = [itemData mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedData, NULL, CFSTR("Hant-Hans"), false);
            [finalReport appendFormat:@"-- [%@: %@] --\n%@\n\n", itemType, itemName, simplifiedData];
        }
        if (g_tianDiPan_completion_handler) { g_tianDiPan_completion_handler([finalReport copy]); } 
        else { [self presentAIActionSheetWithReport:[finalReport copy]]; }
        g_isExtractingTianDiPanDetail = NO; g_tianDiPan_workQueue = nil; g_tianDiPan_resultsArray = nil; g_tianDiPan_completion_handler = nil;
        return;
    }

    NSDictionary *task = g_tianDiPan_workQueue.firstObject; [g_tianDiPan_workQueue removeObjectAtIndex:0];
    NSString *name = task[@"name"]; CGPoint point = [task[@"point"] CGPointValue];
    LogMessage(EchoLogTypeInfo, @"正在处理: %@ (%.0f, %.0f)", name, point.x, point.y);

    // ====================== 核心修复点 1 ======================
    NSString *plateViewClassName = @"六壬大占.天地盤視圖類";
    // =======================================================
    Class plateViewClass = NSClassFromString(plateViewClassName);
    if (!plateViewClass) { LogMessage(EchoLogError,@"关键错误: 找不到类 %@", plateViewClassName); [self processTianDiPanQueue]; return; }
    
    NSMutableArray *plateViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);
    if (plateViews.count == 0) { LogMessage(EchoLogError,@"关键错误: 找不到 %@ 的实例", plateViewClassName); [self processTianDiPanQueue]; return; }
    UIView *plateView = plateViews.firstObject;
    LogMessage(EchoLogTypeDebug, @"视图已找到: <%p>", plateView);
    
    UITapGestureRecognizer *singleTapGesture = nil;
    for (UIGestureRecognizer *gesture in plateView.gestureRecognizers) {
        if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) { singleTapGesture = (UITapGestureRecognizer *)gesture; break; }
    }
    if (!singleTapGesture) { LogMessage(EchoLogError,@"关键错误: 找不到单击手势"); [self processTianDiPanQueue]; return; }
    LogMessage(EchoLogTypeDebug, @"手势已找到: <%p>", singleTapGesture);
    
    @try {
        [singleTapGesture setValue:[NSValue valueWithCGPoint:point] forKey:@"_locationInView"];
        LogMessage(EchoLogTypeDebug, @"坐标已注入");
    } @catch (NSException *exception) {
        LogMessage(EchoLogError, @"坐标注入失败: %@", exception.reason); [self processTianDiPanQueue]; return;
    }

    id target = self;
    SEL action = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
    LogMessage(EchoLogTypeDebug, @"准备触发: Target=<%p>, Action=%@", target, NSStringFromSelector(action));
    
    if ([target respondsToSelector:action]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [target performSelector:action withObject:singleTapGesture];
        #pragma clang diagnostic pop
    } else {
        LogMessage(EchoLogError, @"触发失败: Target 无法响应");
        [self processTianDiPanQueue];
    }
}

%new
- (void)presentAIActionSheetWithReport:(NSString *)report {
    if (!report || report.length == 0) { LogMessage(EchoLogError, @"报告为空"); return; }
    [UIPasteboard generalPasteboard].string = report; 
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"天地盘详情已复制到剪贴板" preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertControllerStyleDefault handler:nil];
    [actionSheet addAction:copyAction];
    [self presentViewController:actionSheet animated:YES completion:nil];
}

%end

%ctor {
    @autoreleasepool {
        initializeTianDiPanCoordinates();
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[Echo-Final-Debug] 天地盘详情提取工具(终极调试版)已加载。");
    }
}
