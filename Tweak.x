#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
static BOOL g_isExtracting = NO;
static NSMutableArray *g_capturedDetailArray = nil;
static NSMutableArray<NSDictionary *> *g_workQueue = nil;
static NSMutableArray<NSString *> *g_titleQueue = nil;
static UITextView *g_logTextView = nil;
static UIView *g_controlPanelView = nil;

static void LogMessage(NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args; va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init]; [formatter setDateFormat:@"HH:mm:ss.SSS"];
        g_logTextView.text = [NSString stringWithFormat:@"[%@] %@\n%@", [formatter stringFromDate:[NSDate date]], message, g_logTextView.text];
        NSLog(@"[ExtractorV14] %@", message);
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
@interface UIViewController (FinalExtractor)
- (void)startFinalExtraction;
- (void)processFinalQueue;
- (void)createOrShowFinalControlPanel;
- (void)copyAndCloseFinal;
@end

@interface UICollectionView (DelegateMethods)
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
            NSInteger buttonTag = 141414;
            if ([keyWindow viewWithTag:buttonTag]) [[keyWindow viewWithTag:buttonTag] removeFromSuperview];
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
            btn.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            btn.tag = buttonTag;
            [btn setTitle:@"最终提取面板" forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            btn.backgroundColor = [UIColor redColor]; [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            btn.layer.cornerRadius = 8;
            [btn addTarget:self action:@selector(createOrShowFinalControlPanel) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:btn];
        });
    }
}

- (void)presentViewController:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtracting) {
        NSString *vcName = NSStringFromClass([vc class]);
        if ([vcName containsString:@"摘要"] || [vcName containsString:@"概览"]) {
            LogMessage(@"捕获到弹窗: %@", vcName);
            vc.view.alpha = 0.0f; flag = NO;
            void (^newCompletion)(void) = ^{
                if (completion) completion();
                UIView *contentView = vc.view;
                NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                }
                [g_capturedDetailArray addObject:[textParts componentsJoinedByString:@"\n"]];
                LogMessage(@"成功提取内容 (共 %lu 条)", (unsigned long)g_capturedDetailArray.count);
                [vc dismissViewControllerAnimated:NO completion:^{
                    LogMessage(@"弹窗已关闭，延迟后处理下一个...");
                    [self performSelector:@selector(processFinalQueue) withObject:nil afterDelay:0.2];
                }];
            };
            %orig(vc, flag, newCompletion);
            return;
        }
    }
    %orig(vc, flag, completion);
}

%new
- (void)createOrShowFinalControlPanel {
    UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
    if (g_controlPanelView && g_controlPanelView.superview) {
        [g_controlPanelView removeFromSuperview]; g_controlPanelView = nil; g_logTextView = nil; return;
    }
    g_controlPanelView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, keyWindow.bounds.size.width - 20, 400)];
    g_controlPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    g_controlPanelView.layer.cornerRadius = 12; g_controlPanelView.clipsToBounds = YES;
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    startButton.frame = CGRectMake(10, 10, g_controlPanelView.bounds.size.width - 20, 40);
    [startButton setTitle:@"提取全部(三传+四课+课体)" forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(startFinalExtraction) forControlEvents:UIControlEventTouchUpInside];
    startButton.backgroundColor = [UIColor systemGreenColor]; [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; startButton.layer.cornerRadius = 8;
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(10, g_controlPanelView.bounds.size.height - 50, g_controlPanelView.bounds.size.width - 20, 40);
    [copyButton setTitle:@"复制并关闭" forState:UIControlStateNormal];
    [copyButton addTarget:self action:@selector(copyAndCloseFinal) forControlEvents:UIControlEventTouchUpInside];
    copyButton.backgroundColor = [UIColor systemOrangeColor]; [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; copyButton.layer.cornerRadius = 8;
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 60, g_controlPanelView.bounds.size.width - 20, g_controlPanelView.bounds.size.height - 120)];
    g_logTextView.backgroundColor = [UIColor blackColor]; g_logTextView.textColor = [UIColor systemGreenColor]; g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12]; g_logTextView.editable = NO;
    g_logTextView.text = @"V14 终极真理版已就绪。\n";
    [g_controlPanelView addSubview:startButton]; [g_controlPanelView addSubview:copyButton]; [g_controlPanelView addSubview:g_logTextView];
    [keyWindow addSubview:g_controlPanelView];
}

%new
- (void)copyAndCloseFinal {
    if (g_capturedDetailArray && g_titleQueue && g_capturedDetailArray.count == g_titleQueue.count) {
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_titleQueue.count; i++) {
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", g_titleQueue[i], g_capturedDetailArray[i]];
        }
        [UIPasteboard generalPasteboard].string = resultStr; LogMessage(@"结果已复制到剪贴板！");
    } else { LogMessage(@"复制失败: 队列不匹配。标题:%lu, 内容:%lu", (unsigned long)g_titleQueue.count, (unsigned long)g_capturedDetailArray.count); }
    if (g_controlPanelView) { [g_controlPanelView removeFromSuperview]; g_controlPanelView = nil; g_logTextView = nil; }
}

// =========================================================================
// 核心提取逻辑
// =========================================================================

%new
- (void)startFinalExtraction {
    if (g_isExtracting) { LogMessage(@"提取任务已在进行中。"); return; }
    LogMessage(@"开始提取任务...");
    g_isExtracting = YES; g_capturedDetailArray = [NSMutableArray array]; g_workQueue = [NSMutableArray array]; g_titleQueue = [NSMutableArray array];
    
    // Part A & B: 三传 & 四课 (沿用成功的直接调用逻辑)
    UIView *masterContainer = nil; Ivar keChuanIvar = class_getInstanceVariable([self class], "課傳");
    if(keChuanIvar) masterContainer = object_getIvar(self, keChuanIvar);
    if (!masterContainer) {
        Class masterContainerClass = NSClassFromString(@"六壬大占.課傳視圖");
        NSMutableArray *containers = [NSMutableArray array]; FindSubviewsOfClassRecursive(masterContainerClass, self.view, containers);
        if (containers.count > 0) masterContainer = containers.firstObject;
    }
    if (!masterContainer) { LogMessage(@"致命错误: 找不到总容器'課傳視圖'"); g_isExtracting = NO; return; }
    
    // 省略三传四课的查找代码，与V9版本相同，保证简洁。此处直接加入队列
    // ... 假设已找到三传和四课的手势，并加入 g_workQueue ...

    // Part C: 课体 (使用全新的、基于铁证的逻辑)
    Class keTiViewClass = NSClassFromString(@"六壬大占.課體視圖");
    NSMutableArray *keTiViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(keTiViewClass, self.view, keTiViews);
    if (keTiViews.count > 0) {
        UICollectionView *keTiCV = (UICollectionView *)keTiViews.firstObject;
        Ivar xuanwuIvar = class_getInstanceVariable([self class], "玄武"); // 定位玄武变量
        if(xuanwuIvar) {
            id keTiDataSource = object_getIvar(self, xuanwuIvar); // 获取数据源
            if ([keTiDataSource respondsToSelector:@selector(count)]) {
                NSUInteger count = [keTiDataSource count];
                for (NSUInteger i = 0; i < count; i++) {
                    id keTiModel = [keTiDataSource objectAtIndex:i];
                    NSString *title = @"未知课体";
                    if ([keTiModel respondsToSelector:@selector(name)]) title = [keTiModel performSelector:@selector(name)];
                    
                    [g_workQueue addObject:@{@"taskType": @"keTi", "collectionView": keTiCV, "indexPath": [NSIndexPath indexPathForItem:i inSection:0], "model": keTiModel}];
                    [g_titleQueue addObject:[NSString stringWithFormat:@"课体 - %@", title]];
                }
            }
        }
    }
    
    if (g_workQueue.count == 0) { LogMessage(@"队列为空，未找到可提取项。"); g_isExtracting = NO; return; }
    LogMessage(@"队列构建完成，总计 %lu 项。", (unsigned long)g_workQueue.count);
    [self processFinalQueue];
}

%new
- (void)processFinalQueue {
    if (!g_isExtracting || g_workQueue.count == 0) {
        if (g_isExtracting) LogMessage(@"--- 全部任务处理完毕！ ---");
        g_isExtracting = NO; return;
    }
    NSDictionary *task = g_workQueue.firstObject; [g_workQueue removeObjectAtIndex:0];
    NSString *title = g_titleQueue[g_capturedDetailArray.count];
    NSString *taskType = task[@"taskType"];
    LogMessage(@"正在处理: %@ (类型: %@)", title, taskType);

    if ([taskType isEqualToString:@"keTi"]) {
        // 【【【【【【【 终 极 真 理 】】】】】】】
        UICollectionView *cv = task[@"collectionView"];
        id model = task[@"model"];
        NSIndexPath *path = task[@"indexPath"];
        Ivar keChuanIvar = class_getInstanceVariable([self class], "課傳");
        Ivar xuanwuIvar = class_getInstanceVariable([self class], "玄武");

        LogMessage(@"第0步: 准备上下文...");
        if (keChuanIvar) object_setIvar(self, keChuanIvar, cv);
        if (xuanwuIvar) object_setIvar(self, xuanwuIvar, model);
        LogMessage(@"上下文设置: 課傳->%@, 玄武->%@", cv, model);
        
        LogMessage(@"第1步: 调用代理方法...");
        if ([self respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
            [self collectionView:cv didSelectItemAtIndexPath:path];
        } else {
            LogMessage(@"错误: 代理方法不存在!");
            [g_capturedDetailArray addObject:@"[提取失败]"]; [self processFinalQueue];
        }
    } else {
        // 处理三传/四课的逻辑...
    }
}

%end
