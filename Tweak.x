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
    if (!view) return;
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
- (void)debug_SimulateKeTiTap_V4;
@end

@interface UICollectionView (DelegateMethods)
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath;
@end

%hook UIViewController

// --- viewDidLoad ---
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
            [controlButton setTitle:@"提取面板" forState:UIControlStateNormal];
            controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            controlButton.backgroundColor = [UIColor purpleColor];
            [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            controlButton.layer.cornerRadius = 8;
            [controlButton addTarget:self action:@selector(createOrShowControlPanel_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:controlButton];
        });
    }
}

// --- presentViewController ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"] || [vcClassName containsString:@"課體摘要視圖"]) {
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
    
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    startButton.frame = CGRectMake(10, 10, 160, 40);
    [startButton setTitle:@"提取三传+四课" forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(startExtraction_Truth) forControlEvents:UIControlEventTouchUpInside];
    startButton.backgroundColor = [UIColor systemGreenColor]; [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; startButton.layer.cornerRadius = 8;
    
    UIButton *debugButton = [UIButton buttonWithType:UIButtonTypeSystem];
    debugButton.frame = CGRectMake(180, 10, 180, 40);
    [debugButton setTitle:@"模拟点击课体(V4)" forState:UIControlStateNormal];
    [debugButton addTarget:self action:@selector(debug_SimulateKeTiTap_V4) forControlEvents:UIControlEventTouchUpInside];
    debugButton.backgroundColor = [UIColor systemRedColor]; [debugButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; debugButton.layer.cornerRadius = 8;

    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(10, 60, 160, 40);
    [copyButton setTitle:@"复制结果并关闭" forState:UIControlStateNormal];
    [copyButton addTarget:self action:@selector(copyAndClose_Truth) forControlEvents:UIControlEventTouchUpInside];
    copyButton.backgroundColor = [UIColor systemOrangeColor]; [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; copyButton.layer.cornerRadius = 8;

    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 110, g_controlPanelView.bounds.size.width - 20, g_controlPanelView.bounds.size.height - 120)];
    g_logTextView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0]; g_logTextView.textColor = [UIColor systemGreenColor]; g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12]; g_logTextView.editable = NO; g_logTextView.layer.cornerRadius = 8;
    g_logTextView.text = @"日志控制台已准备就绪。\n";
    
    [g_controlPanelView addSubview:startButton];
    [g_controlPanelView addSubview:debugButton];
    [g_controlPanelView addSubview:copyButton];
    [g_controlPanelView addSubview:g_logTextView];
    [keyWindow addSubview:g_controlPanelView];
}

%new
- (void)copyAndClose_Truth {
    if (g_capturedKeChuanDetailArray && g_keChuanTitleQueue && g_capturedKeChuanDetailArray.count == g_keChuanTitleQueue.count) {
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = g_capturedKeChuanDetailArray[i];
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        LogMessage(@"结果已复制到剪贴板！");
    } else { 
        LogMessage(@"没有可复制的内容或队列数量不匹配。标题: %lu, 内容: %lu", (unsigned long)g_keChuanTitleQueue.count, (unsigned long)g_capturedKeChuanDetailArray.count);
    }
    
    if (g_controlPanelView) {
        [g_controlPanelView removeFromSuperview]; g_controlPanelView = nil; g_logTextView = nil;
    }
}

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

    // Part A: 三传提取
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    NSMutableArray *sanChuanResults = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanContainerClass, keChuanContainer, sanChuanResults);
    
    if (sanChuanResults.count > 0) {
        UIView *sanChuanContainer = sanChuanResults.firstObject;
        const char *ivarNames[] = {"初傳", "中傳", "末傳", NULL}; NSString *rowTitles[] = {@"初传", @"中传", @"末传"};
        for (int i = 0; ivarNames[i] != NULL; ++i) {
            Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, ivarNames[i]); if (!ivar) continue;
            UIView *chuanView = object_getIvar(sanChuanContainer, ivar); if (!chuanView) continue;
            NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
            [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            if(labels.count >= 2) {
                UILabel *dizhiLabel = labels[labels.count-2]; UILabel *tianjiangLabel = labels[labels.count-1];
                if (dizhiLabel.gestureRecognizers.count > 0) {
                    [g_keChuanWorkQueue addObject:@{@"gesture": dizhiLabel.gestureRecognizers.firstObject, @"contextView": chuanView, @"taskType": @"diZhi"}];
                    [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                }
                if (tianjiangLabel.gestureRecognizers.count > 0) {
                    [g_keChuanWorkQueue addObject:@{@"gesture": tianjiangLabel.gestureRecognizers.firstObject, @"contextView": chuanView, @"taskType": @"tianJiang"}];
                    [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
                }
            }
        }
    }
  
    // Part B: 四课提取
    Class siKeContainerClass = NSClassFromString(@"六壬大占.四課視圖");
    NSMutableArray *siKeResults = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeContainerClass, keChuanContainer, siKeResults);
    if (siKeResults.count > 0) {
        UIView *siKeContainer = siKeResults.firstObject;
        const char *ivarNames[] = {"第一課", "第二課", "第三課", "第四課", NULL}; NSString *rowTitles[] = {@"一课", @"二课", @"三课", @"四课"};
        for (int i = 0; ivarNames[i] != NULL; ++i) {
            Ivar ivar = class_getInstanceVariable(siKeContainerClass, ivarNames[i]); if (!ivar) continue;
            UIView *keView = object_getIvar(siKeContainer, ivar); if (!keView) continue;
            NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], keView, labels);
            if(labels.count >= 2) {
                UILabel *dizhiLabel = labels[0]; UILabel *tianjiangLabel = labels[1];
                if (dizhiLabel.gestureRecognizers.count > 0) {
                    [g_keChuanWorkQueue addObject:@{@"gesture": dizhiLabel.gestureRecognizers.firstObject, @"contextView": keView, @"taskType": @"diZhi"}];
                    [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                }
                if (tianjiangLabel.gestureRecognizers.count > 0) {
                    [g_keChuanWorkQueue addObject:@{@"gesture": tianjiangLabel.gestureRecognizers.firstObject, @"contextView": keView, @"taskType": @"tianJiang"}];
                    [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
                }
            }
        }
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
    UIGestureRecognizer *gestureToTrigger = task[@"gesture"];
    UIView *contextView = task[@"contextView"];
    NSString *taskType = task[@"taskType"];
    
    LogMessage(@"正在处理: %@ (类型: %@)", title, taskType);
    
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


%new
- (void)debug_SimulateKeTiTap_V4 {
    LogMessage(@"--- 开始【课体】模拟点击侦测 (V4.2) ---");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
    
    Class keTiViewClass = NSClassFromString(@"六壬大占.課體視圖");
    if (!keTiViewClass) { LogMessage(@"【侦测】错误: 找不到 課體視圖 类。"); g_isExtractingKeChuanDetail = NO; return; }
    
    NSMutableArray *keTiViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(keTiViewClass, self.view, keTiViews);
    
    if (keTiViews.count == 0) {
        LogMessage(@"【侦测】错误: 视图层级中找不到 課體視圖 实例。");
        g_isExtractingKeChuanDetail = NO; return;
    }
    
    UICollectionView *keTiCollectionView = (UICollectionView *)keTiViews.firstObject;
    LogMessage(@"【侦测】成功找到 課體視圖 (CollectionView): %@", keTiCollectionView);
    LogMessage(@"【侦测】它的代理(delegate)是: %@", keTiCollectionView.delegate);
    LogMessage(@"【侦测】它的数据源(dataSource)是: %@", keTiCollectionView.dataSource);

    NSIndexPath *firstItemPath = [NSIndexPath indexPathForItem:0 inSection:0];
    LogMessage(@"【侦测】准备模拟点击第一个单元格，路径为: %@", firstItemPath);

    id delegate = keTiCollectionView.delegate;
    SEL delegateSelector = @selector(collectionView:didSelectItemAtIndexPath:);
    
    if (delegate && [delegate respondsToSelector:delegateSelector]) {
        LogMessage(@"\n>>>>>> 尝试方案A: 调用代理方法 <<<<<<");
        LogMessage(@"【侦测】代理 %@ 响应方法 %@。", [delegate class], NSStringFromSelector(delegateSelector));
        LogMessage(@"【侦测】正在调用 [delegate collectionView:self didSelectItemAtIndexPath:firstItemPath]...");
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [delegate performSelector:delegateSelector withObject:keTiCollectionView withObject:firstItemPath];
        #pragma clang diagnostic pop
        LogMessage(@"【侦测】方案A调用完毕。请检查是否出现弹窗或新日志。");
        return; 
    } else {
        LogMessage(@"\n>>>>>> 方案A失败: 代理不存在或不响应点击方法。<<<<<<");
    }

    LogMessage(@"\n>>>>>> 尝试方案B: 调用 ViewController 上的已知方法 <<<<<<");
    UIGestureRecognizer *gesture = keTiCollectionView.gestureRecognizers.firstObject;
    if (!gesture) {
        LogMessage(@"【侦测】方案B失败: 課體視圖 上没有手势。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }

    Ivar keChuanIvar = class_getInstanceVariable([self class], "課傳");
    if (keChuanIvar) {
        object_setIvar(self, keChuanIvar, keTiCollectionView);
        LogMessage(@"【侦测】已设置 '課傳' Ivar。");
    }
    
    SEL vcSelector = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    if ([self respondsToSelector:vcSelector]) {
        LogMessage(@"【侦测】正在调用 [self %@]", NSStringFromSelector(vcSelector));
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:vcSelector withObject:gesture];
        #pragma clang diagnostic pop
        LogMessage(@"【侦-测】方案B调用完毕。");
    } else {
        LogMessage(@"【侦测】方案B失败: ViewController 不响应 %@。", NSStringFromSelector(vcSelector));
        g_isExtractingKeChuanDetail = NO;
    }
}

%end
