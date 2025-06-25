// Filename: CombinedExtractor_v5.2_RobustFilter
// 描述: 最终解决方案 v5.2。重写了StackView的提取逻辑，使其更加健壮，能100%过滤掉内容为空的标题。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =================================================================
// 1. 全局变量与辅助函数
// =================================================================

static BOOL g_isExtracting = NO;
static NSString *g_currentTaskType = nil;
static BOOL g_shouldIncludeXiangJie = NO;

static NSMutableArray *g_keTi_workQueue = nil;
static NSMutableArray *g_keTi_resultsArray = nil;
static UICollectionView *g_keTi_targetCV = nil;

static UITextView *g_logView = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

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
        NSLog(@"[CombinedExtractor-v5.2] %@", message);
    });
}

// =================================================================
// 2. 核心的Hook与队列处理逻辑
// =================================================================

static void processKeTiWorkQueue(void);

// ================== 分区提取函数 (v5.2 健壮过滤版) ==================
static NSString* extractDataFromSplitView(UIView *rootView, BOOL includeXiangJie) {
    if (!rootView) return @"[错误: 根视图为空]";
    
    NSMutableString *finalResult = [NSMutableString string];

    // --- Part 1: 从 UIStackView 提取上半部分内容 ---
    NSMutableArray *stackViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UIStackView class], rootView, stackViews);
    
    if (stackViews.count > 0) {
        UIStackView *mainStackView = stackViews.firstObject;
        
        // 使用更健壮的“块”处理逻辑
        NSMutableArray *blocks = [NSMutableArray array];
        NSMutableDictionary *currentBlock = nil;

        for (UIView *subview in mainStackView.arrangedSubviews) {
            if (![subview isKindOfClass:[UILabel class]]) continue;
            UILabel *label = (UILabel *)subview;
            NSString *text = label.text;
            if (!text || text.length == 0) continue;

            BOOL isTitle = (label.font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) != 0;

            if (isTitle) {
                // 如果已存在一个块，先保存它
                if (currentBlock) {
                    [blocks addObject:currentBlock];
                }
                // 创建一个新块
                currentBlock = [NSMutableDictionary dictionaryWithDictionary:@{
                    @"title": text,
                    @"content": [NSMutableString string]
                }];
            } else {
                // 如果这是一个内容，并且当前有一个块，就追加内容
                if (currentBlock) {
                    NSMutableString *content = currentBlock[@"content"];
                    if (content.length > 0) {
                        [content appendString:@" "]; // 用空格分隔多行内容
                    }
                    [content appendString:text];
                }
            }
        }
        // 不要忘记添加最后一个块
        if (currentBlock) {
            [blocks addObject:currentBlock];
        }

        // 格式化并过滤所有块
        for (NSDictionary *block in blocks) {
            NSString *title = block[@"title"];
            NSString *content = [block[@"content"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            // 只有内容不为空的块才会被添加
            if (content.length > 0) {
                [finalResult appendFormat:@"%@\n%@\n\n", title, content];
            }
        }
    }

    // --- Part 2: 从 IntrinsicTableView 提取“详解”内容 ---
    if (includeXiangJie) {
        Class tableViewClass = NSClassFromString(@"六壬大占.IntrinsicTableView");
        if (tableViewClass) {
            NSMutableArray *tableViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive(tableViewClass, rootView, tableViews);
            
            if (tableViews.count > 0) {
                UIView *xiangJieTable = tableViews.firstObject;
                
                NSMutableArray *xiangJieLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], xiangJieTable, xiangJieLabels);
                
                if (xiangJieLabels.count > 0) {
                    [finalResult appendString:@"--- 详解 ---\n\n"];
                    
                    for (NSUInteger i = 0; i < xiangJieLabels.count; i += 2) {
                        UILabel *titleLabel = xiangJieLabels[i];
                        
                        // 过滤掉结尾多余的“详解”标签
                        if (i + 1 >= xiangJieLabels.count && [titleLabel.text isEqualToString:@"详解"]) {
                            continue; 
                        }

                        if (i + 1 < xiangJieLabels.count) {
                            UILabel *contentLabel = xiangJieLabels[i+1];
                            [finalResult appendFormat:@"%@→%@\n\n", titleLabel.text, contentLabel.text];
                        } else {
                            [finalResult appendFormat:@"%@→\n\n", titleLabel.text];
                        }
                    }
                }
            }
        }
    }

    return [finalResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}


// Hook：拦截弹窗事件
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    Class targetClass = NSClassFromString(@"六壬大占.課體概覽視圖");
    
    if (g_isExtracting && targetClass && [vcToPresent isKindOfClass:targetClass]) {
        vcToPresent.view.alpha = 0.0f; animated = NO;
        
        void (^extractionCompletion)(void) = ^{
            if (completion) { completion(); }
            
            NSString *extractedText = extractDataFromSplitView(vcToPresent.view, g_shouldIncludeXiangJie);
            
            if ([g_currentTaskType isEqualToString:@"KeTi"]) {
                [g_keTi_resultsArray addObject:extractedText];
                LogMessage(@"成功提取“课体”第 %lu 项...", (unsigned long)g_keTi_resultsArray.count);
                [vcToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        processKeTiWorkQueue();
                    });
                }];
            } 
            else if ([g_currentTaskType isEqualToString:@"JiuZongMen"]) {
                LogMessage(@"成功提取“九宗门”详情！");
                [UIPasteboard generalPasteboard].string = extractedText;
                LogMessage(@"内容已复制到剪贴板！");
                g_isExtracting = NO;
                g_currentTaskType = nil;
                [vcToPresent dismissViewControllerAnimated:NO completion:nil];
            }
        };
        Original_presentViewController(self, _cmd, vcToPresent, animated, extractionCompletion);
    } else {
        Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
    }
}

// “课体”任务队列处理器
static void processKeTiWorkQueue() {
    if (g_keTi_workQueue.count == 0) {
        LogMessage(@"所有 %lu 项“课体”任务处理完毕！", (unsigned long)g_keTi_resultsArray.count);
        NSMutableString *finalResult = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keTi_resultsArray.count; i++) {
            NSString *itemText = g_keTi_resultsArray[i];
            NSString *itemTitle = [NSString stringWithFormat:@"课体 %lu", (unsigned long)i + 1];
            NSRange titleRange = [itemText rangeOfString:@"\n"];
            if (titleRange.location != NSNotFound) {
                 NSString* firstLine = [itemText substringToIndex:titleRange.location];
                 if ([firstLine containsString:@"课"]) {
                    itemTitle = firstLine;
                 }
            }
            [finalResult appendFormat:@"--- %@ ---\n\n%@\n\n\n", itemTitle, itemText];
        }
        [UIPasteboard generalPasteboard].string = [finalResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
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
// 3. UI 和控制逻辑
// =================================================================
@interface UIViewController (CombinedExtractor)
- (void)setupCombinedExtractorPanel;
- (void)startExtractionWithTaskType:(NSString *)taskType includeXiangJie:(BOOL)include;
- (void)handleButtonTap:(UIButton *)sender;
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

%new
- (void)setupCombinedExtractorPanel {
    UIWindow *keyWindow = self.view.window;
    if (!keyWindow || [keyWindow viewWithTag:889900]) return;

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 350, 500)];
    panel.tag = 889900;
    panel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.92];
    panel.layer.cornerRadius = 12;
    panel.layer.borderColor = [UIColor systemPurpleColor].CGColor;
    panel.layer.borderWidth = 1.5;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 350, 20)];
    titleLabel.text = @"大六壬终极提取器 v5.2";
    titleLabel.textColor = [UIColor systemPurpleColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:titleLabel];

    CGFloat buttonY = 60;
    CGFloat buttonHeight = 44;
    CGFloat buttonSpacing = 10;
    
    NSArray *buttonConfigs = @[
        @{@"title": @"提取课体 (带详解)", @"tag": @(1), @"color": [UIColor systemGreenColor]},
        @{@"title": @"提取课体 (无详解)", @"tag": @(2), @"color": [UIColor colorWithRed:0.2 green:0.5 blue:0.3 alpha:1.0]},
        @{@"title": @"提取九宗门 (带详解)", @"tag": @(3), @"color": [UIColor systemCyanColor]},
        @{@"title": @"提取九宗门 (无详解)", @"tag": @(4), @"color": [UIColor colorWithRed:0.1 green:0.4 blue:0.5 alpha:1.0]}
    ];

    for (NSDictionary *config in buttonConfigs) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(20, buttonY, panel.bounds.size.width - 40, buttonHeight);
        [btn setTitle:config[@"title"] forState:UIControlStateNormal];
        btn.tag = [config[@"tag"] integerValue];
        btn.backgroundColor = config[@"color"];
        [btn addTarget:self action:@selector(handleButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        btn.layer.cornerRadius = 8;
        [panel addSubview:btn];
        
        buttonY += buttonHeight + buttonSpacing;
    }

    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, buttonY + 10, panel.bounds.size.width - 20, panel.bounds.size.height - buttonY - 20)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor whiteColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = NO;
    g_logView.layer.cornerRadius = 5;
    g_logView.text = @"终极提取器 v5.2 (健壮过滤版) 已就绪。";
    [panel addSubview:g_logView];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [panel addGestureRecognizer:pan];

    [keyWindow addSubview:panel];
}

%new
- (void)handleButtonTap:(UIButton *)sender {
    if (g_isExtracting) { LogMessage(@"错误：已有任务在进行中。"); return; }
    
    NSString *taskType = nil;
    BOOL includeXiangJie = NO;

    switch (sender.tag) {
        case 1: taskType = @"KeTi"; includeXiangJie = YES; break;
        case 2: taskType = @"KeTi"; includeXiangJie = NO; break;
        case 3: taskType = @"JiuZongMen"; includeXiangJie = YES; break;
        case 4: taskType = @"JiuZongMen"; includeXiangJie = NO; break;
        default: return;
    }
    
    [self startExtractionWithTaskType:taskType includeXiangJie:includeXiangJie];
}

%new
- (void)startExtractionWithTaskType:(NSString *)taskType includeXiangJie:(BOOL)include {
    g_isExtracting = YES;
    g_currentTaskType = taskType;
    g_shouldIncludeXiangJie = include;

    LogMessage(@"--- 开始任务: %@ (详解: %@) ---", taskType, include ? @"是" : @"否");

    if ([taskType isEqualToString:@"KeTi"]) {
        UIWindow *keyWindow = self.view.window;
        if (!keyWindow) { LogMessage(@"错误: 找不到主窗口。"); g_isExtracting = NO; return; }
        
        g_keTi_targetCV = nil;
        Class keTiCellClass = NSClassFromString(@"六壬大占.課體單元");
        if (!keTiCellClass) { LogMessage(@"错误: 找不到 '六壬大占.課體單元' 类。"); g_isExtracting = NO; return; }
        
        NSMutableArray<UICollectionView *> *allCVs = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UICollectionView class], keyWindow, allCVs);
        
        for (UICollectionView *cv in allCVs) {
            for (id cell in cv.visibleCells) {
                if ([cell isKindOfClass:keTiCellClass]) {
                    g_keTi_targetCV = cv;
                    break;
                }
            }
            if(g_keTi_targetCV) break;
        }

        if (!g_keTi_targetCV) { LogMessage(@"错误: 找不到包含“课体”的UICollectionView。"); g_isExtracting = NO; return; }
        
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

    } else if ([taskType isEqualToString:@"JiuZongMen"]) {
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
        }
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
// 4. 构造函数
// =================================================================

%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[CombinedExtractor-v5.2] 终极提取器 v5.2 (健壮过滤版) 已准备就绪。");
    }
}
