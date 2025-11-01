#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量、常量定义与辅助函数
// =========================================================================

#pragma mark - Global State & Flags

// 任务控制旗标
static BOOL g_isExtractingTianDiPanDetail = NO;
// 工作队列：存储所有待点击的目标信息
static NSMutableArray<NSDictionary *> *g_tianDiPan_workQueue = nil;
// 结果数组：存储从每个弹窗中提取到的文本
static NSMutableArray<NSString *> *g_tianDiPan_resultsArray = nil;
// 最终完成时的回调 Block
static void (^g_tianDiPan_completion_handler)(NSString *result) = nil;


#pragma mark - 辅助函数

// 递归查找指定类的所有子视图
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}

// 获取最顶层的 Window
static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        frontmostWindow = window;
                        break;
                    }
                }
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

// 详细的日志系统
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


// 核心拦截函数
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    // 检查是否是我们的任务在运行
    if (g_isExtractingTianDiPanDetail) {
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
        
        // 检查是否是我们想要拦截的目标弹窗
        if ([vcClassName isEqualToString:@"六壬大占.天將摘要視圖"] || 
            [vcClassName isEqualToString:@"六壬大占.天地盤宮位摘要視圖"]) {
            
            EchoLog(EchoLogTypeDebug, @"拦截到目标弹窗: %@, 准备隐形加载...", vcClassName);
            
            // 1. 让它在后台加载，但完全透明，用户看不到
            vcToPresent.view.alpha = 0.0f;
            
            // 2. 延迟执行，给弹窗的 viewDidLoad 和 viewWillAppear 留出加载数据的时间
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                EchoLog(EchoLogTypeDebug, @"弹窗数据应已加载，开始提取...");
                
                // 3. 调用统一的提取函数
                NSString *extractedText = [self ECHO_extractDataFromStandardPopup:vcToPresent.view];
                [g_tianDiPan_resultsArray addObject:extractedText];
                
                EchoLog(EchoLogTypeSuccess, @"提取成功, 内容长度: %lu", (unsigned long)extractedText.length);

                // 4. 立即销毁这个隐形的弹窗
                [vcToPresent dismissViewControllerAnimated:NO completion:^{
                    EchoLog(EchoLogTypeDebug, @"隐形弹窗已销毁，继续处理下一个任务...");
                    // 5. 继续处理工作队列中的下一个任务
                    [self ECHO_processTianDiPanQueue];
                }];
            });

            // 6. 调用原始的 present 方法，让这个透明的 vc 加载起来
            Original_presentViewController(self, _cmd, vcToPresent, NO, nil); // 使用 NO 禁止动画
            
            // 7. 阻止后续代码执行，我们的任务已接管
            return; 
        }
    }
    
    // 如果不是我们的任务，就按正常流程走
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}


%hook UIViewController

// 在主界面加载后，注入我们的测试按钮
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self ECHO_injectTianDiPanButton];
        });
    }
}

// =========================================================================
// 3. 新增的独立功能实现
// =========================================================================

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
    
    // 1. 设置状态
    g_isExtractingTianDiPanDetail = YES;
    g_tianDiPan_workQueue = [NSMutableArray array];
    g_tianDiPan_resultsArray = [NSMutableArray array];
    // 这里可以设置一个完成回调，但为了独立性，我们直接在队列处理完后打印结果
    g_tianDiPan_completion_handler = ^(NSString *finalResult){
        NSLog(@"[EchoTDP] [✅ FINAL RESULT] \n%@", finalResult);
        UIPasteboard.generalPasteboard.string = finalResult;
        EchoLog(EchoLogTypeSuccess, @"所有天地盘详情提取完毕，结果已打印并复制到剪贴板！");
    };

    // 2. 获取所有可点击的目标
    NSArray<NSDictionary *> *targets = [self ECHO_getTianDiPanClickableTargets];
    if (!targets || targets.count == 0) {
        EchoLog(EchoLogError, @"未能获取任何可点击的目标，任务中止。");
        g_isExtractingTianDiPanDetail = NO;
        return;
    }
    [g_tianDiPan_workQueue addObjectsFromArray:targets];
    EchoLog(EchoLogTypeInfo, @"成功定位到 %lu 个可点击目标，已创建工作队列。", (unsigned long)g_tianDiPan_workQueue.count);

    // 3. 开始处理队列
    [self ECHO_processTianDiPanQueue];
}

%new
- (void)ECHO_processTianDiPanQueue {
    // 检查任务是否完成
    if (g_tianDiPan_workQueue.count == 0) {
        EchoLog(EchoLogTypeSuccess, @"所有任务处理完毕，正在整理最终报告...");
        
        NSMutableString *report = [NSMutableString string];
        for (NSString *result in g_tianDiPan_resultsArray) {
            [report appendString:result];
            [report appendString:@"\n--------------------\n"];
        }
        
        if (g_tianDiPan_completion_handler) {
            g_tianDiPan_completion_handler(report);
        }

        // 清理状态
        g_isExtractingTianDiPanDetail = NO;
        g_tianDiPan_workQueue = nil;
        g_tianDiPan_resultsArray = nil;
        g_tianDiPan_completion_handler = nil;
        EchoLog(EchoLogTypeInfo, @"==================== 任务结束 ====================");
        return;
    }

    // 从队列中取出一个任务
    NSDictionary *task = g_tianDiPan_workQueue.firstObject;
    [g_tianDiPan_workQueue removeObjectAtIndex:0];
    
    EchoLog(EchoLogTypeInfo, @"处理任务 %lu/%lu: %@ (%@)",
            (unsigned long)(g_tianDiPan_resultsArray.count + 1),
            (unsigned long)(g_tianDiPan_resultsArray.count + g_tianDiPan_workQueue.count + 1),
            task[@"name"], task[@"type"]);

    // 找到天地盘视图和它的手势识别器
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    if (!plateViewClass) {
        EchoLog(EchoLogError, @"找不到天地盘视图类，无法继续。");
        [self ECHO_processTianDiPanQueue]; // 跳过这个任务
        return;
    }
    
    NSMutableArray *plateViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);
    if (plateViews.count == 0) {
        EchoLog(EchoLogError, @"找不到天地盘视图实例，无法继续。");
        [self ECHO_processTianDiPanQueue];
        return;
    }
    UIView *plateView = plateViews.firstObject;

    UITapGestureRecognizer *gesture = nil;
    for (UIGestureRecognizer *g in plateView.gestureRecognizers) {
        if ([g isKindOfClass:[UITapGestureRecognizer class]]) {
            gesture = (UITapGestureRecognizer *)g;
            break;
        }
    }
    
    if (!gesture) {
        EchoLog(EchoLogError, @"在天地盘视图上找不到 UITapGestureRecognizer，无法继续。");
        [self ECHO_processTianDiPanQueue];
        return;
    }

    // 核心步骤：伪造点击坐标并触发 Action
    @try {
        CGPoint targetPosition = [task[@"position"] CGPointValue];
        EchoLog(EchoLogTypeDebug, @"伪造点击坐标: {%.2f, %.2f}", targetPosition.x, targetPosition.y);
        
        // 使用 KVC 强行设置私有 Ivar
        [gesture setValue:[NSValue valueWithCGPoint:targetPosition] forKey:@"_locationInView"];
        
        // MARK: 错误修正 1
        // `valueForKey:`返回`id`，需要强制转换为`NSArray`才能使用`.firstObject`
        id targets = [gesture valueForKey:@"_targets"];
        if (![targets respondsToSelector:@selector(firstObject)]) {
             EchoLog(EchoLogError, @"手势识别器的'targets'属性不是一个有效的数组。");
             [self ECHO_processTianDiPanQueue];
             return;
        }
        id target = [(NSArray *)targets firstObject]; 
        
        id targetIvar = [self ECHO_getIvarValueSafely:target ivarNameSuffix:@"_target"];
        SEL action = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
        
        if (targetIvar && [targetIvar respondsToSelector:action]) {
            EchoLog(EchoLogTypeDebug, @"手动触发 Action: %@", NSStringFromSelector(action));
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [targetIvar performSelector:action withObject:gesture];
            #pragma clang diagnostic pop
        } else {
            EchoLog(EchoLogError, @"无法获取到有效的 target 或 target 不响应 action。");
            [self ECHO_processTianDiPanQueue];
        }
    } @catch (NSException *exception) {
        EchoLog(EchoLogError, @"伪造点击时发生异常: %@", exception.reason);
        [self ECHO_processTianDiPanQueue];
    }
}

// 提取弹窗内容的统一函数 (复用你旧脚本的逻辑)
%new
- (NSString *)ECHO_extractDataFromStandardPopup:(UIView *)contentView {
    NSMutableArray<NSString *> *finalTextParts = [NSMutableArray array];
    NSMutableArray *allStackViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UIStackView class], contentView, allStackViews);

    if (allStackViews.count > 0) {
        UIStackView *mainStackView = allStackViews.firstObject;
        for (UIView *subview in mainStackView.arrangedSubviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                NSString *text = ((UILabel *)subview).text;
                if (text && text.length > 0) [finalTextParts addObject:text];
            } 
            else if ([subview isKindOfClass:NSClassFromString(@"六壬大占.IntrinsicTableView")]) {
                UITableView *tableView = (UITableView *)subview;
                id<UITableViewDataSource> dataSource = tableView.dataSource;
                if (dataSource) {
                    NSInteger sections = 1;
                    if ([dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]) {
                        sections = [dataSource numberOfSectionsInTableView:tableView];
                    }
                    for (NSInteger s = 0; s < sections; s++) {
                        NSInteger rows = [dataSource tableView:tableView numberOfRowsInSection:s];
                        for (NSInteger r = 0; r < rows; r++) {
                            UITableViewCell *cell = [dataSource tableView:tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:r inSection:s]];
                            if (cell) {
                                NSMutableArray *labels = [NSMutableArray array];
                                FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labels);
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
        // MARK: 错误修正 2
        // 笔误 EchoLogWarning -> EchoLogTypeWarning
        EchoLog(EchoLogTypeWarning, @"在弹窗中未找到主 UIStackView，将尝试全局 UILabel 提取。");
        NSMutableArray *allLabels = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
        for(UILabel *l in allLabels) { if (l.text.length > 0) [finalTextParts addObject:l.text]; }
    }

    return [finalTextParts componentsJoinedByString:@"\n"];
}

// 获取天地盘所有可点击目标的坐标 (基于 V18 逻辑修改)
%new
- (NSArray<NSDictionary *> *)ECHO_getTianDiPanClickableTargets {
    @try {
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
        // MARK: 错误修正 3 (批量)
        // C 字符串 "..." -> OC 字符串 @"..."
        if (!plateViewClass) { EchoLog(EchoLogError, @"定位失败: 找不到视图类"); return nil; }

        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);
        if (plateViews.count == 0) { EchoLog(EchoLogError, @"定位失败: 找不到视图实例"); return nil; }

        UIView *plateView = plateViews.firstObject;
        id diGongDict = [self ECHO_getIvarValueSafely:plateView ivarNameSuffix:@"地宮宮名列"];
        id tianJiangDict = [self ECHO_getIvarValueSafely:plateView ivarNameSuffix:@"天將宮名列"];

        if (!diGongDict || !tianJiangDict) { EchoLog(EchoLogError, @"定位失败: 未能获取核心数据字典"); return nil; }

        NSMutableArray<NSDictionary *> *targets = [NSMutableArray array];
        
        // 提取地宫（宫位）目标
        for (id key in [diGongDict allKeys]) {
            CALayer *layer = diGongDict[key];
            if (layer && [layer isKindOfClass:[CALayer class]]) {
                NSString *name = [self ECHO_getStringFromLayer:layer];
                // MARK: 错误修正 4 (批量) & 逻辑优化
                // CALayer没有superview，但我们可以用convertPoint:fromLayer:并传入nil来从窗口坐标系转换，更稳定。
                // 我们需要的是layer在其父layer中的position，然后将这个点从父layer的坐标系转换到plateView的坐标系。
                CGPoint pointInSuperlayer = layer.position;
                CGPoint position = [plateView.layer convertPoint:pointInSuperlayer fromLayer:layer.superlayer];
                [targets addObject:@{
                    @"name": name,
                    @"type": @"gongWei",
                    @"position": [NSValue valueWithCGPoint:position]
                }];
            }
        }

        // 提取天将目标
        for (id key in [tianJiangDict allKeys]) {
            CALayer *layer = tianJiangDict[key];
            if (layer && [layer isKindOfClass:[CALayer class]]) {
                NSString *name = [self ECHO_getStringFromLayer:layer];
                CGPoint pointInSuperlayer = layer.position;
                CGPoint position = [plateView.layer convertPoint:pointInSuperlayer fromLayer:layer.superlayer];
                [targets addObject:@{
                    @"name": name,
                    @"type": @"tianJiang",
                    @"position": [NSValue valueWithCGPoint:position]
                }];
            }
        }
        
        return [targets copy];
        
    } @catch (NSException *exception) {
        // MARK: 错误修正 5
        EchoLog(EchoLogError, @"定位异常: %@", exception.reason);
        return nil;
    }
}


// 安全获取 Ivar 值的辅助函数
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
            if ([ivarName hasSuffix:ivarNameSuffix]) {
                value = object_getIvar(object, ivars[i]);
                break;
            }
        }
    }
    free(ivars);
    return value;
}

// 从 CALayer 获取文本的辅助函数
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
        NSLog(@"[EchoTDP] 天地盘独立提取脚本 v1.1 (已修复) 已加载。");
    }
}

