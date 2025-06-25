// Filename: CombinedExtractor_v2.0
// 描述: 优化版，解决了内容丢失和格式化问题。
// 1. 完整提取所有层级内容。
// 2. 智能识别“标题-正文”结构。
// 3. 对“详解”部分进行特殊的 Key→Value 格式化。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =================================================================
// 1. 全局变量与辅助函数 (保持不变)
// =================================================================

// --- 状态控制 ---
static BOOL g_isExtracting = NO;
static NSString *g_currentTaskType = nil;

// --- “课体”批量提取专用变量 ---
static NSMutableArray *g_keTi_workQueue = nil;
static NSMutableArray *g_keTi_resultsArray = nil;
static UICollectionView *g_keTi_targetCV = nil;

// --- UI ---
static UITextView *g_logView = nil;

// 辅助函数：递归查找子视图
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// 统一日志函数
static void LogMessage(NSString *format, ...) {
    if (!g_logView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        g_logView.text = [NSString stringWithFormat:@"%@%@\n%@", logPrefix, message, g_logView.text];
        NSLog(@"[CombinedExtractor] %@", message);
    });
}

// =================================================================
// 2. 核心的Hook与队列处理逻辑 (已更新)
// =================================================================

static void processKeTiWorkQueue(void);

// ================== 新增的核心提取函数 ==================
// 这个函数是解决问题的关键
static NSString* extractAndFormatContentFromView_v2(UIView *contentView) {
    NSMutableArray *allLabels = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
    
    // 按垂直位置排序，确保文本顺序正确
    [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
        if (roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
        if (roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
        return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
    }];

    NSMutableArray<NSString *> *formattedBlocks = [NSMutableArray array];
    NSMutableString *currentContent = [NSMutableString string];
    NSString *currentTitle = nil;
    BOOL inXiangJieSection = NO; // 特殊标记，是否进入了“详解”部分

    for (UILabel *label in allLabels) {
        if (!label.text || label.text.length == 0) continue;
        
        // 关键逻辑：通过字体是否为粗体来判断是否为标题
        BOOL isTitle = (label.font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) != 0;
        NSString *labelText = label.text;

        if (isTitle) {
            // 遇到了一个新的标题，先把之前缓存的标题和内容保存起来
            if (currentTitle) {
                NSString *trimmedContent = [currentContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (trimmedContent.length > 0) {
                    if (inXiangJieSection) {
                        // 在详解部分，使用 -> 连接
                        [formattedBlocks addObject:[NSString stringWithFormat:@"%@→%@", currentTitle, trimmedContent]];
                    } else {
                        // 在普通部分，使用换行连接
                        [formattedBlocks addObject:[NSString stringWithFormat:@"%@\n%@", currentTitle, trimmedContent]];
                    }
                } else {
                    // 如果标题下没有内容，也单独记录标题
                     [formattedBlocks addObject:currentTitle];
                }
            }

            // 更新当前标题并重置内容缓存
            currentTitle = labelText;
            [currentContent setString:@""];

            // 检查是否进入或退出了“详解”部分
            if ([labelText isEqualToString:@"详解"]) {
                inXiangJieSection = YES;
                // 将“详解”本身作为一个大标题加进去
                [formattedBlocks addObject:@"\n--- 详解 ---"]; 
            }

        } else {
            // 如果是正文，追加到当前内容缓存
            if (currentContent.length > 0) {
                [currentContent appendString:@"\n"];
            }
            [currentContent appendString:labelText];
        }
    }
    
    // 不要忘记处理最后一个块
    if (currentTitle) {
        NSString *trimmedContent = [currentContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmedContent.length > 0) {
            if (inXiangJieSection) {
                [formattedBlocks addObject:[NSString stringWithFormat:@"%@→%@", currentTitle, trimmedContent]];
            } else {
                [formattedBlocks addObject:[NSString stringWithFormat:@"%@\n%@", currentTitle, trimmedContent]];
            }
        } else {
            [formattedBlocks addObject:currentTitle];
        }
    }

    return [formattedBlocks componentsJoinedByString:@"\n\n"];
}


// Hook：拦截弹窗事件 (已更新)
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    Class targetClass = NSClassFromString(@"六壬大占.課體概覽視圖");
    
    // 只在我们的提取任务执行时，才拦截目标窗口
    if (g_isExtracting && targetClass && [vcToPresent isKindOfClass:targetClass]) {
        vcToPresent.view.alpha = 0.0f; animated = NO;
        
        void (^extractionCompletion)(void) = ^{
            if (completion) { completion(); }

            // --- 使用新的、智能的提取函数 ---
            NSString *extractedText = extractAndFormatContentFromView_v2(vcToPresent.view);
            
            // --- 根据任务类型，决定如何处理提取到的文本 ---
            if ([g_currentTaskType isEqualToString:@"KeTi"]) {
                [g_keTi_resultsArray addObject:extractedText];
                LogMessage(@"成功提取“课体”第 %lu 项...", (unsigned long)g_keTi_resultsArray.count);
                [vcToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        processKeTiWorkQueue(); // 处理下一个课体
                    });
                }];
            } 
            else if ([g_currentTaskType isEqualToString:@"JiuZongMen"]) {
                LogMessage(@"成功提取“九宗门”详情！");
                [UIPasteboard generalPasteboard].string = extractedText;
                LogMessage(@"内容已复制到剪贴板！");
                g_isExtracting = NO; // 单次任务完成，重置总开关
                g_currentTaskType = nil;
                [vcToPresent dismissViewControllerAnimated:NO completion:nil];
            }
        };
        Original_presentViewController(self, _cmd, vcToPresent, animated, extractionCompletion);
    } else {
        Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
    }
}

// “课体”任务队列处理器 (保持不变)
static void processKeTiWorkQueue() {
    if (g_keTi_workQueue.count == 0) {
        LogMessage(@"所有 %lu 项“课体”任务处理完毕！", (unsigned long)g_keTi_resultsArray.count);
        NSMutableString *finalResult = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keTi_resultsArray.count; i++) {
            [finalResult appendFormat:@"--- 课体: %@ ---\n\n", g_keTi_resultsArray[i]];
        }
        [UIPasteboard generalPasteboard].string: [finalResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        LogMessage(@"“课体”批量提取完成，所有内容已合并并复制！");
        
        g_isExtracting = NO;
        g_currentTaskType = nil;
        g_keTi_targetCV = nil;
        g_keTi_workQueue = nil;
        g_keTi_resultsArray = nil;
        return;
    }
    
    NSIndexPath *indexPath = g_keTi_workQueue.firstObject;
    [g_keTi_workQueue removeObjectAtIndex:0];
    LogMessage(@"正在处理“课体”第 %lu/%lu 项...", (unsigned long)(g_keTi_resultsArray.count + 1), (unsigned long)(g_keTi_resultsArray.count + g_keTi_workQueue.count + 1));
    
    id delegate = g_keTi_targetCV.delegate;
    if (delegate && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
        [delegate collectionView:g_keTi_targetCV didSelectItemAtIndexPath:indexPath];
    }
}


// =================================================================
// 3. UI 和控制逻辑 (基本不变，可以继续使用您原来的)
// =================================================================

@interface UIViewController (CombinedExtractor)
- (void)setupCombinedExtractorPanel;
- (void)startKeTiExtraction;
- (void)startJiuZongMenExtraction;
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer;
@end

%hook UIViewController
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupCombinedExtractorPanel];
        });
    }
}

// setupCombinedExtractorPanel, startKeTiExtraction, startJiuZongMenExtraction, handlePanelPan 
// 这几个 %new 方法您可以直接使用您原来的版本，无需改动。
// 为了代码的完整性，我还是将它们附在下面。

%new
- (void)setupCombinedExtractorPanel {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) { keyWindow = scene.windows.firstObject; break; }
        }
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [[UIApplication sharedApplication] keyWindow];
        #pragma clang diagnostic pop
    }
    if (!keyWindow || [keyWindow viewWithTag:889900]) return;

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 350, 450)];
    panel.tag = 889900;
    panel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.92];
    panel.layer.cornerRadius = 12;
    panel.layer.borderColor = [UIColor systemRedColor].CGColor;
    panel.layer.borderWidth = 1.5;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 350, 20)];
    titleLabel.text = @"大六壬终极提取器 v2.0"; // 版本号+1
    titleLabel.textColor = [UIColor systemRedColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:titleLabel];

    UIButton *keTiButton = [UIButton buttonWithType:UIButtonTypeSystem];
    keTiButton.frame = CGRectMake(20, 50, panel.bounds.size.width - 40, 44);
    [keTiButton setTitle:@"一键提取全部课体" forState:UIControlStateNormal];
    [keTiButton addTarget:self action:@selector(startKeTiExtraction) forControlEvents:UIControlEventTouchUpInside];
    keTiButton.backgroundColor = [UIColor systemGreenColor];
    
    UIButton *jiuZongMenButton = [UIButton buttonWithType:UIButtonTypeSystem];
    jiuZongMenButton.frame = CGRectMake(20, 104, panel.bounds.size.width - 40, 44);
    [jiuZongMenButton setTitle:@"提取九宗门详情" forState:UIControlStateNormal];
    [jiuZongMenButton addTarget:self action:@selector(startJiuZongMenExtraction) forControlEvents:UIControlEventTouchUpInside];
    jiuZongMenButton.backgroundColor = [UIColor systemCyanColor];

    for (UIButton *btn in @[keTiButton, jiuZongMenButton]) {
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        btn.layer.cornerRadius = 8;
        [panel addSubview:btn];
    }

    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 160, panel.bounds.size.width - 20, panel.bounds.size.height - 170)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor whiteColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = NO;
    g_logView.layer.cornerRadius = 5;
    g_logView.text = @"终极提取器 v2.0 已就绪。";
    [panel addSubview:g_logView];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [panel addGestureRecognizer:pan];

    [keyWindow addSubview:panel];
}

%new
- (void)startKeTiExtraction {
    if (g_isExtracting) { LogMessage(@"错误：已有任务在进行中。"); return; }
    
    LogMessage(@"--- 开始“课体”批量提取任务 ---");

    UIWindow *keyWindow = self.view.window;
    if (!keyWindow) { LogMessage(@"错误: 找不到主窗口。"); return; }
    
    g_keTi_targetCV = nil;
    Class keTiCellClass = NSClassFromString(@"六壬大占.課體單元");
    if (!keTiCellClass) { LogMessage(@"错误: 找不到 '六壬大占.課體單元' 类。"); return; }
    
    NSMutableArray<UICollectionView *> *allCVs = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], keyWindow, allCVs);
    
    for (UICollectionView *cv in allCVs) {
        for (UICollectionViewCell *cell in cv.visibleCells) {
             if ([cell isKindOfClass:keTiCellClass]) {
                 g_keTi_targetCV = cv; break;
             }
        }
        if (g_keTi_targetCV) { break; }
    }

    if (!g_keTi_targetCV) { LogMessage(@"错误: 找不到包含“课体”的UICollectionView。"); return; }
    
    g_isExtracting = YES;
    g_currentTaskType = @"KeTi";
    g_keTi_workQueue = [NSMutableArray array];
    g_keTi_resultsArray = [NSMutableArray array];
    
    NSInteger totalItems = [g_keTi_targetCV.dataSource collectionView:g_keTi_targetCV numberOfItemsInSection:0];
    for (NSInteger i = 0; i < totalItems; i++) {
        [g_keTi_workQueue addObject:[NSIndexPath indexPathForItem:i inSection:0]];
    }

    if (g_keTi_workQueue.count == 0) {
        LogMessage(@"错误: 未找到任何“课体”单元来创建任务队列。");
        g_isExtracting = NO; return;
    }

    LogMessage(@"发现 %lu 个“课体”单元，开始处理队列...", (unsigned long)g_keTi_workQueue.count);
    processKeTiWorkQueue();
}

%new
- (void)startJiuZongMenExtraction {
    if (g_isExtracting) { LogMessage(@"错误：已有任务在进行中。"); return; }

    LogMessage(@"--- 开始“九宗门”提取任务 ---");
    g_isExtracting = YES;
    g_currentTaskType = @"JiuZongMen";

    SEL selector = NSSelectorFromString(@"顯示九宗門概覽");
    if ([self respondsToSelector:selector]) {
        LogMessage(@"正在调用方法: 顯示九宗門概覽");
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:selector];
        #pragma clang diagnostic pop
    } else {
        LogMessage(@"错误: 当前ViewController没有'顯示九宗門概覽'方法。");
        g_isExtracting = NO;
        g_currentTaskType = nil;
    }
}

%new
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer {
    UIView *panel = recognizer.view;
    CGPoint translation = [recognizer translationInView:panel.superview];
    panel.center = CGPointMake(panel.center.x + translation.x, panel.center.y + translation.y);
    [recognizer setTranslation:CGPointZero inView:panel.superview];
}

%end


// =================================================================
// 4. 构造函数 (保持不变)
// =================================================================

%ctor {
    @autoreleasepool {
        // 由于 viewDidLoad 中已经注入了UI，我们只需要 Hook presentViewController 即可。
        // 注意：这里我们Hook的是 UIViewController 而不是具体的 vcClass，这样更通用。
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[CombinedExtractor] 终极提取器 v2.0 已准备就绪。");
    }
}
