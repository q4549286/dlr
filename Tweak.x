#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
static BOOL g_isExtracting = NO;
static NSMutableArray<NSDictionary *> *g_workQueue = nil;
static NSMutableString *g_finalResultString = nil;

static UITextView *g_logTextView = nil;
static UIView *g_controlPanelView = nil;

static void LogMessage(NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args; va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init]; [formatter setDateFormat:@"HH:mm:ss"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSString *fullMessage = [logPrefix stringByAppendingString:message];
        g_logTextView.text = [NSString stringWithFormat:@"%@\n%@", fullMessage, g_logTextView.text];
        NSLog(@"[ExtractorV15] %@", message);
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
@interface UIViewController (FinalTruthAddons)
- (void)startExtraction_FinalTruth;
- (void)processWorkQueue_FinalTruth;
- (void)createOrShowControlPanel_FinalTruth;
- (void)copyAndClose_FinalTruth;
@end

%hook UIViewController

// --- viewDidLoad ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger btnTag = 151515; if ([keyWindow viewWithTag:btnTag]) { return; }
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
            btn.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            btn.tag = btnTag; [btn setTitle:@"提取面板" forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:16]; btn.backgroundColor = [UIColor systemRedColor];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; btn.layer.cornerRadius = 8;
            [btn addTarget:self action:@selector(createOrShowControlPanel_FinalTruth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:btn];
        });
    }
}

// --- presentViewController ---
- (void)presentViewController:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtracting) {
        NSString *vcName = NSStringFromClass([vc class]);
        if ([vcName containsString:@"摘要"] || [vcName containsString:@"總覽"] || [vcName containsString:@"概覽"]) {
            LogMessage(@"捕获到弹窗: %@", vcName);
            vc.view.alpha = 0.0f; flag = NO;
            
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                UIView *contentView = vc.view;
                NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; } }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                
                NSDictionary *currentTask = g_workQueue.firstObject;
                [g_finalResultString appendFormat:@"--- %@ ---\n%@\n\n", currentTask[@"title"], fullDetail];
                LogMessage(@"成功提取 '%@' 的内容。", currentTask[@"title"]);

                [vc dismissViewControllerAnimated:NO completion:^{
                    [g_workQueue removeObjectAtIndex:0];
                    const double kDelay = 0.2; LogMessage(@"延迟 %.1fs 后处理下一个...", kDelay);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processWorkQueue_FinalTruth];
                    });
                }];
            };
            %orig(vc, flag, newCompletion);
            return;
        }
    }
    %orig(vc, flag, completion);
}

%new
- (void)createOrShowControlPanel_FinalTruth {
    UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
    if (g_controlPanelView) { [g_controlPanelView removeFromSuperview]; g_controlPanelView = nil; g_logTextView = nil; return; }
    g_controlPanelView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, keyWindow.bounds.size.width - 20, 350)];
    g_controlPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    g_controlPanelView.layer.cornerRadius = 12; g_controlPanelView.clipsToBounds = YES;
    
    UIButton *startBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    startBtn.frame = CGRectMake(10, 10, g_controlPanelView.bounds.size.width - 20, 40);
    [startBtn setTitle:@"提取全部(三传+四课+课体)" forState:UIControlStateNormal];
    [startBtn addTarget:self action:@selector(startExtraction_FinalTruth) forControlEvents:UIControlEventTouchUpInside];
    startBtn.backgroundColor = [UIColor systemGreenColor]; [startBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; startBtn.layer.cornerRadius = 8;
    
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 60, g_controlPanelView.bounds.size.width - 20, g_controlPanelView.bounds.size.height - 120)];
    g_logTextView.backgroundColor = [UIColor blackColor]; g_logTextView.textColor = [UIColor systemGreenColor]; g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12]; g_logTextView.editable = NO; g_logTextView.text = @"V15 最终版已就绪。\n";
    
    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(10, g_controlPanelView.bounds.size.height - 50, g_controlPanelView.bounds.size.width - 20, 40);
    [copyBtn setTitle:@"复制结果并关闭" forState:UIControlStateNormal];
    [copyBtn addTarget:self action:@selector(copyAndClose_FinalTruth) forControlEvents:UIControlEventTouchUpInside];
    copyBtn.backgroundColor = [UIColor systemOrangeColor]; [copyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; copyBtn.layer.cornerRadius = 8;

    [g_controlPanelView addSubview:startBtn]; [g_controlPanelView addSubview:g_logTextView]; [g_controlPanelView addSubview:copyBtn];
    [keyWindow addSubview:g_controlPanelView];
}

%new
- (void)copyAndClose_FinalTruth {
    if (g_finalResultString.length > 0) { [UIPasteboard generalPasteboard].string = g_finalResultString; LogMessage(@"结果已复制!"); }
    [self createOrShowControlPanel_FinalTruth];
}

// =========================================================================
// 核心提取逻辑
// =========================================================================
%new
- (void)startExtraction_FinalTruth {
    if (g_isExtracting) { LogMessage(@"错误：提取任务已在进行中。"); return; }
    LogMessage(@"开始提取任务...");
    g_isExtracting = YES;
    g_workQueue = [NSMutableArray array]; g_finalResultString = [NSMutableString string];
  
    // Part A: 课体提取 (基于您的铁证)
    [g_workQueue addObject:@{@"taskType": @"keTi", @"title": @"课体总览"}];

    // Part B: 三传/四课提取 (基于之前的成功经验)
    Class masterContainerClass = NSClassFromString(@"六壬大占.課傳視圖");
    NSMutableArray *masterContainers = [NSMutableArray array]; FindSubviewsOfClassRecursive(masterContainerClass, self.view, masterContainers);
    if (masterContainers.count > 0) {
        UIView *masterContainer = masterContainers.firstObject;
        Class sanChuanClass = NSClassFromString(@"六壬大占.三傳視圖"); NSMutableArray *sanChuans=[NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanClass,masterContainer,sanChuans);
        if(sanChuans.count>0){ UIView*c=sanChuans.firstObject; const char*iv[]={"初傳","中傳","末傳",NULL}; NSString*t[]={@"初传",@"中传",@"末传"};
            for(int i=0;iv[i]!=NULL;++i){ Ivar v=class_getInstanceVariable([c class],iv[i]); if(!v)continue; UIView*vv=object_getIvar(c,v); if(!vv)continue; NSMutableArray*l=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class],vv,l); [l sortUsingComparator:^NSComparisonResult(UILabel*o1,UILabel*o2){return [@(o1.frame.origin.x)compare:@(o2.frame.origin.x)];}]; if(l.count>=2){ UILabel*d=l[l.count-2];UILabel*j=l[l.count-1]; if(d.gestureRecognizers.count>0)[g_workQueue addObject:@{@"taskType":@"gesture",@"gesture":d.gestureRecognizers.firstObject,@"title":[NSString stringWithFormat:@"%@-地支(%@)",t[i],d.text]}]; if(j.gestureRecognizers.count>0)[g_workQueue addObject:@{@"taskType":@"gesture",@"gesture":j.gestureRecognizers.firstObject,@"title":[NSString stringWithFormat:@"%@-天将(%@)",t[i],j.text]}];}}
        }
        Class siKeClass = NSClassFromString(@"六壬大占.四課視圖"); NSMutableArray *siKes=[NSMutableArray array]; FindSubviewsOfClassRecursive(siKeClass,masterContainer,siKes);
        if(siKes.count>0){ UIView*c=siKes.firstObject; const char*iv[]={"第一課","第二課","第三課","第四課",NULL}; NSString*t[]={@"一课",@"二课",@"三课",@"四课"};
            for(int i=0;iv[i]!=NULL;++i){ Ivar v=class_getInstanceVariable([c class],iv[i]); if(!v)continue; UIView*vv=object_getIvar(c,v); if(!vv)continue; NSMutableArray*l=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class],vv,l); if(l.count>=2){ UILabel*d=l[0];UILabel*j=l[1]; if(d.gestureRecognizers.count>0)[g_workQueue addObject:@{@"taskType":@"gesture",@"gesture":d.gestureRecognizers.firstObject,@"title":[NSString stringWithFormat:@"%@-地支(%@)",t[i],d.text]}]; if(j.gestureRecognizers.count>0)[g_workQueue addObject:@{@"taskType":@"gesture",@"gesture":j.gestureRecognizers.firstObject,@"title":[NSString stringWithFormat:@"%@-天将(%@)",t[i],j.text]}];}}
        }
    }
    
    if (g_workQueue.count == 0) { LogMessage(@"队列为空，未找到可提取项。"); g_isExtracting = NO; return; }
    LogMessage(@"--- 任务队列构建完成，总计 %lu 项。---", (unsigned long)g_workQueue.count);
    [self processWorkQueue_FinalTruth];
}

%new
- (void)processWorkQueue_FinalTruth {
    if (!g_isExtracting || g_workQueue.count == 0) {
        if (g_isExtracting) { LogMessage(@"--- 全部任务处理完毕！ ---"); }
        g_isExtracting = NO; return;
    }
  
    NSDictionary *task = g_workQueue.firstObject; 
    NSString *taskType = task[@"taskType"];
    LogMessage(@"正在处理: '%@'", task[@"title"]);
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if ([taskType isEqualToString:@"keTi"]) {
        SEL selector = NSSelectorFromString(@"顯示格局總覽");
        if ([self respondsToSelector:selector]) {
            [self performSelector:selector];
        } else {
            LogMessage(@"错误! 方法 '顯示格局總覽' 不存在。");
            [g_workQueue removeObjectAtIndex:0]; [self processWorkQueue_FinalTruth];
        }
    } else if ([taskType isEqualToString:@"gesture"]) {
        UIGestureRecognizer *gesture = task[@"gesture"];
        Ivar ivar = class_getInstanceVariable([self class], "課傳");
        id targetView = [gesture view];
        while (targetView && ![NSStringFromClass([targetView class]) containsString:@"課視圖"] && ![NSStringFromClass([targetView class]) containsString:@"傳視圖"]) { targetView = [targetView superview]; }
        if (ivar && targetView) object_setIvar(self, ivar, targetView);
        
        SEL action = NSSelectorFromString(@"顯示課傳摘要WithSender:");
        if (![self respondsToSelector:action]) action = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");

        if ([self respondsToSelector:action]) {
            [self performSelector:action withObject:gesture];
        } else {
            LogMessage(@"错误! 方法不存在。");
            [g_workQueue removeObjectAtIndex:0]; [self processWorkQueue_FinalTruth];
        }
    }
    #pragma clang diagnostic pop
}

%end
