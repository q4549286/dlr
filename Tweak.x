#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray<UIView *> *g_keChuanWorkQueue = nil; // 明确类型为UIView
static NSMutableArray<NSString *> *g_keChuanTitleQueue = nil;

// 新增：日志视图和控制面板
static UITextView *g_logTextView = nil;
static UIView *g_controlPanelView = nil;

// 日志记录函数
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

// 递归查找视图
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
            if ([keyWindow viewWithTag:controlButtonTag]) { return; } // 如果已存在则不创建
            
            UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
            controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            controlButton.tag = controlButtonTag;
            [controlButton setTitle:@"提取工具(日志版)" forState:UIControlStateNormal];
            controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            controlButton.backgroundColor = [UIColor systemBlueColor];
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
            
            viewControllerToPresent.view.alpha = 0.0f; // 隐藏弹窗，加快速度
            flag = NO;
            
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                
                // 按Y坐标、再按X坐标排序，确保文本顺序正确
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
                
                // 关闭当前弹窗，并在关闭后处理下一个
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    // 【【【最关键的修正】】】
                    // 增加0.2秒延迟，给主VC足够的时间重置状态
                    LogMessage(@"弹窗已关闭，延迟 0.2s 后处理下一个...");
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
        [g_controlPanelView removeFromSuperview];
        g_controlPanelView = nil;
        g_logTextView = nil;
        return;
    }

    g_controlPanelView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, keyWindow.bounds.size.width - 20, keyWindow.bounds.size.height - 150)];
    g_controlPanelView.tag = panelTag;
    g_controlPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
    g_controlPanelView.layer.cornerRadius = 12;
    g_controlPanelView.clipsToBounds = YES;
    
    // 开始按钮
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    startButton.frame = CGRectMake(10, 10, 120, 40);
    [startButton setTitle:@"开始自动提取" forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(startExtraction_Truth) forControlEvents:UIControlEventTouchUpInside];
    startButton.backgroundColor = [UIColor systemGreenColor];
    [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    startButton.layer.cornerRadius = 8;

    // 复制并关闭按钮
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(140, 10, 120, 40);
    [copyButton setTitle:@"复制并关闭" forState:UIControlStateNormal];
    [copyButton addTarget:self action:@selector(copyAndClose_Truth) forControlEvents:UIControlEventTouchUpInside];
    copyButton.backgroundColor = [UIColor systemOrangeColor];
    [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyButton.layer.cornerRadius = 8;
    
    // 日志视图
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 60, g_controlPanelView.bounds.size.width - 20, g_controlPanelView.bounds.size.height - 70)];
    g_logTextView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    g_logTextView.textColor = [UIColor systemGreenColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO;
    g_logTextView.layer.cornerRadius = 8;
    g_logTextView.text = @"日志控制台已准备就绪。\n";
    
    [g_controlPanelView addSubview:startButton];
    [g_controlPanelView addSubview:copyButton];
    [g_controlPanelView addSubview:g_logTextView];
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
    } else {
        LogMessage(@"没有可复制的内容。");
    }
    
    if (g_controlPanelView) {
        [g_controlPanelView removeFromSuperview];
        g_controlPanelView = nil;
        g_logTextView = nil;
    }
}


%new
// --- startExtraction_Truth: 构建任务队列 ---
- (void)startExtraction_Truth {
    if (g_isExtractingKeChuanDetail) {
        LogMessage(@"错误：提取任务已在进行中。");
        return;
    }
    
    LogMessage(@"开始提取任务...");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
  
    // Part A: 三传
    LogMessage(@"正在查找三传视图...");
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanContainerClass) {
        NSMutableArray *containers = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, containers);
        if (containers.count > 0) {
            UIView *sanChuanContainer = containers.firstObject;
            LogMessage(@"找到三传容器: %@", sanChuanContainer);
          
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
                          
                            [g_keChuanWorkQueue addObject:dizhiLabel];
                            NSString *dizhiTitle = [NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text];
                            [g_keChuanTitleQueue addObject:dizhiTitle];
                            LogMessage(@"已入队: %@", dizhiTitle);

                            [g_keChuanWorkQueue addObject:tianjiangLabel];
                            NSString *tianjiangTitle = [NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text];
                            [g_keChuanTitleQueue addObject:tianjiangTitle];
                            LogMessage(@"已入队: %@", tianjiangTitle);
                        }
                    }
                }
            }
        } else { LogMessage(@"未找到三传容器。"); }
    } else { LogMessage(@"找不到类: 六壬大占.三傳視圖"); }
  
    // Part B: 四课 (补全此部分逻辑)
    LogMessage(@"正在查找四课视图...");
    Class siKeContainerClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeContainerClass) {
        NSMutableArray *containers = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeContainerClass, self.view, containers);
        if (containers.count > 0) {
            UIView *siKeContainer = containers.firstObject;
            LogMessage(@"找到四课容器: %@", siKeContainer);
            
            // 注意：四课的ivar名可能是繁体中文，并且顺序可能需要调整
            const char *ivarNames[] = {"第四課", "第三課", "第二課", "第一課", NULL}; // 通常从右到左，所以是4,3,2,1
            NSString *rowTitles[] = {@"第四课", @"第三课", @"第二课", @"第一课"};

            for (int i = 0; ivarNames[i] != NULL; ++i) {
                Ivar ivar = class_getInstanceVariable(siKeContainerClass, ivarNames[i]);
                if (ivar) {
                    UIView *keView = object_getIvar(siKeContainer, ivar);
                    if (keView) {
                        NSMutableArray *labels = [NSMutableArray array];
                        FindSubviewsOfClassRecursive([UILabel class], keView, labels);
                        // 四课的UILabel是上下排列的
                        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                        if (labels.count >= 2) {
                            UILabel *tianjiangLabel = labels[0]; // 天将在上面
                            UILabel *dizhiLabel = labels[1]; // 地支在下面

                            [g_keChuanWorkQueue addObject:dizhiLabel];
                            NSString *dizhiTitle = [NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text];
                            [g_keChuanTitleQueue addObject:dizhiTitle];
                            LogMessage(@"已入队: %@", dizhiTitle);

                            [g_keChuanWorkQueue addObject:tianjiangLabel];
                            NSString *tianjiangTitle = [NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text];
                            [g_keChuanTitleQueue addObject:tianjiangTitle];
                            LogMessage(@"已入队: %@", tianjiangTitle);
                        }
                    } else { LogMessage(@"获取 ivar '%s' 的视图失败", ivarNames[i]); }
                } else { LogMessage(@"找不到 ivar '%s'", ivarNames[i]); }
            }
        } else { LogMessage(@"未找到四课容器。"); }
    } else { LogMessage(@"找不到类: 六壬大占.四課視圖"); }


    if (g_keChuanWorkQueue.count == 0) {
        LogMessage(@"队列为空，未找到任何可提取项。任务中止。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    
    LogMessage(@"任务队列构建完成，总计 %lu 项。开始处理...", (unsigned long)g_keChuanWorkQueue.count);
    [self processKeChuanQueue_Truth];
}

%new
// --- processKeChuanQueue_Truth: 处理队列中的下一个任务 ---
- (void)processKeChuanQueue_Truth {
    // 检查是否应该停止
    if (!g_isExtractingKeChuanDetail || g_keChuanWorkQueue.count == 0) {
        if (g_isExtractingKeChuanDetail) { // 只有在正常完成时才弹窗
            LogMessage(@"全部任务处理完毕！");
            
            UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"所有详情已自动复制，请关闭此工具后粘贴查看。" preferredStyle:UIAlertControllerStyleAlert];
            [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                // 自动复制
                [self copyAndClose_Truth];
            }]];
            [self presentViewController:successAlert animated:YES completion:nil];
        }
        
        // 重置状态
        g_isExtractingKeChuanDetail = NO;
        return;
    }
  
    UIView *itemToClick = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
  
    NSString *title = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];
    LogMessage(@"正在处理: %@ (队列剩余 %lu)", title, (unsigned long)g_keChuanWorkQueue.count);

    SEL actionToPerform = nil;
    if ([title containsString:@"地支"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    } else {
        actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    }
  
    if ([self respondsToSelector:actionToPerform]) {
        LogMessage(@"触发点击事件: %@, sender: %@", NSStringFromSelector(actionToPerform), itemToClick);
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:itemToClick];
        #pragma clang diagnostic pop
    } else {
        LogMessage(@"错误: VC 不响应 %@。跳过此项。", NSStringFromSelector(actionToPerform));
        [g_capturedKeChuanDetailArray addObject:@"[错误: 无法调用点击方法]"]; // 添加一个占位符
        // 如果不响应，也要手动驱动队列继续，否则会卡住
        [self processKeChuanQueue_Truth];
    }
}

%end
