#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray<NSDictionary *> *g_keChuanWorkQueue = nil;
static NSMutableArray<NSString *> *g_keChuanTitleQueue = nil;

static UITextView *g_logTextView = nil;
static UIView *g_controlPanelView = nil;

static void LogMessage(NSString *format, ...) { /* ... */ }
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { /* ... */ }


// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)startExtraction_Truth;
- (void)processKeChuanQueue_Truth;
- (void)createOrShowControlPanel_Truth;
- (void)copyAndClose_Truth;
@end

@interface UICollectionView (DelegateMethods)
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath;
@end

%hook UIViewController

// --- viewDidLoad ---
- (void)viewDidLoad { %orig; /* ... */ }

// --- presentViewController ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        // 【【【 最终更新点 #1: 加入新的课体弹窗类名 】】】
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"] || [vcClassName containsString:@"課體概覽視圖"]) {
            LogMessage(@"捕获到弹窗: %@", vcClassName);
            viewControllerToPresent.view.alpha = 0.0f; flag = NO;
            
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
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
                    const double kDelayInSeconds = 0.2; 
                    LogMessage(@"弹窗已关闭，延迟 %.1f 秒后处理下一个...", kDelayInSeconds);
                    [self processKeChuanQueue_Truth];
                }];
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)createOrShowControlPanel_Truth {
    UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
    NSInteger panelTag = 556692;
    if (g_controlPanelView && g_controlPanelView.superview) {
        [g_controlPanelView removeFromSuperview]; g_controlPanelView = nil; g_logTextView = nil; return;
    }
    g_controlPanelView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, keyWindow.bounds.size.width - 20, keyWindow.bounds.size.height - 200)];
    g_controlPanelView.tag = panelTag;
    g_controlPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
    g_controlPanelView.layer.cornerRadius = 12; g_controlPanelView.clipsToBounds = YES;
    
    // 【【【 最终更新点 #2: 按钮文本更新为最终版 】】】
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    startButton.frame = CGRectMake(10, 10, 240, 40);
    [startButton setTitle:@"提取全部(三传+四课+课体)" forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(startExtraction_Truth) forControlEvents:UIControlEventTouchUpInside];
    startButton.backgroundColor = [UIColor systemGreenColor]; [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; startButton.layer.cornerRadius = 8;
    
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(260, 10, 100, 40);
    [copyButton setTitle:@"复制关闭" forState:UIControlStateNormal];
    [copyButton addTarget:self action:@selector(copyAndClose_Truth) forControlEvents:UIControlEventTouchUpInside];
    copyButton.backgroundColor = [UIColor systemOrangeColor]; [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; copyButton.layer.cornerRadius = 8;

    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 60, g_controlPanelView.bounds.size.width - 20, g_controlPanelView.bounds.size.height - 70)];
    g_logTextView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0]; g_logTextView.textColor = [UIColor systemGreenColor]; g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12]; g_logTextView.editable = NO; g_logTextView.layer.cornerRadius = 8;
    g_logTextView.text = @"日志控制台已准备就绪。\n";
    
    [g_controlPanelView addSubview:startButton];
    [g_controlPanelView addSubview:copyButton];
    [g_controlPanelView addSubview:g_logTextView];
    [keyWindow addSubview:g_controlPanelView];
}

%new
- (void)copyAndClose_Truth { /* ... */ }


// =========================================================================
// 核心提取逻辑
// =========================================================================

%new
- (void)startExtraction_Truth {
    if (g_isExtractingKeChuanDetail) { LogMessage(@"错误：提取任务已在进行中。"); return; }
    
    LogMessage(@"开始提取任务...");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array]; g_keChuanWorkQueue = [NSMutableArray array]; g_keChuanTitleQueue = [NSMutableArray array];
  
    Ivar keChuanContainerIvar = class_getInstanceVariable([self class], "課傳");
    if (!keChuanContainerIvar) { LogMessage(@"致命错误: 找不到总容器 '課傳' 的ivar。"); g_isExtractingKeChuanDetail = NO; return; }
    UIView *keChuanContainer = object_getIvar(self, keChuanContainerIvar);
    if (!keChuanContainer) { LogMessage(@"致命错误: '課傳' 总容器视图为nil。"); g_isExtractingKeChuanDetail = NO; return; }
    LogMessage(@"成功获取总容器 '課傳': %@", keChuanContainer);

    // Part A & B: 三传和四课提取 (保持不变)
    // ...

    // 【【【 最终更新点 #3: 全新的课体提取模块 】】】
    LogMessage(@"--- 开始搜索【课体】模块 ---");
    Class keTiViewClass = NSClassFromString(@"六壬大占.課體視圖");
    NSMutableArray *keTiViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(keTiViewClass, self.view, keTiViews);

    if (keTiViews.count > 0) {
        UICollectionView *keTiCollectionView = (UICollectionView *)keTiViews.firstObject;
        LogMessage(@"【课体】成功找到容器: %@", keTiCollectionView);
        
        // 获取课体单元总数
        NSInteger itemCount = [keTiCollectionView.dataSource collectionView:keTiCollectionView numberOfItemsInSection:0];
        LogMessage(@"【课体】容器中总共有 %ld 个单元。", (long)itemCount);

        for (NSInteger i = 0; i < itemCount; i++) {
            NSIndexPath *path = [NSIndexPath indexPathForItem:i inSection:0];
            UICollectionViewCell *cell = [keTiCollectionView.dataSource collectionView:keTiCollectionView cellForItemAtIndexPath:path];
            
            // 从单元格中找到UILabel获取标题
            NSString *title = @"未知课体";
            if (cell) {
                NSMutableArray *labelsInCell = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labelsInCell);
                if (labelsInCell.count > 0) { title = ((UILabel *)labelsInCell.firstObject).text; }
            }

            [g_keChuanWorkQueue addObject:@{
                @"taskType": @"keTi",
                @"collectionView": keTiCollectionView,
                @"indexPath": path
            }];
            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"课体 - %@", title]];
            LogMessage(@"【课体】已添加任务: %@ (路径: %@)", title, path);
        }
    } else {
        LogMessage(@"--- 在视图层级中未找到 '課體視圖' ---");
    }

    if (g_keChuanWorkQueue.count == 0) { LogMessage(@"队列为空，未找到任何可提取项。"); g_isExtractingKeChuanDetail = NO; return; }
    LogMessage(@"--- 任务队列构建完成，总计 %lu 项。---", (unsigned long)g_keChuanWorkQueue.count);
    [self processKeChuanQueue_Truth];
}

%new
- (void)processKeChuanQueue_Truth {
    if (!g_isExtractingKeChuanDetail || g_keChuanWorkQueue.count == 0) {
        if (g_isExtractingKeChuanDetail) {
            LogMessage(@"--- 全部任务处理完毕！ ---");
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"所有详情已提取。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
        g_isExtractingKeChuanDetail = NO; return;
    }
  
    NSDictionary *task = g_keChuanWorkQueue.firstObject; 
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    NSString *title = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];
    NSString *taskType = task[@"taskType"];
    LogMessage(@"正在处理: %@ (类型: %@)", title, taskType);

    // 【【【 最终更新点 #4: 处理新的课体任务类型 】】】
    if ([taskType isEqualToString:@"keTi"]) {
        UICollectionView *collectionView = task[@"collectionView"];
        NSIndexPath *indexPath = task[@"indexPath"];
        id delegate = collectionView.delegate;
        SEL selector = @selector(collectionView:didSelectItemAtIndexPath:);
        
        LogMessage(@"第0+1步: 调用代理方法 %@", NSStringFromSelector(selector));
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [delegate performSelector:selector withObject:collectionView withObject:indexPath];
        #pragma clang diagnostic pop

    } else { // 处理旧的三传和四课任务
        UIGestureRecognizer *gestureToTrigger = task[@"gesture"];
        UIView *contextView = task[@"contextView"];
        
        Ivar keChuanIvar = class_getInstanceVariable([self class], "課傳");
        if (keChuanIvar) {
            object_setIvar(self, keChuanIvar, contextView);
            LogMessage(@"第0步: 成功设置 '課傳' ivar -> %@", contextView);
        }
        
        SEL actionToPerform = nil;
        if ([taskType isEqualToString:@"tianJiang"]) {
            actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
        } else {
            actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
        }
        
        if ([self respondsToSelector:actionToPerform]) {
            LogMessage(@"第1步: 调用方法 %@, 传递手势: %@", NSStringFromSelector(actionToPerform), gestureToTrigger);
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self performSelector:actionToPerform withObject:gestureToTrigger];
            #pragma clang diagnostic pop
        } else {
            LogMessage(@"第1步: 错误！方法 %@ 不存在。", NSStringFromSelector(actionToPerform));
            [g_capturedKeChuanDetailArray addObject:@"[提取失败: 方法不存在]"];
            [self processKeChuanQueue_Truth];
        }
    }
}

%end
