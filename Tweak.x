#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量、常量定义与辅助函数
// =========================================================================

#pragma mark - Global State & Flags
static BOOL g_isExtractingTianDiPanDetail = NO;
static NSMutableArray<NSDictionary *> *g_tianDiPan_workQueue = nil;
static NSMutableArray<NSString *> *g_tianDiPan_resultsArray = nil;
static void (^g_tianDiPan_completion_handler)(NSString *result) = nil;


#pragma mark - 辅助函数 & 私有接口声明
@interface UIEvent (Private)
- (void)_addTouch:(id)touch forDelayedDelivery:(BOOL)arg2;
@end
@interface UITouch (Private)
- (void)setTimestamp:(NSTimeInterval)timestamp;
- (void)setPhase:(UITouchPhase)phase;
- (void)setTapCount:(NSUInteger)tapCount;
- (void)_setLocationInWindow:(CGPoint)location resetPrevious:(BOOL)reset;
- (void)_setWindow:(UIWindow *)window;
@end


static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) { if (window.isKeyWindow) { frontmostWindow = window; break; } }
                if (frontmostWindow) break;
            }
        }
    }
    if (!frontmostWindow) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        frontmostWindow = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
    }
    return frontmostWindow;
}

typedef NS_ENUM(NSInteger, EchoLogType) { EchoLogTypeDebug, EchoLogTypeInfo, EchoLogTypeSuccess, EchoLogTypeWarning, EchoLogError };
static void EchoLog(EchoLogType type, NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSString *prefix;
    switch (type) {
        case EchoLogTypeDebug:   prefix = @"[🛠️ DEBUG]"; break;
        case EchoLogTypeInfo:    prefix = @"[ℹ️ INFO]"; break;
        case EchoLogTypeSuccess: prefix = @"[✅ SUCCESS]"; break;
        case EchoLogTypeWarning: prefix = @"[⚠️ WARN]"; break;
        case EchoLogError:       prefix = @"[❌ ERROR]"; break;
    }
    NSLog(@"[EchoTDP] %@ %@", prefix, message);
}

// =========================================================================
// 2. 核心接口与 Tweak 实现
// =========================================================================
@interface UIViewController (EchoTianDiPanExtractor)
- (void)ECHO_injectTianDiPanButton;
- (void)ECHO_startTianDiPanExtraction;
- (void)ECHO_processTianDiPanQueue;
- (NSArray<NSDictionary *> *)ECHO_getTianDiPanClickableTargets;
- (NSString *)ECHO_getStringFromLayer:(id)layer;
- (id)ECHO_getIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix;
- (NSString *)ECHO_extractDataFromStandardPopup:(UIView *)contentView;
@end

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    if (g_isExtractingTianDiPanDetail) {
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
        if ([vcClassName isEqualToString:@"六壬大占.天將摘要視圖"] || [vcClassName isEqualToString:@"六壬大占.天地盤宮位摘要視圖"]) {
            EchoLog(EchoLogTypeDebug, @"拦截到目标弹窗: %@, 准备隐形加载...", vcClassName);
            vcToPresent.view.alpha = 0.0f;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                EchoLog(EchoLogTypeDebug, @"弹窗数据应已加载，开始提取...");
                NSString *extractedText = [self ECHO_extractDataFromStandardPopup:vcToPresent.view];
                [g_tianDiPan_resultsArray addObject:extractedText];
                EchoLog(EchoLogTypeSuccess, @"提取成功, 内容长度: %lu", (unsigned long)extractedText.length);
                [vcToPresent dismissViewControllerAnimated:NO completion:^{
                    EchoLog(EchoLogTypeDebug, @"隐形弹窗已销毁，继续处理下一个任务...");
                    [self ECHO_processTianDiPanQueue];
                }];
            });
            Original_presentViewController(self, _cmd, vcToPresent, NO, nil);
            return;
        }
    }
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

%hook UIViewController
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self ECHO_injectTianDiPanButton];
        });
    }
}
%new
- (void)ECHO_injectTianDiPanButton {
    UIWindow *keyWindow = GetFrontmostWindow();
    if (!keyWindow || [keyWindow viewWithTag:12345]) return;
    UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
    testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 85, 140, 36);
    testButton.tag = 12345;
    [testButton setTitle:@"提取天地盘详情" forState:UIControlStateNormal];
    testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    testButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
    [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    testButton.layer.cornerRadius = 18;
    [testButton addTarget:self action:@selector(ECHO_startTianDiPanExtraction) forControlEvents:UIControlEventTouchUpInside];
    [keyWindow addSubview:testButton];
    EchoLog(EchoLogTypeInfo, @"测试按钮已成功注入到主界面。");
}
%new
- (void)ECHO_startTianDiPanExtraction {
    if (g_isExtractingTianDiPanDetail) {
        EchoLog(EchoLogTypeWarning, @"任务已在进行中，请勿重复点击。");
        return;
    }
    EchoLog(EchoLogTypeInfo, @"==================== 任务启动 ====================");
    g_isExtractingTianDiPanDetail = YES;
    g_tianDiPan_workQueue = [NSMutableArray array];
    g_tianDiPan_resultsArray = [NSMutableArray array];
    g_tianDiPan_completion_handler = ^(NSString *finalResult){
        NSLog(@"[EchoTDP] [✅ FINAL RESULT] \n%@", finalResult);
        UIPasteboard.generalPasteboard.string = finalResult;
        EchoLog(EchoLogTypeSuccess, @"所有天地盘详情提取完毕，结果已打印并复制到剪贴板！");
    };
    NSArray<NSDictionary *> *targets = [self ECHO_getTianDiPanClickableTargets];
    if (!targets || targets.count == 0) {
        EchoLog(EchoLogError, @"未能获取任何可点击的目标，任务中止。");
        g_isExtractingTianDiPanDetail = NO;
        return;
    }
    [g_tianDiPan_workQueue addObjectsFromArray:targets];
    EchoLog(EchoLogTypeInfo, @"成功定位到 %lu 个可点击目标，已创建工作队列。", (unsigned long)g_tianDiPan_workQueue.count);
    [self ECHO_processTianDiPanQueue];
}

// MARK: v1.3 - 核心修正点
%new
- (void)ECHO_processTianDiPanQueue {
    if (g_tianDiPan_workQueue.count == 0) {
        EchoLog(EchoLogTypeSuccess, @"所有任务处理完毕，正在整理最终报告...");
        NSMutableString *report = [NSMutableString string];
        for (NSString *result in g_tianDiPan_resultsArray) {
            [report appendString:result]; [report appendString:@"\n--------------------\n"];
        }
        if (g_tianDiPan_completion_handler) { g_tianDiPan_completion_handler(report); }
        g_isExtractingTianDiPanDetail = NO; g_tianDiPan_workQueue = nil; g_tianDiPan_resultsArray = nil; g_tianDiPan_completion_handler = nil;
        EchoLog(EchoLogTypeInfo, @"==================== 任务结束 ====================");
        return;
    }

    NSDictionary *task = g_tianDiPan_workQueue.firstObject;
    [g_tianDiPan_workQueue removeObjectAtIndex:0];
    EchoLog(EchoLogTypeInfo, @"处理任务 %lu/%lu: %@ (%@)",
            (unsigned long)(g_tianDiPan_resultsArray.count + 1),
            (unsigned long)(g_tianDiPan_resultsArray.count + g_tianDiPan_workQueue.count + 1),
            task[@"name"], task[@"type"]);
            
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    if (!plateViewClass) {
        EchoLog(EchoLogError, @"找不到天地盘视图类 `天地盤視圖類`，跳过任务。");
        [self ECHO_processTianDiPanQueue]; return;
    }
    
    // MARK: 关键修正 - 搜索整个 window，而不是 self.view
    UIWindow *keyWindow = GetFrontmostWindow();
    NSMutableArray *plateViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
    
    if (plateViews.count == 0) {
        EchoLog(EchoLogError, @"在当前窗口中找不到天地盘视图实例，跳过任务。");
        [self ECHO_processTianDiPanQueue]; return;
    }
    UIView *plateView = plateViews.firstObject;

    UITapGestureRecognizer *gesture = nil;
    for (UIGestureRecognizer *g in plateView.gestureRecognizers) {
        if ([g isKindOfClass:[UITapGestureRecognizer class]]) { gesture = (UITapGestureRecognizer *)g; break; }
    }
    if (!gesture) {
        EchoLog(EchoLogError, @"在天地盘视图上找不到 UITapGestureRecognizer，跳过任务。");
        [self ECHO_processTianDiPanQueue]; return;
    }

    @try {
        UIWindow *window = plateView.window;
        if (!window) {
            EchoLog(EchoLogError, @"plateView 没有关联的 window，无法创建事件，跳过任务。");
            [self ECHO_processTianDiPanQueue]; return;
        }
        CGPoint targetPosition = [task[@"position"] CGPointValue];
        
        UITouch *touch = [[UITouch alloc] init];
        [touch setTimestamp:[NSDate date].timeIntervalSince1970];
        [touch setTapCount:1];
        [touch _setWindow:window];
        [touch _setLocationInWindow:targetPosition resetPrevious:YES];

        UIEvent *event = [[NSClassFromString(@"UITouchesEvent") alloc] init];
        [event _addTouch:touch forDelayedDelivery:NO];

        [touch setPhase:UITouchPhaseBegan];
        NSSet *touches = [NSSet setWithObject:touch];
        [gesture touchesBegan:touches withEvent:event];

        [touch setPhase:UITouchPhaseEnded];
        [gesture touchesEnded:touches withEvent:event];
        
        EchoLog(EchoLogTypeDebug, @"已成功分发伪造的 Touch 事件到坐标 {%.2f, %.2f}", targetPosition.x, targetPosition.y);

    } @catch (NSException *exception) {
        EchoLog(EchoLogError, @"伪造 Touch 事件时发生异常: %@", exception.reason);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self ECHO_processTianDiPanQueue];
        });
    }
}

%new
- (NSString *)ECHO_extractDataFromStandardPopup:(UIView *)contentView {
    NSMutableArray<NSString *> *finalTextParts = [NSMutableArray array];
    NSMutableArray *allStackViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UIStackView class], contentView, allStackViews);
    if (allStackViews.count > 0) {
        UIStackView *mainStackView = allStackViews.firstObject;
        for (UIView *subview in mainStackView.arrangedSubviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                NSString *text = ((UILabel *)subview).text; if (text && text.length > 0) [finalTextParts addObject:text];
            } else if ([subview isKindOfClass:NSClassFromString(@"六壬大占.IntrinsicTableView")]) {
                UITableView *tableView = (UITableView *)subview;
                id<UITableViewDataSource> dataSource = tableView.dataSource;
                if (dataSource) {
                    NSInteger sections = [dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)] ? [dataSource numberOfSectionsInTableView:tableView] : 1;
                    for (NSInteger s = 0; s < sections; s++) {
                        NSInteger rows = [dataSource tableView:tableView numberOfRowsInSection:s];
                        for (NSInteger r = 0; r < rows; r++) {
                            UITableViewCell *cell = [dataSource tableView:tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:r inSection:s]];
                            if (cell) {
                                NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labels);
                                [labels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2){ return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)]; }];
                                NSMutableArray<NSString *> *cellParts = [NSMutableArray array];
                                for(UILabel *l in labels) { if(l.text.length > 0) [cellParts addObject:l.text]; }
                                [finalTextParts addObject:[cellParts componentsJoinedByString:@" "]];
                            }
                        }
                    }
                }
            }
        }
    } else {
        EchoLog(EchoLogTypeWarning, @"在弹窗中未找到主 UIStackView，将尝试全局 UILabel 提取。");
        NSMutableArray *allLabels = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
        for(UILabel *l in allLabels) { if (l.text.length > 0) [finalTextParts addObject:l.text]; }
    }
    return [finalTextParts componentsJoinedByString:@"\n"];
}

// MARK: v1.3 - 核心修正点
%new
- (NSArray<NSDictionary *> *)ECHO_getTianDiPanClickableTargets {
    @try {
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
        if (!plateViewClass) { EchoLog(EchoLogError, @"定位失败: 找不到视图类 `天地盤視圖類`"); return nil; }

        // MARK: 关键修正 - 搜索整个 window，而不是 self.view
        UIWindow *keyWindow = GetFrontmostWindow();
        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
        
        if (plateViews.count == 0) { EchoLog(EchoLogError, @"定位失败: 在当前窗口中找不到视图实例"); return nil; }

        UIView *plateView = plateViews.firstObject;
        id diGongDict = [self ECHO_getIvarValueSafely:plateView ivarNameSuffix:@"地宮宮名列"];
        id tianJiangDict = [self ECHO_getIvarValueSafely:plateView ivarNameSuffix:@"天將宮名列"];

        if (!diGongDict || !tianJiangDict) { EchoLog(EchoLogError, @"定位失败: 未能获取核心数据字典"); return nil; }
        
        NSMutableArray<NSDictionary *> *targets = [NSMutableArray array];
        for (id key in [diGongDict allKeys]) {
            CALayer *layer = diGongDict[key];
            if (layer && [layer isKindOfClass:[CALayer class]]) {
                NSString *name = [self ECHO_getStringFromLayer:layer];
                CGPoint position = [plateView.layer convertPoint:layer.position fromLayer:layer.superlayer];
                [targets addObject:@{ @"name": name, @"type": @"gongWei", @"position": [NSValue valueWithCGPoint:position] }];
            }
        }
        for (id key in [tianJiangDict allKeys]) {
            CALayer *layer = tianJiangDict[key];
            if (layer && [layer isKindOfClass:[CALayer class]]) {
                NSString *name = [self ECHO_getStringFromLayer:layer];
                CGPoint position = [plateView.layer convertPoint:layer.position fromLayer:layer.superlayer];
                [targets addObject:@{ @"name": name, @"type": @"tianJiang", @"position": [NSValue valueWithCGPoint:position] }];
            }
        }
        return [targets copy];
    } @catch (NSException *exception) {
        EchoLog(EchoLogError, @"定位异常: %@", exception.reason);
        return nil;
    }
}

%new
- (id)ECHO_getIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix {
    if (!object || !ivarNameSuffix) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) { free(ivars); return nil; }
    id value = nil;
    for (unsigned int i = 0; i < ivarCount; i++) {
        const char *name = ivar_getName(ivars[i]);
        if (name) {
            NSString *ivarName = [NSString stringWithUTF8String:name];
            if ([ivarName hasSuffix:ivarNameSuffix]) { value = object_getIvar(object, ivars[i]); break; }
        }
    }
    free(ivars);
    return value;
}

%new
- (NSString *)ECHO_getStringFromLayer:(id)layer {
    if (layer && [layer respondsToSelector:@selector(string)]) {
        id stringValue = [layer valueForKey:@"string"];
        if ([stringValue isKindOfClass:[NSString class]]) return stringValue;
        if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string;
    }
    return @"?";
}
%end

%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[EchoTDP] 天地盘独立提取脚本 v1.3 (全局搜索修正版) 已加载。");
    }
}
