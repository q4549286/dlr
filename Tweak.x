#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 屏幕日志系统 & 辅助函数
// =========================================================================
static UITextView *g_logTextView = nil; static UIView *g_logContainerView = nil;
// ... 日志和UI创建函数 (与之前版本相同，此处省略以保持简洁)
static void LogTestMessage(NSString *format, ...) { va_list args; va_start(args, format); NSString *message = [[NSString alloc] initWithFormat:format arguments:args]; va_end(args); NSLog(@"[Echo点击测试] %@", message); if (g_logTextView) { dispatch_async(dispatch_get_main_queue(), ^{ NSDateFormatter *formatter = [[NSDateFormatter alloc] init]; [formatter setDateFormat:@"HH:mm:ss"]; NSString *logLine = [NSString stringWithFormat:@"[%@] %@\n", [formatter stringFromDate:[NSDate date]], message]; NSMutableAttributedString *newLog = [[NSMutableAttributedString alloc] initWithString:logLine attributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont fontWithName:@"Menlo" size:10]}]; NSMutableAttributedString *existingText = [[NSMutableAttributedString alloc] initWithAttributedString:g_logTextView.attributedText]; [newLog appendAttributedString:existingText]; if (newLog.length > 5000) { [newLog deleteCharactersInRange:NSMakeRange(5000, newLog.length - 5000)]; } g_logTextView.attributedText = newLog; }); } }
static void CreateLogUI(UIWindow *window) { /* ... same as before ... */ }
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
            NSString *cleanTitle = [[(titleLabel.text ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@" %@", type] withString:@""];
            NSMutableArray *descParts = [NSMutableArray array];
            if (arrangedSubviews.count > 1) { for (NSUInteger i = 1; i < arrangedSubviews.count; i++) { if ([arrangedSubviews[i] isKindOfClass:[UILabel class]]) { [descParts addObject:((UILabel *)arrangedSubviews[i]).text]; } } }
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
        
        if (g_isExtractingBiFa) {
            taskName = @"毕法要诀";
            taskCompletion = g_biFa_completion;
            g_isExtractingBiFa = NO; g_biFa_completion = nil;
        } else if (g_isExtractingGeJu) {
            taskName = @"格局要览";
            taskCompletion = g_geJu_completion;
            g_isExtractingGeJu = NO; g_geJu_completion = nil;
        } else if (g_isExtractingFangFa) {
            taskName = @"解析方法";
            taskCompletion = g_fangFa_completion;
            g_isExtractingFangFa = NO; g_fangFa_completion = nil;
        }

        if (taskName) {
            LogTestMessage(@"匹配成功 -> %@", taskName);
            // 延迟提取依然是好习惯，防止万一
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *result = extractDataFromStackViewPopup(vcToPresent.view, [taskName substringToIndex:2]); // 用"毕法", "格局"等关键词
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

@interface UIView (EchoLogGestures) /* ... */ @end
@implementation UIView (EchoLogGestures) /* ... */ @end

%hook UIViewController

- (void)viewDidLoad { %orig; Class targetClass = NSClassFromString(@"六壬大占.ViewController"); if (targetClass && [self isKindOfClass:targetClass]) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ CreateLogUI(self.view.window); UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem]; testButton.frame = CGRectMake(10, 50, 160, 40); testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14]; [testButton setTitle:@"运行模拟点击测试" forState:UIControlStateNormal]; testButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1.0]; [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; testButton.layer.cornerRadius = 20; [testButton addTarget:self action:@selector(runEchoSimulateTapTests) forControlEvents:UIControlEventTouchUpInside]; [self.view.window addSubview:testButton]; }); } }

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
            for (UIGestureRecognizer *gesture in label.gestureRecognizers) {
                if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
                    hasTapGesture = YES;
                    break;
                }
            }
             // 还需要检查父视图的手势
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
             viewToTap = viewToTap.superview;
             for (UIGestureRecognizer *gesture in viewToTap.gestureRecognizers) {
                if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
                    tapGesture = (UITapGestureRecognizer *)gesture;
                    break;
                }
            }
        }
        
        if (tapGesture) {
            // 通过运行时获取手势绑定的 action 和 target
            id target = [tapGesture valueForKey:@"_targets"];
            if (target && [target count] > 0) {
                id targetProxy = target[0];
                id realTarget = [targetProxy valueForKey:@"_target"];
                SEL action = NSSelectorFromString([NSStringFromSelector([targetProxy action]) stringByReplacingOccurrencesOfString:@":" withString:@""]);
                
                if (realTarget && action && [realTarget respondsToSelector:action]) {
                    LogTestMessage(@"成功触发手势 Action: %@ on Target: %@", NSStringFromSelector(action), realTarget);
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [realTarget performSelector:action withObject:tapGesture];
                    #pragma clang diagnostic pop
                } else {
                     LogTestMessage(@"错误：无法触发手势，target或action无效。");
                }
            }
        } else {
             LogTestMessage(@"错误：在 '%@' 及其父视图上未找到可用的Tap手势。", targetLabel.text);
        }
    } else {
        LogTestMessage(@"错误：未能定位到包含 '%@' 的可点击标签。", searchText);
        // 如果找不到，需要重置状态
         if ([searchText isEqualToString:@"毕法"]) { g_isExtractingBiFa = NO; g_biFa_completion = nil; }
         else if ([searchText isEqualToString:@"格局"]) { g_isExtractingGeJu = NO; g_geJu_completion = nil; }
         else if ([searchText isEqualToString:@"方法"]) { g_isExtractingFangFa = NO; g_fangFa_completion = nil; }
    }
}
%end

%ctor { @autoreleasepool { MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController); } }
