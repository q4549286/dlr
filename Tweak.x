#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 屏幕日志系统 & 辅助函数 (无变化)
// =========================================================================
static UITextView *g_logTextView = nil; static UIView *g_logContainerView = nil;
static void LogTestMessage(NSString *format, ...) { va_list args; va_start(args, format); NSString *message = [[NSString alloc] initWithFormat:format arguments:args]; va_end(args); NSLog(@"[Echo无痕测试] %@", message); if (g_logTextView) { dispatch_async(dispatch_get_main_queue(), ^{ NSDateFormatter *formatter = [[NSDateFormatter alloc] init]; [formatter setDateFormat:@"HH:mm:ss"]; NSString *logLine = [NSString stringWithFormat:@"[%@] %@\n", [formatter stringFromDate:[NSDate date]], message]; NSMutableAttributedString *newLog = [[NSMutableAttributedString alloc] initWithString:logLine attributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont fontWithName:@"Menlo" size:10]}]; NSMutableAttributedString *existingText = [[NSMutableAttributedString alloc] initWithAttributedString:g_logTextView.attributedText]; [newLog appendAttributedString:existingText]; if (newLog.length > 5000) { [newLog deleteCharactersInRange:NSMakeRange(5000, newLog.length - 5000)]; } g_logTextView.attributedText = newLog; }); } }
static void CreateLogUI(UIWindow *window) { if (g_logContainerView || !window) return; CGFloat screenWidth = window.bounds.size.width; CGFloat screenHeight = window.bounds.size.height; g_logContainerView = [[UIView alloc] initWithFrame:CGRectMake(10, screenHeight - 260, screenWidth - 20, 250)]; g_logContainerView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85]; g_logContainerView.layer.cornerRadius = 12; g_logContainerView.clipsToBounds = YES; UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, g_logContainerView.bounds.size.width, 30)]; titleBar.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0]; UILabel *titleLabel = [[UILabel alloc] initWithFrame:titleBar.bounds]; titleLabel.text = @"Echo 无痕提取测试日志 (双击隐藏/显示)"; titleLabel.textColor = [UIColor whiteColor]; titleLabel.font = [UIFont boldSystemFontOfSize:12]; titleLabel.textAlignment = NSTextAlignmentCenter; [titleBar addSubview:titleLabel]; [g_logContainerView addSubview:titleBar]; UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:g_logContainerView action:@selector(handlePan:)]; [titleBar addGestureRecognizer:pan]; UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:g_logContainerView action:@selector(handleDoubleTap:)]; doubleTap.numberOfTapsRequired = 2; [titleBar addGestureRecognizer:doubleTap]; g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(5, 35, g_logContainerView.bounds.size.width - 10, g_logContainerView.bounds.size.height - 40)]; g_logTextView.backgroundColor = [UIColor clearColor]; g_logTextView.editable = NO; g_logTextView.textColor = [UIColor whiteColor]; g_logTextView.font = [UIFont fontWithName:@"Menlo" size:10]; g_logTextView.attributedText = [[NSAttributedString alloc] initWithString:@"日志系统已就绪...\n" attributes:@{NSForegroundColorAttributeName: [UIColor greenColor]}]; [g_logContainerView addSubview:g_logTextView]; [window addSubview:g_logContainerView]; }
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if (!view || !storage) return; if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }
#define SUPPRESS_LEAK_WARNING(code) _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") code; _Pragma("clang diagnostic pop")

// =========================================================================
// 2. 全局状态定义 (无变化)
// =========================================================================
static BOOL g_isExtractingJiuZongMen = NO; static void (^g_jiuZongMen_completion)(NSString *) = nil; static BOOL g_isExtractingBiFa = NO; static void (^g_biFa_completion)(NSString *) = nil; static BOOL g_isExtractingGeJu = NO; static void (^g_geJu_completion)(NSString *) = nil; static BOOL g_isExtractingFangFa = NO; static void (^g_fangFa_completion)(NSString *) = nil; static BOOL g_isExtractingQiZheng = NO; static void (^g_qiZheng_completion)(NSString *) = nil; static BOOL g_isExtractingSanGong = NO; static void (^g_sanGong_completion)(NSString *) = nil;

// =========================================================================
// 3. 提取逻辑函数 (核心修正)
// =========================================================================
static NSString* extractDataFromPopup(UIView *contentView) {
    // 优先查找 IntrinsicTableView
    Class tableViewClass = NSClassFromString(@"六壬大占.IntrinsicTableView");
    if (!tableViewClass) {
        // Fallback for older versions or other popups
        tableViewClass = [UITableView class];
    }
    
    NSMutableArray *tableViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(tableViewClass, contentView, tableViews);
    
    if (tableViews.count > 0) {
        LogTestMessage(@"检测到 TableView 布局，开始解析列表...");
        UITableView *tableView = tableViews.firstObject;
        NSMutableArray<NSString *> *textParts = [NSMutableArray array];
        
        // 遍历所有 Section 和 Row 来获取 Cell
        for (NSInteger section = 0; section < [tableView numberOfSections]; section++) {
            for (NSInteger row = 0; row < [tableView numberOfRowsInSection:section]; row++) {
                UITableViewCell *cell = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
                if (cell) {
                    NSMutableArray *labels = [NSMutableArray array];
                    FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labels);
                    
                    // 对Cell内部的Label按Y坐标排序，防止顺序错乱
                    [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                        return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];
                    }];
                    
                    // 将一个Cell内的所有Label文本拼接成一行
                    NSMutableArray *cellTexts = [NSMutableArray array];
                    for(UILabel *label in labels) {
                        if (label.text.length > 0) {
                           [cellTexts addObject:label.text];
                        }
                    }
                    [textParts addObject:[cellTexts componentsJoinedByString:@"→"]];
                }
            }
        }
        return [textParts componentsJoinedByString:@"\n"];
    }

    // 如果没有找到 TableView，则使用原来的 StackView 提取逻辑作为备用
    LogTestMessage(@"未检测到 TableView，回退到 StackView 解析模式...");
    NSMutableArray *stackViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UIStackView class], contentView, stackViews);
    NSMutableArray *textParts = [NSMutableArray array];
    for(UIStackView *sv in stackViews) {
        for(UIView *subview in sv.arrangedSubviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                [textParts addObject:((UILabel*)subview).text];
            }
        }
    }
    return [textParts componentsJoinedByString:@"\n"];
}

// 简单的提取逻辑，用于七政/三宫等
static NSString* extractDataFromSimpleLabelPopup(UIView *contentView) {
    NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
    [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
    NSMutableArray *textParts = [NSMutableArray array]; for (UILabel *label in allLabels) { if (label.text.length > 0) [textParts addObject:label.text]; }
    return [textParts componentsJoinedByString:@"\n"];
}


// =========================================================================
// 4. 核心 Hook 实现 (调用新的提取函数)
// =========================================================================
@interface UIViewController (EchoNoPopupFinalTest)
// ... 接口声明
@end

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    NSString *vcClassName = NSStringFromClass([vcToPresent class]);

    void (^handleExtraction)(NSString *, NSString *, void(^)(NSString*)) = ^(NSString *taskName, NSString *result, void(^completionBlock)(NSString*)) {
        [UIPasteboard generalPasteboard].string = result ?: @"";
        LogTestMessage(@"提取成功！%@ 内容已复制 (共 %lu 字符)", taskName, (unsigned long)(result.length));
        if (completionBlock) { completionBlock(result); }
    };
    
    void (^delayedExtraction)(void(^)()) = ^(void(^extractionLogic)()) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), extractionLogic);
    };

    if (g_isExtractingJiuZongMen && [vcClassName containsString:@"課體概覽視圖"]) {
        LogTestMessage(@"匹配成功 -> 九宗门"); g_isExtractingJiuZongMen = NO;
        delayedExtraction(^{
            NSString *result = extractDataFromPopup(vcToPresent.view);
            handleExtraction(@"九宗门", result, g_jiuZongMen_completion);
            g_jiuZongMen_completion = nil;
        }); return;
    }
    else if ([vcClassName containsString:@"格局總覽視圖"]) {
        if (g_isExtractingBiFa) {
            LogTestMessage(@"匹配成功 -> 毕法要诀"); g_isExtractingBiFa = NO;
            delayedExtraction(^{ NSString *result = extractDataFromPopup(vcToPresent.view); handleExtraction(@"毕法要诀", result, g_biFa_completion); g_biFa_completion = nil; });
            return;
        } else if (g_isExtractingGeJu) {
            LogTestMessage(@"匹配成功 -> 格局要览"); g_isExtractingGeJu = NO;
            delayedExtraction(^{ NSString *result = extractDataFromPopup(vcToPresent.view); handleExtraction(@"格局要览", result, g_geJu_completion); g_geJu_completion = nil; });
            return;
        } else if (g_isExtractingFangFa) {
            LogTestMessage(@"匹配成功 -> 解析方法"); g_isExtractingFangFa = NO;
            delayedExtraction(^{ NSString *result = extractDataFromPopup(vcToPresent.view); handleExtraction(@"解析方法", result, g_fangFa_completion); g_fangFa_completion = nil; });
            return;
        }
    }
    else if (g_isExtractingQiZheng && [vcClassName containsString:@"七政"]) {
        LogTestMessage(@"匹配成功 -> 七政四余"); g_isExtractingQiZheng = NO;
        delayedExtraction(^{ NSString *result = extractDataFromSimpleLabelPopup(vcToPresent.view); handleExtraction(@"七政四余", result, g_qiZheng_completion); g_qiZheng_completion = nil; });
        return;
    }
    else if (g_isExtractingSanGong && [vcClassName containsString:@"三宮時信息視圖"]) {
        LogTestMessage(@"匹配成功 -> 三宫时信息"); g_isExtractingSanGong = NO;
        delayedExtraction(^{ NSString *result = extractDataFromSimpleLabelPopup(vcToPresent.view); handleExtraction(@"三宫时信息", result, g_sanGong_completion); g_sanGong_completion = nil; });
        return;
    }
    LogTestMessage(@"弹窗 %@ 未被拦截，正常显示。", vcClassName);
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

@interface UIView (EchoLogGestures) - (void)handlePan:(UIPanGestureRecognizer *)recognizer; - (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer; @end
@implementation UIView (EchoLogGestures) - (void)handlePan:(UIPanGestureRecognizer *)recognizer { CGPoint translation = [recognizer translationInView:self.superview]; self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y); [recognizer setTranslation:CGPointZero inView:self.superview]; } - (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer { [UIView animateWithDuration:0.3 animations:^{ if (self.bounds.size.height > 50) { self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, 30); for (UIView *subview in self.subviews) { if ([subview isKindOfClass:[UITextView class]]) subview.hidden = YES; } } else { self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, 250); for (UIView *subview in self.subviews) { if ([subview isKindOfClass:[UITextView class]]) subview.hidden = NO; } } }]; } @end

%hook UIViewController
// viewDidLoad, runEchoNoPopupExtractionTests 和 其他 extract... 函数都无变化
- (void)viewDidLoad { %orig; Class targetClass = NSClassFromString(@"六壬大占.ViewController"); if (targetClass && [self isKindOfClass:targetClass]) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ CreateLogUI(self.view.window); UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem]; testButton.frame = CGRectMake(10, 50, 160, 40); testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14]; [testButton setTitle:@"运行完整无痕测试" forState:UIControlStateNormal]; testButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.3 alpha:1.0]; [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; testButton.layer.cornerRadius = 20; testButton.layer.shadowColor = [UIColor blackColor].CGColor; testButton.layer.shadowOffset = CGSizeMake(0, 2); testButton.layer.shadowOpacity = 0.5; [testButton addTarget:self action:@selector(runEchoNoPopupExtractionTests) forControlEvents:UIControlEventTouchUpInside]; [self.view.window addSubview:testButton]; }); } }
%new
- (void)runEchoNoPopupExtractionTests { LogTestMessage(@"================== 开始完整测试 =================="); NSArray<dispatch_block_t> *tasks = @[ ^{ [self extractJiuZongMen_NoPopup_WithCompletion:nil]; }, ^{ [self extractBiFa_NoPopup_WithCompletion:nil]; }, ^{ [self extractGeJu_NoPopup_WithCompletion:nil]; }, ^{ [self extractFangFa_NoPopup_WithCompletion:nil]; }, ^{ [self extractQiZheng_NoPopup_WithCompletion:nil]; }, ^{ [self extractSanGong_NoPopup_WithCompletion:nil]; } ]; NSMutableArray<dispatch_block_t> *taskQueue = [tasks mutableCopy]; __block void (^executeNextTask)(); __weak __block void (^weak_executeNextTask)(); executeNextTask = ^{ __strong __block void (^strong_executeNextTask)() = weak_executeNextTask; if (taskQueue.count == 0 || !strong_executeNextTask) { LogTestMessage(@"================== 所有测试完成 =================="); return; } dispatch_block_t currentTask = taskQueue.firstObject; [taskQueue removeObjectAtIndex:0]; currentTask(); dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ strong_executeNextTask(); }); }; weak_executeNextTask = executeNextTask; executeNextTask(); }
%new - (void)extractJiuZongMen_NoPopup_WithCompletion:(void (^)(NSString *))completion { if (g_isExtractingJiuZongMen) return; LogTestMessage(@"[任务触发] 九宗门"); g_isExtractingJiuZongMen = YES; g_jiuZongMen_completion = [completion copy]; SEL selector = NSSelectorFromString(@"顯示九宗門概覽"); if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector]); } }
%new - (void)extractBiFa_NoPopup_WithCompletion:(void (^)(NSString *))completion { if (g_isExtractingBiFa) return; LogTestMessage(@"[任务触发] 毕法要诀"); g_isExtractingBiFa = YES; g_biFa_completion = [completion copy]; SEL selector = NSSelectorFromString(@"顯示法訣總覽"); if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector]); } }
%new - (void)extractGeJu_NoPopup_WithCompletion:(void (^)(NSString *))completion { if (g_isExtractingGeJu) return; LogTestMessage(@"[任务触发] 格局要览"); g_isExtractingGeJu = YES; g_geJu_completion = [completion copy]; SEL selector = NSSelectorFromString(@"顯示格局總覽"); if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector]); } }
%new - (void)extractFangFa_NoPopup_WithCompletion:(void (^)(NSString *))completion { if (g_isExtractingFangFa) return; LogTestMessage(@"[任务触发] 解析方法"); g_isExtractingFangFa = YES; g_fangFa_completion = [completion copy]; SEL selector = NSSelectorFromString(@"顯示方法總覽"); if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector]); } }
%new - (void)extractQiZheng_NoPopup_WithCompletion:(void (^)(NSString *))completion { if (g_isExtractingQiZheng) return; LogTestMessage(@"[任务触发] 七政四余"); g_isExtractingQiZheng = YES; g_qiZheng_completion = [completion copy]; SEL selector = NSSelectorFromString(@"顯示七政信息WithSender:"); if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector withObject:nil]); } }
%new - (void)extractSanGong_NoPopup_WithCompletion:(void (^)(NSString *))completion { if (g_isExtractingSanGong) return; LogTestMessage(@"[任务触发] 三宫时信息"); g_isExtractingSanGong = YES; g_sanGong_completion = [completion copy]; SEL selector = NSSelectorFromString(@"顯示三宮時信息WithSender:"); if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector withObject:nil]); } }
%end

%ctor { @autoreleasepool { MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController); } }
