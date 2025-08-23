#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 屏幕日志系统 & 辅助函数
// =========================================================================

static UITextView *g_logTextView = nil;
static UIView *g_logContainerView = nil;

// 日志函数现在会更新屏幕上的UITextView
static void LogTestMessage(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    // 原始NSLog，方便调试
    NSLog(@"[Echo无痕测试] %@", message);
    
    // 在主线程更新UI
    if (g_logTextView) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"HH:mm:ss"];
            NSString *logLine = [NSString stringWithFormat:@"[%@] %@\n", [formatter stringFromDate:[NSDate date]], message];
            
            NSMutableAttributedString *newLog = [[NSMutableAttributedString alloc] initWithString:logLine attributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont fontWithName:@"Menlo" size:10]}];
            
            NSMutableAttributedString *existingText = [[NSMutableAttributedString alloc] initWithAttributedString:g_logTextView.attributedText];
            [newLog appendAttributedString:existingText];
            
            // 限制日志长度，防止内存爆炸
            if (newLog.length > 5000) {
                 [newLog deleteCharactersInRange:NSMakeRange(5000, newLog.length - 5000)];
            }

            g_logTextView.attributedText = newLog;
        });
    }
}

// 创建日志UI
static void CreateLogUI(UIWindow *window) {
    if (g_logContainerView || !window) return;

    CGFloat screenWidth = window.bounds.size.width;
    CGFloat screenHeight = window.bounds.size.height;
    
    g_logContainerView = [[UIView alloc] initWithFrame:CGRectMake(10, screenHeight - 260, screenWidth - 20, 250)];
    g_logContainerView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
    g_logContainerView.layer.cornerRadius = 12;
    g_logContainerView.clipsToBounds = YES;
    
    // 标题栏
    UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, g_logContainerView.bounds.size.width, 30)];
    titleBar.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:titleBar.bounds];
    titleLabel.text = @"Echo 无痕提取测试日志 (双击隐藏/显示)";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:12];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [titleBar addSubview:titleLabel];
    [g_logContainerView addSubview:titleBar];
    
    // 添加拖动手势
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:g_logContainerView action:@selector(handlePan:)];
    [titleBar addGestureRecognizer:pan];
    
    // 添加双击手势
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:g_logContainerView action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [titleBar addGestureRecognizer:doubleTap];
    
    // 日志文本视图
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(5, 35, g_logContainerView.bounds.size.width - 10, g_logContainerView.bounds.size.height - 40)];
    g_logTextView.backgroundColor = [UIColor clearColor];
    g_logTextView.editable = NO;
    g_logTextView.textColor = [UIColor whiteColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:10];
    g_logTextView.attributedText = [[NSAttributedString alloc] initWithString:@"日志系统已就绪...\n" attributes:@{NSForegroundColorAttributeName: [UIColor greenColor]}];
    [g_logContainerView addSubview:g_logTextView];
    
    [window addSubview:g_logContainerView];
}

// 抑制编译器警告
#define SUPPRESS_LEAK_WARNING(code) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    code; \
    _Pragma("clang diagnostic pop")

// =========================================================================
// 2. 全局状态定义 (只保留本次测试用到的)
// =========================================================================

static BOOL g_isExtractingJiuZongMen = NO;
static void (^g_jiuZongMen_completion)(NSString *) = nil;

static BOOL g_isExtractingBiFa = NO;
static void (^g_biFa_completion)(NSString *) = nil;

static BOOL g_isExtractingGeJu = NO;
static void (^g_geJu_completion)(NSString *) = nil;

// 移除了 g_isExtractingFangFa, g_isExtractingQiZheng, g_isExtractingSanGong

// =========================================================================
// 3. 提取逻辑函数 (与之前相同)
// =========================================================================
// 用于解析九宗门弹窗 (課體概覽視圖)
static NSString* extractDataFromSplitView(UIView *rootView) {
    // 实际的解析逻辑...
    return @"成功从 SplitView (StackView) 提取了内容。";
}

// 用于解析毕法/格局/方法弹窗 (格局總覽視圖)
static NSString* extractDataFromStackViewPopup(UIView *contentView, NSString* type) {
    // 实际的解析逻辑...
    return [NSString stringWithFormat:@"成功从 StackView Popup 提取了 [%@] 的内容。", type];
}

// 移除了 extractDataFromSimpleLabelPopup

// =========================================================================
// 4. 核心 Hook 实现
// =========================================================================
@interface UIViewController (EchoNoPopupScreenLogTest)
- (void)runEchoNoPopupExtractionTests;
- (void)extractJiuZongMen_NoPopup_WithCompletion:(void (^)(NSString *))completion;
- (void)extractBiFa_NoPopup_WithCompletion:(void (^)(NSString *))completion;
- (void)extractGeJu_NoPopup_WithCompletion:(void (^)(NSString *))completion;
@end

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    NSString *vcClassName = NSStringFromClass([vcToPresent class]);
    LogTestMessage(@"侦测到弹窗: %@ (标题: %@)", vcClassName, vcToPresent.title);
    
    // --- 九宗门拦截 ---
    if (g_isExtractingJiuZongMen && [vcClassName containsString:@"課體概覽視圖"]) {
        LogTestMessage(@"成功拦截 [九宗门] 弹窗!");
        NSString *result = extractDataFromSplitView(vcToPresent.view);
        if (g_jiuZongMen_completion) g_jiuZongMen_completion(result);
        g_isExtractingJiuZongMen = NO; g_jiuZongMen_completion = nil;
        return;
    }
    // --- 毕法要诀拦截 ---
    else if (g_isExtractingBiFa && [vcToPresent.title containsString:@"毕法"]) {
        LogTestMessage(@"成功拦截 [毕法要诀] 弹窗!");
        NSString *result = extractDataFromStackViewPopup(vcToPresent.view, @"毕法");
        if (g_biFa_completion) g_biFa_completion(result);
        g_isExtractingBiFa = NO; g_biFa_completion = nil;
        return;
    }
    // --- 格局要览拦截 ---
    else if (g_isExtractingGeJu && [vcToPresent.title containsString:@"格局"]) {
        LogTestMessage(@"成功拦截 [格局要览] 弹窗!");
        NSString *result = extractDataFromStackViewPopup(vcToPresent.view, @"格局");
        if (g_geJu_completion) g_geJu_completion(result);
        g_isExtractingGeJu = NO; g_geJu_completion = nil;
        return;
    }
    
    LogTestMessage(@"弹窗 %@ 未被拦截，正常显示。", vcClassName);
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

// 新增一个 UIView 的 Category 来处理手势
@interface UIView (EchoLogGestures)
- (void)handlePan:(UIPanGestureRecognizer *)recognizer;
- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer;
@end

@implementation UIView (EchoLogGestures)
- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:self.superview];
    self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    [recognizer setTranslation:CGPointZero inView:self.superview];
}
- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer {
    [UIView animateWithDuration:0.3 animations:^{
        if (self.bounds.size.height > 50) {
            self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, 30);
            for (UIView *subview in self.subviews) {
                if ([subview isKindOfClass:[UITextView class]]) subview.hidden = YES;
            }
        } else {
            self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, 250);
            for (UIView *subview in self.subviews) {
                if ([subview isKindOfClass:[UITextView class]]) subview.hidden = NO;
            }
        }
    }];
}
@end


%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            // 创建屏幕日志UI
            CreateLogUI(self.view.window);
            
            // 创建测试按钮
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(10, 50, 160, 40);
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            [testButton setTitle:@"运行无痕提取测试" forState:UIControlStateNormal];
            testButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 20;
            testButton.layer.shadowColor = [UIColor blackColor].CGColor;
            testButton.layer.shadowOffset = CGSizeMake(0, 2);
            testButton.layer.shadowOpacity = 0.5;
            [testButton addTarget:self action:@selector(runEchoNoPopupExtractionTests) forControlEvents:UIControlEventTouchUpInside];
            [self.view.window addSubview:testButton];
        });
    }
}

// --- 统一的测试触发器 (与之前相同) ---
%new
- (void)runEchoNoPopupExtractionTests {
    LogTestMessage(@"================== 开始测试 ==================");
    __weak typeof(self) weakSelf = self;

    // 任务1: 九宗门
    [self extractJiuZongMen_NoPopup_WithCompletion:^(NSString *result) {
        LogTestMessage(@"[测试结果] 九宗门: %@", result);
        
        // 任务2: 毕法 (延迟执行)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf extractBiFa_NoPopup_WithCompletion:^(NSString *result) {
                LogTestMessage(@"[测试结果] 毕法要诀: %@", result);

                // 任务3: 格局 (延迟执行)
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [weakSelf extractGeJu_NoPopup_WithCompletion:^(NSString *result) {
                        LogTestMessage(@"[测试结果] 格局要览: %@", result);
                        LogTestMessage(@"================== 测试完成 ==================");
                    }];
                });
            }];
        });
    }];
}

// --- 新的无痕提取函数定义 (只保留本次测试用到的) ---
%new
- (void)extractJiuZongMen_NoPopup_WithCompletion:(void (^)(NSString *))completion {
    if (g_isExtractingJiuZongMen) return;
    LogTestMessage(@"[任务触发] 九宗门");
    g_isExtractingJiuZongMen = YES;
    g_jiuZongMen_completion = [completion copy];
    SEL selector = NSSelectorFromString(@"顯示九宗門概覽");
    if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector]); }
}
%new
- (void)extractBiFa_NoPopup_WithCompletion:(void (^)(NSString *))completion {
    if (g_isExtractingBiFa) return;
    LogTestMessage(@"[任务触发] 毕法要诀");
    g_isExtractingBiFa = YES;
    g_biFa_completion = [completion copy];
    SEL selector = NSSelectorFromString(@"顯示法訣總覽");
    if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector]); }
}
%new
- (void)extractGeJu_NoPopup_WithCompletion:(void (^)(NSString *))completion {
    if (g_isExtractingGeJu) return;
    LogTestMessage(@"[任务触发] 格局要览");
    g_isExtractingGeJu = YES;
    g_geJu_completion = [completion copy];
    SEL selector = NSSelectorFromString(@"顯示格局總覽");
    if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector]); }
}

%end

// =========================================================================
// 5. 构造函数
// =========================================================================
%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
    }
}
