#import <UIKit/UIKit.h>
#import <objc/runtime.h>
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
static __weak UIViewController *g_mainViewController = nil;
static __weak UIView *g_popoverSourceView = nil; // <<<< 核心：保存 Popover 的源视图

#pragma mark - Helpers
typedef NS_ENUM(NSInteger, EchoLogType) { EchoLogTypeInfo, EchoLogTypeSuccess, EchoLogError, EchoLogTypeDebug };
static void LogMessage(EchoLogType type, NSString *format, ...) {
    va_list args; va_start(args, format); NSString *message = [[NSString alloc] initWithFormat:format arguments:args]; va_end(args);
    NSLog(@"[Echo-Final] %@", message);
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
- (void)startTDPExtraction;
- (void)processTianDiPanQueue;
@end

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    if (g_isExtractingTianDiPanDetail) {
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
        if ([vcClassName isEqualToString:@"六壬大占.天將摘要視圖"] || [vcClassName isEqualToString:@"六壬大占.天地盤宮位摘要視圖"]) {
            LogMessage(EchoLogTypeDebug, @"拦截到 ViewController: %@", vcClassName);
            vcToPresent.view.alpha = 0.0f;
            
            Original_presentViewController(self, _cmd, vcToPresent, NO, ^(void){
                dispatch_async(dispatch_get_main_queue(), ^{
                     NSString *extractedText = extractDataFromStackViewPopup(vcToPresent.view);
                     [g_tianDiPan_resultsArray addObject:extractedText];
                     [vcToPresent dismissViewControllerAnimated:NO completion:^{
                         if (g_mainViewController) {
                            [g_mainViewController processTianDiPanQueue];
                         }
                     }];
                });
                if(completion) completion();
            });
            return;
        }
    }
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

%hook UIViewController
- (void)viewDidLoad {
    %orig;
    Class c = NSClassFromString(@"六壬大占.ViewController");
    if (c && [self isKindOfClass:c]) {
        g_mainViewController = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            UIWindow *w=GetFrontmostWindow(); if(!w||[w viewWithTag:kEchoControlButtonTag])return;
            UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem]; b.frame=CGRectMake(w.bounds.size.width-150,45,140,36); b.tag=kEchoControlButtonTag;
            [b setTitle:@"推衍课盘" forState:UIControlStateNormal]; b.backgroundColor=ECHO_COLOR_MAIN_BLUE; [b setTitleColor:[UIColor whiteColor]forState:UIControlStateNormal];
            b.layer.cornerRadius=18; [b addTarget:self action:@selector(createOrShowTDPPanel)forControlEvents:UIControlEventTouchUpInside]; [w addSubview:b];
        });
    }
}

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
- (void)handleTDPExtractionButtonTap:(UIButton *)sender { [self startTDPExtraction]; }

%new
- (void)startTDPExtraction {
    if (g_isExtractingTianDiPanDetail) { LogMessage(EchoLogError, @"错误: 提取任务已在进行中。"); return; }
    LogMessage(EchoLogTypeInfo, @"任务启动: 推衍天地盘详情...");
    
    // <<<< 核心修复点 1: 查找并缓存 SourceView >>>>
    Class sourceViewClass = NSClassFromString(@"六壬大占.課體視圖");
    if (!sourceViewClass) { LogMessage(EchoLogError, @"严重错误: 找不到关键的源视图类 '六壬大占.課體視圖'"); return; }
    NSMutableArray *sourceViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(sourceViewClass, self.view, sourceViews);
    if (sourceViews.count == 0) { LogMessage(EchoLogError, @"严重错误: 在当前界面找不到 '課體視圖' 的实例"); return; }
    g_popoverSourceView = sourceViews.firstObject;
    LogMessage(EchoLogTypeDebug, @"已成功定位Popover源视图: <%p>", g_popoverSourceView);
    
    g_isExtractingTianDiPanDetail = YES; 
    g_tianDiPan_workQueue = [NSMutableArray array];
    // 为了简化，我们只提取两个作为测试
    for(int i=0; i < 24; i++) { [g_tianDiPan_workQueue addObject:@(i)]; }
    g_tianDiPan_resultsArray = [NSMutableArray array];
    
    [self processTianDiPanQueue];
}


%new
- (void)processTianDiPanQueue {
    if (g_tianDiPan_workQueue.count == 0) {
        if (!g_isExtractingTianDiPanDetail) return;
        g_isExtractingTianDiPanDetail = NO;
        LogMessage(EchoLogTypeSuccess, @"完成: 所有天地盘详情提取完毕。");
        // ... (报告生成逻辑保持不变)
        NSMutableString *finalReport = [NSMutableString string];
        [finalReport appendString:@"// 天地盘详情 (完整版)\n\n"];
        for (NSUInteger i = 0; i < 24; i++) {
            NSString *itemType = (i < 12) ? @"天将详情" : @"上神详情";
            NSString *itemName = [NSString stringWithFormat:@"%@-%lu", (i < 12) ? @"天将" : @"上神", (unsigned long)i % 12];
            NSString *itemData = (i < g_tianDiPan_resultsArray.count) ? g_tianDiPan_resultsArray[i] : @"[数据提取失败]";
            NSMutableString *simplifiedData = [itemData mutableCopy]; CFStringTransform((__bridge CFStringRef)simplifiedData, NULL, CFSTR("Hant-Hans"), false);
            [finalReport appendFormat:@"-- [%@: %@] --\n%@\n\n", itemType, itemName, simplifiedData];
        }
        [UIPasteboard generalPasteboard].string = finalReport;
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"天地盘详情已复制到剪贴板" preferredStyle:UIAlertControllerStyleActionSheet];
        [ac addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
        g_tianDiPan_workQueue = nil; g_tianDiPan_resultsArray = nil; g_popoverSourceView = nil;
        return;
    }

    NSInteger index = [g_tianDiPan_workQueue.firstObject integerValue];
    [g_tianDiPan_workQueue removeObjectAtIndex:0];
    
    LogMessage(EchoLogTypeInfo, @"正在处理索引: %ld", (long)index);

    // ====================== 核心修复点 2: 直接创建并呈现 ViewController ======================
    @try {
        UIViewController *vcToPresent = nil;
        NSString *vcClassName = nil;

        // 根据索引判断应该创建哪个摘要视图
        if (index < 12) { // 0-11 是天将
            vcClassName = @"六壬大占.天將摘要視圖";
        } else { // 12-23 是上神 (天地盘宫位)
            vcClassName = @"六壬大占.天地盤宮位摘要視圖";
        }
        
        Class vcClass = NSClassFromString(vcClassName);
        if (!vcClass) {
            LogMessage(EchoLogError, @"创建VC失败: 找不到类 %@", vcClassName);
            [self processTianDiPanQueue];
            return;
        }
        
        // 创建实例
        vcToPresent = [[vcClass alloc] init];
        
        // <<<< 核心逻辑：手动设置 Popover >>>>
        vcToPresent.modalPresentationStyle = UIModalPresentationPopover;
        UIPopoverPresentationController *popover = vcToPresent.popoverPresentationController;
        if (popover) {
            popover.sourceView = g_popoverSourceView;
            // 为了避免箭头，我们可以把 sourceRect 设置为 sourceView 的中心一个很小的区域
            popover.sourceRect = CGRectMake(CGRectGetMidX(g_popoverSourceView.bounds), CGRectGetMidY(g_popoverSourceView.bounds), 1, 1);
            popover.permittedArrowDirections = 0; // No arrow
            
            LogMessage(EchoLogTypeDebug, @"Popover 已配置, SourceView: <%p>", g_popoverSourceView);
        } else {
             LogMessage(EchoLogError, @"获取 popoverPresentationController 失败!");
             [self processTianDiPanQueue];
             return;
        }
        
        // 直接调用 present 方法，我们的 Hook 会拦截它
        [self presentViewController:vcToPresent animated:NO completion:nil];

    } @catch (NSException *exception) {
        LogMessage(EchoLogError, @"直接呈现失败: %@", exception.reason);
        [self processTianDiPanQueue];
    }
    // =======================================================================================
}

%end

%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[Echo-Final] 天地盘详情提取工具(最终版)已加载。");
    }
}
