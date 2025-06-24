#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与调试工具 (无需修改)
// =========================================================================
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray<NSDictionary*> *g_keChuanWorkQueue = nil;
static NSMutableArray *g_keChuanTitleQueue = nil;

static UITextView *g_debugTextView = nil;

static void setupDebugWindow(UIWindow *keyWindow) {
    if (g_debugTextView) { 
        for(UIView *subview in g_debugTextView.superview.subviews) {
            if(subview.tag == 556691 || subview == g_debugTextView) {
                [subview removeFromSuperview];
            }
        }
        g_debugTextView = nil;
    }
    g_debugTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 50, keyWindow.bounds.size.width - 20, keyWindow.bounds.size.height * 0.4)];
    g_debugTextView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    g_debugTextView.textColor = [UIColor systemGreenColor];
    g_debugTextView.font = [UIFont fontWithName:@"Menlo" size:10];
    g_debugTextView.editable = NO;
    g_debugTextView.layer.borderColor = [UIColor systemGreenColor].CGColor;
    g_debugTextView.layer.borderWidth = 1.0;
    g_debugTextView.layer.cornerRadius = 8;
    g_debugTextView.text = @"[调试日志窗口]\n";
    [keyWindow addSubview:g_debugTextView];

    UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    clearButton.tag = 556691;
    clearButton.frame = CGRectMake(g_debugTextView.frame.origin.x + g_debugTextView.frame.size.width - 60, g_debugTextView.frame.origin.y + 5, 55, 20);
    [clearButton setTitle:@"清空日志" forState:UIControlStateNormal];
    [clearButton.titleLabel setFont:[UIFont systemFontOfSize:10]];
    [clearButton addTarget:g_debugTextView action:@selector(setText:) forControlEvents:UIControlEventTouchUpInside];
    [keyWindow addSubview:clearButton];
}

static void logDebug(NSString *format, ...) {
    if (!g_debugTextView) return;
    va_list args;
    va_start(args, format);
    NSString *logMessage = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *newText = [g_debugTextView.text stringByAppendingFormat:@"%@\n", logMessage];
        g_debugTextView.text = newText;
        [g_debugTextView scrollRangeToVisible:NSMakeRange(g_debugTextView.text.length - 1, 1)];
    });
    NSLog(@"[课传提取] %@", logMessage);
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)performKeChuanDetailExtractionTest_Truth;
- (void)processKeChuanQueue_Truth;
@end

%hook UIViewController

// --- viewDidLoad & presentViewController (无需修改) ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger TestButtonTag = 556690;
            if ([keyWindow viewWithTag:TestButtonTag]) { [[keyWindow viewWithTag:TestButtonTag] removeFromSuperview]; }
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"提取(最终修正版)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemBlueColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        logDebug(@"拦截到弹窗: %@", vcClassName);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            logDebug(@"  -> 匹配成功，准备提取内容...");
            viewControllerToPresent.view.alpha = 0.0f; flag = NO;
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
                for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; } }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                logDebug(@"  -> 内容提取完毕，关闭弹窗并处理下一个任务。");
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{ [self processKeChuanQueue_Truth]; }];
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
// --- performKeChuanDetailExtractionTest_Truth: 精确查找UILabel上的手势 (全新逻辑) ---
- (void)performKeChuanDetailExtractionTest_Truth {
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];

    setupDebugWindow(self.view.window);
    logDebug(@"=== 开始提取流程 (策略: 精确查找UILabel上的手势) ===");

    // 辅助函数：为指定的UILabel创建任务
    void (^createTaskForLabel)(UILabel*, NSString*) = 
    ^(UILabel *label, NSString *title) {
        if (!label) {
            logDebug(@"错误: 尝试为 '%@' 创建任务，但UILabel为nil", title);
            return;
        }

        logDebug(@"正在为UILabel(text='%@')寻找手势...", label.text);
        
        UITapGestureRecognizer *foundRecognizer = nil;
        for (UIGestureRecognizer *recognizer in label.gestureRecognizers) {
            if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
                foundRecognizer = (UITapGestureRecognizer *)recognizer;
                break;
            }
        }

        if (foundRecognizer) {
            logDebug(@"  -> 成功在UILabel上找到手势: %@", foundRecognizer);
            id targets = [foundRecognizer valueForKey:@"_targets"];
            if (targets && [targets count] > 0) {
                id target_object = targets[0];
                id target = [target_object valueForKey:@"_target"];
                SEL action = (SEL)[[target_object valueForKey:@"_action"] pointerValue];

                if (target && action) {
                    NSDictionary *workItem = @{
                        @"target": target,
                        @"action": [NSValue valueWithPointer:action],
                        @"sender": foundRecognizer
                    };
                    [g_keChuanWorkQueue addObject:workItem];
                    [g_keChuanTitleQueue addObject:title];
                    logDebug(@"  -> 成功创建任务: Title='%@', Target='%@', Action='%@'", title, [target class], NSStringFromSelector(action));
                } else {
                    logDebug(@"  -> 严重错误: 从手势中提取target/action失败。");
                }
            } else {
                logDebug(@"  -> 严重错误: 手势 %@ 没有任何targets。", foundRecognizer);
            }
        } else {
            logDebug(@"  -> 警告: 在UILabel(text='%@')上未找到任何UITapGestureRecognizer。", label.text);
        }
    };

    // Part A: 三传
    logDebug(@"--- 正在扫描三传 ---");
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanContainerClass) {
        NSMutableArray *containers = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, containers);
        if (containers.count > 0) {
            UIView *sanChuanContainer = containers.firstObject;
            const char *ivarNames[] = {"初傳", "中傳", "末傳", NULL};
            NSString *rowTitles[] = {@"初传", @"中传", @"末传"};
            for (int i = 0; ivarNames[i] != NULL; ++i) {
                Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, ivarNames[i]);
                if (ivar) {
                    UIView *chuanView = object_getIvar(sanChuanContainer, ivar);
                    if (chuanView) {
                        NSMutableArray *labels = [NSMutableArray array];
                        FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
                        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
                        if(labels.count >= 2) {
                            UILabel *dizhiLabel = labels[labels.count-2];
                            UILabel *tianjiangLabel = labels[labels.count-1];
                            
                            createTaskForLabel(dizhiLabel, [NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]);
                            createTaskForLabel(tianjiangLabel, [NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]);
                        }
                    }
                }
            }
        }
    } else { logDebug(@"错误: 未找到三传容器类 '六壬大占.三傳視圖'"); }
    
    // Part B: 四课
    logDebug(@"--- 正在扫描四课 ---");
    Class siKeContainerClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeContainerClass) {
        NSMutableArray *containers = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeContainerClass, self.view, containers);
        if (containers.count > 0) {
            UIView *siKeContainer = containers.firstObject;
            const char *ivarNames[] = {"第一課", "第二課", "第三課", "第四課", NULL};
            NSString *rowTitles[] = {@"第一课", @"第二课", @"第三课", @"第四课"};
            for (int i = 0; ivarNames[i] != NULL; ++i) {
                Ivar ivar = class_getInstanceVariable(siKeContainerClass, ivarNames[i]);
                if (ivar) {
                    UIView *keView = object_getIvar(siKeContainer, ivar);
                    if (keView) {
                        NSMutableArray *labels = [NSMutableArray array];
                        FindSubviewsOfClassRecursive([UILabel class], keView, labels);
                        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
                         if(labels.count >= 2) {
                            UILabel *dizhiLabel = labels[labels.count-2];
                            UILabel *tianjiangLabel = labels[labels.count-1];
                            
                            createTaskForLabel(dizhiLabel, [NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]);
                            createTaskForLabel(tianjiangLabel, [NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]);
                        }
                    }
                }
            }
        }
    } else { logDebug(@"错误: 未找到四课容器类 '六壬大占.四課視圖'"); }

    if (g_keChuanWorkQueue.count == 0) { 
        logDebug(@"!!! 严重错误: 未能创建任何任务，流程中止。请检查日志中的警告信息。");
        g_isExtractingKeChuanDetail = NO; 
        return; 
    }

    logDebug(@"=== 扫描完成，共创建 %lu 个任务，开始处理队列 ===", (unsigned long)g_keChuanWorkQueue.count);
    [self processKeChuanQueue_Truth];
}

%new
// --- processKeChuanQueue_Truth: (无需修改) ---
- (void)processKeChuanQueue_Truth {
    if (g_keChuanWorkQueue.count == 0) {
        logDebug(@"=== 所有任务处理完毕 ===");
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        logDebug(@"结果已生成，准备复制到剪贴板并显示成功提示。");
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"所有详情已复制到剪贴板。调试窗口将自动关闭。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
            if (g_debugTextView) {
                // Safely remove debug window and its button
                for(UIView *subview in g_debugTextView.superview.subviews) {
                    if(subview.tag == 556691 || subview == g_debugTextView) {
                        [subview removeFromSuperview];
                    }
                }
                g_debugTextView = nil;
            }
        }]];
        [self presentViewController:successAlert animated:YES completion:nil];
        
        g_isExtractingKeChuanDetail = NO;
        g_keChuanWorkQueue = nil;
        g_capturedKeChuanDetailArray = nil;
        g_keChuanTitleQueue = nil;
        return;
    }
    
    NSDictionary *workItem = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    NSString *title = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];
    logDebug(@"\n--- 处理任务 (%lu/%lu): %@ ---", g_capturedKeChuanDetailArray.count + 1, g_keChuanTitleQueue.count, title);

    id target = workItem[@"target"];
    SEL action = [workItem[@"action"] pointerValue];
    id sender = workItem[@"sender"]; 

    if (target && action && [target respondsToSelector:action]) {
        logDebug(@"即将调用: [<%@: %p> %@]", [target class], target, NSStringFromSelector(action));
        logDebug(@"  -> sender 为: <%@: %p>", [sender class], sender);

        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [target performSelector:action withObject:sender];
        #pragma clang diagnostic pop
    } else {
        logDebug(@"!!! 错误: 无法执行任务。Target 或 Action 无效。");
        logDebug(@"  -> Target: %@", target);
        logDebug(@"  -> Action: %@", NSStringFromSelector(action));
        logDebug(@"  -> Responds: %d", [target respondsToSelector:action]);
        [g_capturedKeChuanDetailArray addObject:[NSString stringWithFormat:@"[任务执行失败 - Target:%@ Action:%@]", target, NSStringFromSelector(action)]];
        [self processKeChuanQueue_Truth];
    }
}
%end
