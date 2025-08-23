#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 屏幕日志系统 & 辅助函数
// =========================================================================

static UITextView *g_logTextView = nil;
static UIView *g_logContainerView = nil;

// 日志函数，会更新屏幕上的UITextView
static void LogTestMessage(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    // 原始NSLog，方便在电脑上调试
    NSLog(@"[Echo点击测试] %@", message);
    
    // 在主线程更新UI
    if (g_logTextView) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"HH:mm:ss"];
            NSString *logLine = [NSString stringWithFormat:@"[%@] %@\n", [formatter stringFromDate:[NSDate date]], message];
            
            NSMutableAttributedString *newLog = [[NSMutableAttributedString alloc] initWithString:logLine attributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont fontWithName:@"Menlo" size:10]}];
            
            NSMutableAttributedString *existingText = [[NSMutableAttributedString alloc] initWithAttributedString:g_logTextView.attributedText];
            [newLog appendAttributedString:existingText];
            
            // 限制日志长度，防止内存溢出
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
    titleLabel.text = @"Echo 模拟点击测试日志 (双击隐藏/显示)";
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

// 递归查找子视图
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if (!view || !storage) return; if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }

// =========================================================================
// 2. 全局状态定义
// =========================================================================
static BOOL g_isExtractingBiFa = NO; static void (^g_biFa_completion)(NSString *) = nil;
static BOOL g_isExtractingGeJu = NO; static void (^g_geJu_completion)(NSString *) = nil;
static BOOL g_isExtractingFangFa = NO; static void (^g_fangFa_completion)(NSString *) = nil;

// =========================================================================
// 3. 提取逻辑函数
// =========================================================================
static NSString* extractDataFromStackViewPopup(UIView *contentView, NSString* type) {
    NSMutableArray *textParts = [NSMutableArray array];
    NSMutableArray *stackViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UIStackView class], contentView, stackViews);
    [stackViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
    for (UIStackView *stackView in stackViews) {
        NSArray *arrangedSubviews = stackView.arrangedSubviews;
        if (arrangedSubviews.count >= 1 && [arrangedSubviews[0] isKindOfClass:[UILabel class]]) {
            UILabel *titleLabel = arrangedSubviews[0];
            NSString *rawTitle = titleLabel.text ?: @"";
            // 修正关键词移除逻辑，使其更精确
            rawTitle = [rawTitle stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@" %@", type] withString:@""];
            NSString *cleanTitle = [rawTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            NSMutableArray *descParts = [NSMutableArray array];
            if (arrangedSubviews.count > 1) { 
                for (NSUInteger i = 1; i < arrangedSubviews.count; i++) { 
                    if ([arrangedSubviews[i] isKindOfClass:[UILabel class]]) { 
                        [descParts addObject:((UILabel *)arrangedSubviews[i]).text]; 
                    } 
                } 
            }
            NSString *fullDesc = [[descParts componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            [textParts addObject:[NSString stringWithFormat:@"%@→%@", cleanTitle, [fullDesc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]];
        }
    }
    return [textParts componentsJoinedByString:@"\n"];
}

// =========================================================================
// 4. 核心 Hook 实现
// =========================================================================
@interface UIViewController (EchoSimulateTapTest)
- (void)runEchoSimulateTapTests;
- (void)extractByTappingLabelWithText:(NSString *)searchText completion:(void (^)(NSString *))completion;
@end

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    NSString *vcClassName = NSStringFromClass([vcToPresent class]);
    
    // 我们只关心格局总览弹窗
    if ([vcClassName containsString:@"格局總覽視圖"]) {
        NSString *taskName = nil;
        void (^taskCompletion)(NSString *) = nil;
        NSString *extractType = nil;
        
        if (g_isExtractingBiFa) {
            taskName = @"毕法要诀";
            extractType = @"毕法";
            taskCompletion = g_biFa_completion;
            g_isExtractingBiFa = NO; g_biFa_completion = nil;
        } else if (g_isExtractingGeJu) {
            taskName = @"格局要览";
            extractType = @"格局";
            taskCompletion = g_geJu_completion;
            g_isExtractingGeJu = NO; g_geJu_completion = nil;
        } else if (g_isExtractingFangFa) {
            taskName = @"解析方法";
            extractType = @"方法";
            taskCompletion = g_fangFa_completion;
            g_isExtractingFangFa = NO; g_fangFa_completion = nil;
        }

        if (taskName) {
            LogTestMessage(@"匹配成功 -> %@", taskName);
            // 延迟提取依然是好习惯，防止万一
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *result = extractDataFromStackViewPopup(vcToPresent.view, extractType);
                [UIPasteboard generalPasteboard].string = result;
                LogTestMessage(@"提取成功！%@ 内容已复制 (共 %lu 字符)", taskName, (unsigned long)result.length);
                if (taskCompletion) {
                    taskCompletion(result);
                }
            });
            return; // 阻止弹窗
        }
    }
    
    LogTestMessage(@"弹窗 %@ 未被拦截，正常显示。", vcClassName);
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

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
            CreateLogUI(self.view.window); 
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem]; 
            testButton.frame = CGRectMake(10, 50, 160, 40); 
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14]; 
            [testButton setTitle:@"运行模拟点击测试" forState:UIControlStateNormal]; 
            testButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1.0]; 
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; 
            testButton.layer.cornerRadius = 20;
            testButton.layer.shadowColor = [UIColor blackColor].CGColor;
            testButton.layer.shadowOffset = CGSizeMake(0, 2);
            testButton.layer.shadowOpacity = 0.5;
            [testButton addTarget:self action:@selector(runEchoSimulateTapTests) forControlEvents:UIControlEventTouchUpInside]; 
            [self.view.window addSubview:testButton]; 
        }); 
    } 
}

%new
- (void)runEchoSimulateTapTests {
    LogTestMessage(@"================== 开始模拟点击测试 ==================");
    __weak typeof(self) weakSelf = self;
    
    [self extractByTappingLabelWithText:@"毕法" completion:^(NSString *result) {
        LogTestMessage(@"[测试结果] 毕法要诀处理完毕。");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf extractByTappingLabelWithText:@"格局" completion:^(NSString *result) {
                LogTestMessage(@"[测试结果] 格局要览处理完毕。");

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                     [weakSelf extractByTappingLabelWithText:@"方法" completion:^(NSString *result) {
                        LogTestMessage(@"[测试结果] 解析方法处理完毕。");
                        LogTestMessage(@"================== 所有点击测试完成 ==================");
                    }];
                });
            }];
        });
    }];
}

// 核心的模拟点击触发函数
%new
- (void)extractByTappingLabelWithText:(NSString *)searchText completion:(void (^)(NSString *))completion {
    LogTestMessage(@"[任务触发] 正在查找并点击包含 '%@' 的标签...", searchText);

    if ([searchText isEqualToString:@"毕法"]) {
        if(g_isExtractingBiFa) return;
        g_isExtractingBiFa = YES;
        g_biFa_completion = [completion copy];
    } else if ([searchText isEqualToString:@"格局"]) {
        if(g_isExtractingGeJu) return;
        g_isExtractingGeJu = YES;
        g_geJu_completion = [completion copy];
    } else if ([searchText isEqualToString:@"方法"]) {
        if(g_isExtractingFangFa) return;
        g_isExtractingFangFa = YES;
        g_fangFa_completion = [completion copy];
    }
    
    // 1. 查找所有 UILabel
    NSMutableArray<UILabel *> *allLabels = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], self.view, allLabels);
    
    UILabel *targetLabel = nil;
    for (UILabel *label in allLabels) {
        if ([label.text containsString:searchText]) {
            // 确保它是一个可点击的标签，检查手势
            BOOL hasTapGesture = NO;
            // 检查自身手势
            for (UIGestureRecognizer *gesture in label.gestureRecognizers) {
                if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
                    hasTapGesture = YES;
                    break;
                }
            }
            // 如果自身没有，检查父视图的手势（这在很多情况下是必须的）
            if (!hasTapGesture && label.superview) {
                 for (UIGestureRecognizer *gesture in label.superview.gestureRecognizers) {
                    if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
                        hasTapGesture = YES;
                        break;
                    }
                }
            }
            
            if (hasTapGesture) {
                targetLabel = label;
                break;
            }
        }
    }
    
    if (targetLabel) {
        LogTestMessage(@"已定位到目标标签: '%@', 正在模拟点击...", targetLabel.text);
        
        // 2. 模拟点击
        UIView *viewToTap = targetLabel;
        UITapGestureRecognizer *tapGesture = nil;

        // 优先使用Label自身的手势
        for (UIGestureRecognizer *gesture in viewToTap.gestureRecognizers) {
            if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
                tapGesture = (UITapGestureRecognizer *)gesture;
                break;
            }
        }
        // 如果自身没有，检查父视图
        if (!tapGesture && viewToTap.superview) {
             viewToTap = viewToTap.superview; // 操作对象变为父视图
             for (UIGestureRecognizer *gesture in viewToTap.gestureRecognizers) {
                if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
                    tapGesture = (UITapGestureRecognizer *)gesture;
                    break;
                }
            }
        }
        
        if (tapGesture) {
            // 通过运行时获取手势绑定的 action 和 target
            // 这是一个常用的获取私有 target-action 的方法
            Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
            id targetProxies = object_getIvar(tapGesture, targetsIvar);
            
            if (targetProxies && [targetProxies count] > 0) {
                id targetProxy = targetProxies[0];
                id realTarget = [targetProxy valueForKey:@"target"]; // 有些系统版本是 target
                if (!realTarget) realTarget = [targetProxy valueForKey:@"_target"]; // 有些是 _target
                
                SEL action = NSSelectorFromString([NSStringFromSelector([targetProxy action]) stringByReplacingOccurrencesOfString:@":" withString:@""]);
                
                if (realTarget && action && [realTarget respondsToSelector:action]) {
                    LogTestMessage(@"成功触发手-势 Action: %@ on Target: %@", NSStringFromSelector(action), realTarget);
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [realTarget performSelector:action withObject:tapGesture];
                    #pragma clang diagnostic pop
                } else {
                     LogTestMessage(@"错误：无法触发手势，target或action无效。");
                }
            } else {
                LogTestMessage(@"错误：无法从手势中获取 target。");
            }
        } else {
             LogTestMessage(@"错误：在 '%@' 及其父视图上未找到可用的Tap手势。", targetLabel.text);
        }
    } else {
        LogTestMessage(@"错误：未能定位到包含 '%@' 的可点击标签。", searchText);
        // 如果找不到，需要重置状态
         if ([searchText isEqualToString:@"毕法"]) { g_isExtractingBiFa = NO; g_biFa_completion = nil; if(completion) completion(nil); }
         else if ([searchText isEqualToString:@"格局"]) { g_isExtractingGeJu = NO; g_geJu_completion = nil; if(completion) completion(nil); }
         else if ([searchText isEqualToString:@"方法"]) { g_isExtractingFangFa = NO; g_fangFa_completion = nil; if(completion) completion(nil); }
    }
}
%end

%ctor { 
    @autoreleasepool { 
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController); 
    } 
}
