// Filename: CombinedExtractor_v3.2_FinalFixed
// 描述: 最终修复版。解决了“详解”部分为TableView的问题，深入其内部提取数据。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =================================================================
// 1. 全局变量与辅助函数 (无变化)
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
        NSLog(@"[CombinedExtractor-v3.2] %@", message);
    });
}

static id GetIvarValueSafely(id object, const char *ivarName) {
    Ivar ivar = class_getInstanceVariable([object class], ivarName);
    if (ivar) {
        return object_getIvar(object, ivar);
    }
    return nil;
}

// =================================================================
// 2. 核心的Hook与队列处理逻辑 (extractDataFromModel 已更新)
// =================================================================

static void processKeTiWorkQueue(void);

// ================== 再次重写的核心提取函数 ==================
static NSString* extractDataFromModel(id viewController, BOOL includeXiangJie) {
    if (!viewController) return @"[错误: 目标控制器为空]";

    NSDictionary<NSString *, NSString *> *dataMap = @{
        @"课名": @"課名",
        @"判断": @"判斷",
        @"变体": @"變體",
        @"简断": @"簡斷",
        @"故象曰": @"象辭"
    };

    NSMutableString *resultString = [NSMutableString string];

    // 1. 提取普通字段 (这部分逻辑正确，保持不变)
    for (NSString *title in @[@"课名", @"判断", @"变体", @"简断", @"故象曰"]) {
        const char *ivarName = [dataMap[title] UTF8String];
        id value = GetIvarValueSafely(viewController, ivarName);
        if (value && [value isKindOfClass:[NSString class]] && ((NSString *)value).length > 0) {
            [resultString appendFormat:@"%@\n%@\n\n", title, value];
        }
    }

    // 2. 根据选项，决定是否提取“详解”
    if (includeXiangJie) {
        // --- 核心修正：处理内嵌的 UITableView ---
        id xiangJieTableView = GetIvarValueSafely(viewController, "詳解表");
        
        if (xiangJieTableView && [xiangJieTableView isKindOfClass:[UITableView class]]) {
            [resultString appendString:@"--- 详解 ---\n\n"];
            
            UITableView *tableView = (UITableView *)xiangJieTableView;
            id<UITableViewDataSource> dataSource = tableView.dataSource;
            
            if (dataSource) {
                NSInteger sections = 1;
                if ([dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]) {
                    sections = [dataSource numberOfSectionsInTableView:tableView];
                }

                for (NSInteger section = 0; section < sections; section++) {
                    NSInteger rows = [dataSource tableView:tableView numberOfRowsInSection:section];
                    for (NSInteger row = 0; row < rows; row++) {
                        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                        UITableViewCell *cell = [dataSource tableView:tableView cellForRowAtIndexPath:indexPath];
                        
                        if (cell) {
                            // 标题-正文 结构通常在 UITableViewCell 的 textLabel 和 detailTextLabel 中
                            // 或者在 cell 的 contentView 的子视图中
                            NSString *titleText = cell.textLabel.text;
                            NSString *detailText = cell.detailTextLabel.text;

                            if (titleText && titleText.length > 0) {
                                // 拼接成 key->value 的形式
                                [resultString appendFormat:@"%@→%@", titleText, (detailText ?: @"")];
                            } else {
                                // 如果cell结构更复杂，遍历cell的所有UILabel
                                NSMutableArray *labelsInCell = [NSMutableArray array];
                                FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labelsInCell);
                                if (labelsInCell.count >= 2) {
                                     UILabel *titleLabel = labelsInCell[0];
                                     UILabel *contentLabel = labelsInCell[1];
                                     [resultString appendFormat:@"%@→%@", titleLabel.text, contentLabel.text];
                                } else if (labelsInCell.count == 1) {
                                     [resultString appendString:((UILabel *)labelsInCell[0]).text];
                                }
                            }
                            [resultString appendString:@"\n\n"];
                        }
                    }
                }
            }
        }
    }

    return [resultString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}


// Hook：拦截弹窗事件 (无变化)
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    Class targetClass = NSClassFromString(@"六壬大占.課體概覽視圖");
    
    if (g_isExtracting && targetClass && [vcToPresent isKindOfClass:targetClass]) {
        vcToPresent.view.alpha = 0.0f; animated = NO;
        
        void (^extractionCompletion)(void) = ^{
            if (completion) { completion(); }

            NSString *extractedText = extractDataFromModel(vcToPresent, g_shouldIncludeXiangJie);
            
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

// “课体”任务队列处理器 (无变化)
static void processKeTiWorkQueue() {
    if (g_keTi_workQueue.count == 0) {
        LogMessage(@"所有 %lu 项“课体”任务处理完毕！", (unsigned long)g_keTi_resultsArray.count);
        NSMutableString *finalResult = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keTi_resultsArray.count; i++) {
            NSString *itemText = g_keTi_resultsArray[i];
            NSString *itemTitle = @"未知课体";
            NSRange titleRange = [itemText rangeOfString:@"\n"];
            if (titleRange.location != NSNotFound) {
                 itemTitle = [itemText substringToIndex:titleRange.location];
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
// 3. UI 和控制逻辑 (无变化)
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
    panel.layer.borderColor = [UIColor systemIndigoColor].CGColor;
    panel.layer.borderWidth = 1.5;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 350, 20)];
    titleLabel.text = @"大六壬终极提取器 v3.2";
    titleLabel.textColor = [UIColor systemIndigoColor];
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
    g_logView.text = @"终极提取器 v3.2 (TableView版) 已就绪。";
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
        case 1:
            taskType = @"KeTi";
            includeXiangJie = YES;
            break;
        case 2:
            taskType = @"KeTi";
            includeXiangJie = NO;
            break;
        case 3:
            taskType = @"JiuZongMen";
            includeXiangJie = YES;
            break;
        case 4:
            taskType = @"JiuZongMen";
            includeXiangJie = NO;
            break;
        default:
            return;
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
            if ([cv.visibleCells.firstObject isKindOfClass:keTiCellClass]) {
                g_keTi_targetCV = cv; break;
            }
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
// 4. 构造函数 (无变化)
// =================================================================

%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[CombinedExtractor-v3.2] 终极提取器 v3.2 (TableView版) 已准备就绪。");
    }
}

