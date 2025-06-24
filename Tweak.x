您好，非常抱歉！“点击闪退”是比之前所有问题都更严重的错误，我为我代码中的疏忽给您带来的不便深表歉悔。

您遇到的闪退问题，根源在于我们上一版代码中一个非常“激进”的操作。

### 闪退原因分析

我们上一版的代码试图通过Key-Value Coding (KVC)的方式来访问 `UIGestureRecognizer` 的私有内部属性（如 `targets`, `action` 等）。

```objc
// 这是上一版有问题的代码
NSArray *targets = [gesture valueForKey:@"targets"];
id gestureTarget = targets.firstObject;
id target = [gestureTarget valueForKey:@"target"];
NSString *actionString = [gestureTarget valueForKey:@"action"];
SEL action = NSSelectorFromString(actionString);
[target performSelector:action withObject:gesture];
```

这种方法极其**不稳定**和**危险**，因为它依赖于苹果没有公开、随时可能改变的内部实现。闪退的发生，几乎可以肯定是以下原因之一：

1.  **内部结构不符**：在您的iOS版本或设备上，`UIGestureRecognizer` 的内部结构可能和我们预想的不一样。例如，`valueForKey:@"targets"` 可能返回了 `nil` 或者不是一个数组，导致后续的 `targets.firstObject` 操作访问了空指针，直接闪退。
2.  **类型不匹配**：`valueForKey:@"action"` 返回的可能不是一个 `NSString`，当我们把它强行传给 `NSSelectorFromString` 时，引发了类型错误，导致闪退。

### 最终解决方案：使用 `@try/@catch` 保护并回退

既然直接模拟手势如此危险，我们需要一个更安全、更健壮的方案。

1.  **终极保护 `@try/@catch`**：我们将在最危险的代码块周围包裹一个 `@try/@catch` 语句。这是一个强大的工具，**即使内部代码发生致命错误（比如我们遇到的闪退），它也能捕获这个异常，阻止App崩溃**，然后执行 `@catch` 里的代码，让我们有机会记录错误并继续执行下去。
2.  **增加安全检查**：在使用任何通过KVC获取的值之前，都进行严格的类型和非空检查。
3.  **失败时的备用方案 (Fallback)**：如果模拟手势失败，我们会回退到我们最开始使用的、虽然有内容重复问题但不会崩溃的方法 (`performSelector:withObject:`)。这样至少能保证程序运行。

这样修改后，代码的健壮性会大大提高。它会优先尝试最有效的方法（模拟手势），如果失败，则会自动切换到备用方案，并记录下详细的错误日志，而不会让整个应用崩溃。

---

### 【最终修复版代码】请替换您的Tweak文件

这是我能提供的最稳定和最安全的版本。它应该能彻底解决闪退问题。

```objc
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray<UIView *> *g_keChuanWorkQueue = nil;
static NSMutableArray<NSString *> *g_keChuanTitleQueue = nil;

static UITextView *g_logTextView = nil;
static UIView *g_controlPanelView = nil;

static void LogMessage(NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss.SSS"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSString *fullMessage = [logPrefix stringByAppendingString:message];
        g_logTextView.text = [NSString stringWithFormat:@"%@\n%@", fullMessage, g_logTextView.text];
        NSLog(@"[KeChuanExtractor] %@", message);
    });
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)startExtraction_Truth;
- (void)processKeChuanQueue_Truth;
- (void)createOrShowControlPanel_Truth;
- (void)copyAndClose_Truth;
- (void)triggerActionOnView:(UIView *)view withTitle:(NSString *)title;
@end

%hook UIViewController

// --- viewDidLoad: 创建控制面板触发按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger controlButtonTag = 556691;
            if ([keyWindow viewWithTag:controlButtonTag]) { [[keyWindow viewWithTag:controlButtonTag] removeFromSuperview]; }
          
            UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
            controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            controlButton.tag = controlButtonTag;
            [controlButton setTitle:@"提取工具(最终版)" forState:UIControlStateNormal];
            controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            controlButton.backgroundColor = [UIColor systemIndigoColor];
            [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            controlButton.layer.cornerRadius = 8;
            [controlButton addTarget:self action:@selector(createOrShowControlPanel_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:controlButton];
        });
    }
}

// --- presentViewController: 捕获弹窗并驱动队列 ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            LogMessage(@"捕获到弹窗: %@", vcClassName);
          
            viewControllerToPresent.view.alpha = 0.0f; 
            flag = NO;
          
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
              
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
              
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
              
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) {
                        [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
              
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                LogMessage(@"成功提取内容 (共 %lu 条)", (unsigned long)g_capturedKeChuanDetailArray.count);
              
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    LogMessage(@"弹窗已关闭，延迟 0.1s 后处理下一个...");
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processKeChuanQueue_Truth];
                    });
                }];
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
// --- 创建控制面板 ---
- (void)createOrShowControlPanel_Truth {
    UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
    NSInteger panelTag = 556692;
    if (g_controlPanelView && g_controlPanelView.superview) {
        [g_controlPanelView removeFromSuperview]; g_controlPanelView = nil; g_logTextView = nil; return;
    }

    g_controlPanelView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, keyWindow.bounds.size.width - 20, keyWindow.bounds.size.height - 150)];
    g_controlPanelView.tag = panelTag;
    g_controlPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
    g_controlPanelView.layer.cornerRadius = 12; g_controlPanelView.clipsToBounds = YES;
  
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    startButton.frame = CGRectMake(10, 10, 120, 40);
    [startButton setTitle:@"开始自动提取" forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(startExtraction_Truth) forControlEvents:UIControlEventTouchUpInside];
    startButton.backgroundColor = [UIColor systemGreenColor]; [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; startButton.layer.cornerRadius = 8;

    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(140, 10, 120, 40);
    [copyButton setTitle:@"复制并关闭" forState:UIControlStateNormal];
    [copyButton addTarget:self action:@selector(copyAndClose_Truth) forControlEvents:UIControlEventTouchUpInside];
    copyButton.backgroundColor = [UIColor systemOrangeColor]; [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; copyButton.layer.cornerRadius = 8;
  
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 60, g_controlPanelView.bounds.size.width - 20, g_controlPanelView.bounds.size.height - 70)];
    g_logTextView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0]; g_logTextView.textColor = [UIColor systemGreenColor]; g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12]; g_logTextView.editable = NO; g_logTextView.layer.cornerRadius = 8; g_logTextView.text = @"日志控制台已准备就绪。\n";
  
    [g_controlPanelView addSubview:startButton]; [g_controlPanelView addSubview:copyButton]; [g_controlPanelView addSubview:g_logTextView];
    [keyWindow addSubview:g_controlPanelView];
}

%new
// --- 复制结果并关闭面板 ---
- (void)copyAndClose_Truth {
    if (g_capturedKeChuanDetailArray && g_capturedKeChuanDetailArray.count > 0 && g_keChuanTitleQueue && g_keChuanTitleQueue.count > 0) {
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        LogMessage(@"结果已复制到剪贴板！");
    } else { LogMessage(@"没有可复制的内容。"); }
  
    if (g_controlPanelView) {
        [g_controlPanelView removeFromSuperview]; g_controlPanelView = nil; g_logTextView = nil;
    }
}


%new
// --- startExtraction_Truth: 构建任务队列 ---
- (void)startExtraction_Truth {
    if (g_isExtractingKeChuanDetail) { LogMessage(@"错误：提取任务已在进行中。"); return; }
  
    LogMessage(@"开始提取任务...");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array]; g_keChuanWorkQueue = [NSMutableArray array]; g_keChuanTitleQueue = [NSMutableArray array];

    // Part A: 三传
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanContainerClass) {
        NSMutableArray *containers = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, containers);
        if (containers.count > 0) {
            UIView *sanChuanContainer = containers.firstObject; const char *ivarNames[] = {"初傳", "中傳", "末傳", NULL}; NSString *rowTitles[] = {@"初传", @"中传", @"末传"};
            for (int i = 0; ivarNames[i] != NULL; ++i) {
                Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, ivarNames[i]); if (!ivar) continue;
                UIView *chuanView = object_getIvar(sanChuanContainer, ivar); if (!chuanView) continue;
                NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
                [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
                if(labels.count >= 2) {
                    UILabel *dizhiLabel = labels[labels.count-2]; UILabel *tianjiangLabel = labels[labels.count-1];
                    [g_keChuanWorkQueue addObject:dizhiLabel]; [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                    [g_keChuanWorkQueue addObject:tianjiangLabel]; [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
                }
            }
        }
    }

    // Part B: 四课
    Class siKeContainerClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeContainerClass) {
        NSMutableArray *containers = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeContainerClass, self.view, containers);
        if (containers.count > 0) {
            UIView *siKeContainer = containers.firstObject; const char *ivarNames[] = {"第四課", "第三課", "第二課", "第一課", NULL}; NSString *rowTitles[] = {@"第四课", @"第三课", @"第二课", @"第一课"};
            for (int i = 0; ivarNames[i] != NULL; ++i) {
                Ivar ivar = class_getInstanceVariable(siKeContainerClass, ivarNames[i]); if (!ivar) continue;
                UIView *keView = object_getIvar(siKeContainer, ivar); if (!keView) continue;
                NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], keView, labels);
                [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                if (labels.count >= 2) {
                    UILabel *tianjiangLabel = labels[0]; UILabel *dizhiLabel = labels[1];
                    [g_keChuanWorkQueue addObject:dizhiLabel]; [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                    [g_keChuanWorkQueue addObject:tianjiangLabel]; [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
                }
            }
        }
    }

    if (g_keChuanWorkQueue.count == 0) {
        LogMessage(@"队列为空，未找到任何可提取项。任务中止。"); g_isExtractingKeChuanDetail = NO; return;
    }
  
    LogMessage(@"任务队列构建完成，总计 %lu 项。开始处理...", (unsigned long)g_keChuanWorkQueue.count);
    [self processKeChuanQueue_Truth];
}

%new
- (void)processKeChuanQueue_Truth {
    if (!g_isExtractingKeChuanDetail || g_keChuanWorkQueue.count == 0) {
        if (g_isExtractingKeChuanDetail) {
            LogMessage(@"全部任务处理完毕！");
            UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"所有详情已提取。请点击“复制并关闭”按钮来获取结果。" preferredStyle:UIAlertControllerStyleAlert];
            [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:successAlert animated:YES completion:nil];
        }
        g_isExtractingKeChuanDetail = NO; return;
    }

    UIView *itemToClick = g_keChuanWorkQueue.firstObject; [g_keChuanWorkQueue removeObjectAtIndex:0];
    NSString *title = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];
    LogMessage(@"正在处理: %@", title);

    [self triggerActionOnView:itemToClick withTitle:title];
}

%new
// 【【【核心修正：带崩溃保护的点击方法】】】
- (void)triggerActionOnView:(UIView *)view withTitle:(NSString *)title {
    @try {
        if (!view || !view.gestureRecognizers || view.gestureRecognizers.count == 0) {
            @throw [NSException exceptionWithName:@"NoGesture" reason:@"视图上没有手势识别器" userInfo:nil];
        }

        BOOL triggered = NO;
        for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
            // 使用KVC获取私有属性_targets，这是一个存放手势目标的数组
            id targets = [gesture valueForKey:@"targets"];
            if (!targets || ![targets isKindOfClass:NSArray.class] || ((NSArray *)targets).count == 0) {
                continue; // 此手势没有目标，跳到下一个
            }
          
            id gestureTarget = [targets firstObject];
            id target = [gestureTarget valueForKey:@"target"];
            NSString *actionString = [gestureTarget valueForKey:@"action"];

            if (!target || !actionString || ![actionString isKindOfClass:NSString.class]) {
                continue; // 目标或方法名无效，跳到下一个
            }

            SEL action = NSSelectorFromString(actionString);
            if ([target respondsToSelector:action]) {
                LogMessage(@"[尝试方案A] 触发手势: Target=%@, Action=%@", target, actionString);
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [target performSelector:action withObject:gesture];
                #pragma clang diagnostic pop
                triggered = YES;
                break; // 成功触发，跳出循环
            }
        }
      
        if (!triggered) {
            @throw [NSException exceptionWithName:@"TriggerFailed" reason:@"无法触发任何有效的手势动作" userInfo:nil];
        }

    } @catch (NSException *exception) {
        LogMessage(@"[方案A失败] 触发手势时发生异常: %@。将尝试备用方案。", exception.reason);
      
        // -----------------------------------------------------------
        // 备用方案 (Fallback Plan)
        // -----------------------------------------------------------
        // 如果模拟手势失败（比如崩溃），我们就回退到之前直接调用方法的方式
        // 这可能会导致内容重复，但至少不会让程序崩溃。
        SEL fallbackAction = nil;
        if ([title containsString:@"地支"]) {
            fallbackAction = NSSelectorFromString(@"顯示課傳摘要WithSender:");
        } else {
            fallbackAction = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
        }
      
        if ([self respondsToSelector:fallbackAction]) {
            LogMessage(@"[执行方案B] 直接调用方法: %@", NSStringFromSelector(fallbackAction));
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self performSelector:fallbackAction withObject:view];
            #pragma clang diagnostic pop
        } else {
            LogMessage(@"[方案B失败] 备用方法也不存在。此项提取失败。");
            [g_capturedKeChuanDetailArray addObject:[NSString stringWithFormat:@"[提取失败: %@]", exception.reason]];
            [self processKeChuanQueue_Truth]; // 手动驱动队列继续
        }
    }
}

%end
```
