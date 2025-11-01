#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局状态管理
// =========================================================================
static BOOL g_isExtractingTianDiPanDetail = NO;
static NSMutableArray<CALayer *> *g_tianDiPanWorkQueue = nil;
static NSMutableArray<NSString *> *g_tianDiPanTitleQueue = nil;
static NSMutableDictionary<NSString *, NSString *> *g_tianDiPanResults = nil;
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));

static UIView *g_test_plateView = nil;
static UITapGestureRecognizer *g_realTapGesture = nil; // 【新】存储真实的点击手势
static IMP g_original_locationInView_IMP = NULL; // 【新】存储 locationInView 的原始实现

// =========================================================================
// 2. 核心辅助函数
// =========================================================================
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if (!view || !storage) return; if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) { if (!object || !ivarNameSuffix) return nil; unsigned int ivarCount; Ivar *ivars = class_copyIvarList([object class], &ivarCount); if (!ivars) { free(ivars); return nil; } id value = nil; for (unsigned int i = 0; i < ivarCount; i++) { Ivar ivar = ivars[i]; const char *name = ivar_getName(ivar); if (name) { NSString *ivarName = [NSString stringWithUTF8String:name]; if ([ivarName hasSuffix:ivarNameSuffix]) { value = object_getIvar(object, ivar); break; } } } free(ivars); return value; }
static NSString* extractTextFromGenericPopupView(UIView *popupView) { NSMutableArray<UILabel *> *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], popupView, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) { return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)]; }]; NSMutableString *result = [NSMutableString string]; for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [result appendFormat:@"%@\n", [label.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]; } } return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; }

// =========================================================================
// 3. 【新】运行时替换的核心代码
// =========================================================================
static CGPoint hooked_locationInView(id self, SEL _cmd, UIView *view) {
    // 这个函数是新的 locationInView 实现
    // 它会从一个我们能控制的地方返回坐标
    NSValue *pointValue = objc_getAssociatedObject(self, @selector(hooked_locationInView));
    if (pointValue) {
        return [pointValue CGPointValue];
    }
    // 如果没有设置，调用原始实现以防万一
    return ((CGPoint (*)(id, SEL, UIView*))g_original_locationInView_IMP)(self, _cmd, view);
}

// 前向声明
@interface UIViewController (EchoTest)
- (void)handleTianDiPanTestButtonTap;
- (void)startExtraction_TianDiPanDetails;
- (void)processTianDiPanDetailsQueue;
@end

// =========================================================================
// 4. 核心Hook与方法实现
// =========================================================================

%hook UIViewController

// 拦截弹窗
static void Tweak_presentViewController(UIViewController *self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    if (g_isExtractingTianDiPanDetail) {
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);

        // 【修复】使用从FLEX中确认的正确弹窗类名
        // 同时处理两种可能的弹窗（宫位摘要/天将摘要）
        if ([vcClassName containsString:@"天地盤宮位摘要視圖"] || [vcClassName containsString:@"課傳天將摘要視圖"]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *extractedText = extractTextFromGenericPopupView(vcToPresent.view);
                NSString *currentTitle = g_tianDiPanTitleQueue.firstObject;
                if (currentTitle) {
                    g_tianDiPanResults[currentTitle] = extractedText;
                    [g_tianDiPanTitleQueue removeObjectAtIndex:0];
                }
                [self processTianDiPanDetailsQueue];
            });
            return; // 拦截成功，不再显示弹窗
        }
    }
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

// 添加测试按钮
- (void)viewDidLoad { %orig; Class targetClass = NSClassFromString(@"六壬大占.ViewController"); if (targetClass && [self isKindOfClass:targetClass]) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem]; testButton.frame = CGRectMake(self.view.bounds.size.width - 120, self.view.bounds.size.height - 60, 100, 44); [testButton setTitle:@"天地盘测试" forState:UIControlStateNormal]; testButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.6 blue:0.0 alpha:1.0]; [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; testButton.layer.cornerRadius = 8; testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16]; [testButton addTarget:self action:@selector(handleTianDiPanTestButtonTap) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:testButton]; NSLog(@"[EchoTest] 测试按钮已添加。"); }); } }

// 按钮点击事件
%new - (void)handleTianDiPanTestButtonTap { [self startExtraction_TianDiPanDetails]; }

// 启动提取流程
%new
- (void)startExtraction_TianDiPanDetails {
    if (g_isExtractingTianDiPanDetail) { NSLog(@"[EchoTest] 提取任务正在进行中。"); return; }
    NSLog(@"[EchoTest] 任务启动...");
    
    g_isExtractingTianDiPanDetail = YES;
    g_tianDiPanWorkQueue = [NSMutableArray array]; g_tianDiPanTitleQueue = [NSMutableArray array]; g_tianDiPanResults = [NSMutableDictionary dictionary];

    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    NSMutableArray *plateViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);
    if (plateViews.count == 0) { NSLog(@"[EchoTest] 错误: 找不到天地盘视图实例。"); g_isExtractingTianDiPanDetail = NO; return; }
    
    g_test_plateView = plateViews.firstObject;

    // 【新】找到并存储真实的手势对象
    for (UIGestureRecognizer *gesture in g_test_plateView.gestureRecognizers) {
        if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
            g_realTapGesture = (UITapGestureRecognizer *)gesture;
            break;
        }
    }
    if (!g_realTapGesture) { NSLog(@"[EchoTest] 错误: 找不到天地盘的点击手势。"); g_isExtractingTianDiPanDetail = NO; return; }

    id diGongDict = GetIvarValueSafely(g_test_plateView, @"地宮宮名列"); id tianShenDict = GetIvarValueSafely(g_test_plateView, @"天神宮名列"); id tianJiangDict = GetIvarValueSafely(g_test_plateView, @"天將宮名列");
    if (!diGongDict || !tianShenDict || !tianJiangDict) { NSLog(@"[EchoTest] 错误: 无法获取宫名列表。"); g_isExtractingTianDiPanDetail = NO; return; }

    void (^addLayersToQueue)(NSDictionary *, NSString *) = ^(NSDictionary *layerDict, NSString *type) { for (NSString *key in layerDict) { id layer = layerDict[key]; if (layer && [layer isKindOfClass:[CALayer class]]) { [g_tianDiPanWorkQueue addObject:layer]; [g_tianDiPanTitleQueue addObject:[NSString stringWithFormat:@"%@ - %@", type, key]]; } } };
    addLayersToQueue(diGongDict, @"地盘"); addLayersToQueue(tianShenDict, @"天盘"); addLayersToQueue(tianJiangDict, @"天将");

    if (g_tianDiPanWorkQueue.count == 0) { NSLog(@"[EchoTest] 错误: 任务队列为空。"); g_isExtractingTianDiPanDetail = NO; return; }
    
    NSLog(@"[EchoTest] 任务队列构建完成，总计 %lu 项。", (unsigned long)g_tianDiPanWorkQueue.count);
    [self processTianDiPanDetailsQueue];
}

// 核心处理函数
%new
- (void)processTianDiPanDetailsQueue {
    if (g_tianDiPanWorkQueue.count == 0) {
        NSLog(@"[EchoTest] ======== 天地盘详情提取完成 ========");
        NSArray *sortedKeys = [g_tianDiPanResults.allKeys sortedArrayUsingSelector:@selector(localizedCompare:)];
        for (NSString *key in sortedKeys) { NSLog(@"\n--- %@ ---\n%@", key, g_tianDiPanResults[key]); }
        NSLog(@"[EchoTest] =======================================");

        g_isExtractingTianDiPanDetail = NO; /* ... 清理其他全局变量 ... */
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试完成" message:[NSString stringWithFormat:@"已成功提取 %lu 条天地盘详情，请检查Xcode或Console日志。", (unsigned long)g_tianDiPanResults.count] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    CALayer *targetLayer = g_tianDiPanWorkQueue.firstObject;
    [g_tianDiPanWorkQueue removeObjectAtIndex:0];
    
    // ======================【终极闪退修复核心】======================
    // 1. 准备要伪造的坐标
    CGPoint targetPosition = targetLayer.position;
    objc_setAssociatedObject(g_realTapGesture, @selector(hooked_locationInView), [NSValue valueWithCGPoint:targetPosition], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // 2. “劫持” locationInView 方法
    Method locationMethod = class_getInstanceMethod([UITapGestureRecognizer class], @selector(locationInView:));
    g_original_locationInView_IMP = method_setImplementation(locationMethod, (IMP)hooked_locationInView);
    // ===============================================================

    // 3. 使用【真实手势】调用【正确方法名】
    SEL selector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
    if ([self respondsToSelector:selector]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:selector withObject:g_realTapGesture];
        #pragma clang diagnostic pop
    } else {
        NSLog(@"[EchoTest] 严重错误: 找不到目标方法 '顯示天地盤觸摸WithSender:'");
        [self processTianDiPanDetailsQueue];
    }
    
    // ======================【清理】======================
    // 4. (关键) 立即恢复原始方法，避免影响App正常使用
    method_setImplementation(locationMethod, g_original_locationInView_IMP);
    objc_setAssociatedObject(g_realTapGesture, @selector(hooked_locationInView), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // ===============================================================
}

%end

// =========================================================================
// 5. Tweak加载入口
// =========================================================================
%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[EchoTest] 天地盘详情提取测试脚本已加载 (v1.6 终极版)。");
    }
}
