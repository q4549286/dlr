#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局状态管理
// =========================================================================
static BOOL g_isExtractingTianDiPanDetail = NO;
static NSMutableArray<UIButton *> *g_tianDiPanButtonQueue = nil; // 【新】队列现在存储安全的UIButton
static NSMutableArray<NSString *> *g_tianDiPanTitleQueue = nil;
static NSMutableDictionary<NSString *, NSString *> *g_tianDiPanResults = nil;
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static UIView *g_overlayContainerView = nil; // 【新】用于存放我们创建的36个按钮

// =========================================================================
// 2. 辅助函数
// =========================================================================
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if (!view || !storage) return; if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) { if (!object || !ivarNameSuffix) return nil; unsigned int ivarCount; Ivar *ivars = class_copyIvarList([object class], &ivarCount); if (!ivars) { free(ivars); return nil; } id value = nil; for (unsigned int i = 0; i < ivarCount; i++) { Ivar ivar = ivars[i]; const char *name = ivar_getName(ivar); if (name) { NSString *ivarName = [NSString stringWithUTF8String:name]; if ([ivarName hasSuffix:ivarNameSuffix]) { value = object_getIvar(object, ivar); break; } } } free(ivars); return value; }
static NSString* extractTextFromGenericPopupView(UIView *popupView) { NSMutableArray<UILabel *> *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], popupView, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) { return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)]; }]; NSMutableString *result = [NSMutableString string]; for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [result appendFormat:@"%@\n", [label.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]; } } return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; }

// 前向声明
@interface UIViewController (EchoTest)
- (void)handleTianDiPanTestButtonTap;
- (void)startExtraction_TianDiPanDetails;
- (void)processTianDiPanDetailsQueue;
@end

// =========================================================================
// 3. 核心Hook与方法实现
// =========================================================================

%hook UIViewController

static void Tweak_presentViewController(UIViewController *self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    if (g_isExtractingTianDiPanDetail) {
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
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
            return;
        }
    }
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

- (void)viewDidLoad { %orig; Class targetClass = NSClassFromString(@"六壬大占.ViewController"); if (targetClass && [self isKindOfClass:targetClass]) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem]; testButton.frame = CGRectMake(self.view.bounds.size.width - 120, self.view.bounds.size.height - 60, 100, 44); [testButton setTitle:@"天地盘测试" forState:UIControlStateNormal]; testButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.6 blue:0.0 alpha:1.0]; [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; testButton.layer.cornerRadius = 8; testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16]; [testButton addTarget:self action:@selector(handleTianDiPanTestButtonTap) forControlEvents:UIControlEventTouchUpInside]; [self.view addSubview:testButton]; NSLog(@"[EchoTest] 测试按钮已添加。"); }); } }

%new - (void)handleTianDiPanTestButtonTap { [self startExtraction_TianDiPanDetails]; }

%new
- (void)startExtraction_TianDiPanDetails {
    if (g_isExtractingTianDiPanDetail) { NSLog(@"[EchoTest] 提取任务正在进行中。"); return; }
    NSLog(@"[EchoTest] 任务启动...");
    
    g_isExtractingTianDiPanDetail = YES;
    g_tianDiPanButtonQueue = [NSMutableArray array]; g_tianDiPanTitleQueue = [NSMutableArray array]; g_tianDiPanResults = [NSMutableDictionary dictionary];

    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    NSMutableArray *plateViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);
    if (plateViews.count == 0) { /* 错误处理 */ g_isExtractingTianDiPanDetail = NO; return; }
    UIView *plateView = plateViews.firstObject;

    UITapGestureRecognizer *realTapGesture = nil;
    for (UIGestureRecognizer *gesture in plateView.gestureRecognizers) {
        if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) { realTapGesture = (UITapGestureRecognizer *)gesture; break; }
    }
    if (!realTapGesture) { /* 错误处理 */ g_isExtractingTianDiPanDetail = NO; return; }
    
    // 【新】从真实手势中“偷”出目标和方法
    id target = nil; SEL action = NULL;
    id targetWrapper = [realTapGesture valueForKey:@"_targets"];
    if ([targetWrapper count] > 0) {
        id firstTarget = targetWrapper[0];
        target = [firstTarget valueForKey:@"_target"];
        action = NSSelectorFromString(NSStringFromSelector((SEL)[firstTarget valueForKey:@"_action"]));
    }
    if (!target || !action) { NSLog(@"[EchoTest] 错误: 无法从真实手势中获取target或action。"); g_isExtractingTianDiPanDetail = NO; return; }

    // 【新】禁用原始手势，避免冲突
    realTapGesture.enabled = NO;

    // 【新】创建覆盖层
    g_overlayContainerView = [[UIView alloc] initWithFrame:plateView.bounds];
    g_overlayContainerView.backgroundColor = [UIColor clearColor];
    [plateView addSubview:g_overlayContainerView];

    id diGongDict = GetIvarValueSafely(plateView, @"地宮宮名列"); id tianShenDict = GetIvarValueSafely(plateView, @"天神宮名列"); id tianJiangDict = GetIvarValueSafely(plateView, @"天將宮名列");

    void (^createButtonsForLayers)(NSDictionary *, NSString *) = ^(NSDictionary *layerDict, NSString *type) {
        for (NSString *key in layerDict) {
            CALayer *layer = layerDict[key];
            if (layer && [layer isKindOfClass:[CALayer class]]) {
                UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
                button.frame = layer.frame; // 使用 CALayer 的 frame
                // 关键：将“偷”来的目标和方法绑定到我们的新按钮上
                [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
                
                [g_overlayContainerView addSubview:button];
                [g_tianDiPanButtonQueue addObject:button];
                [g_tianDiPanTitleQueue addObject:[NSString stringWithFormat:@"%@ - %@", type, key]];
            }
        }
    };

    createButtonsForLayers(diGongDict, @"地盘"); createButtonsForLayers(tianShenDict, @"天盘"); createButtonsForLayers(tianJiangDict, @"天将");

    if (g_tianDiPanButtonQueue.count == 0) { /* 错误处理 */ g_isExtractingTianDiPanDetail = NO; realTapGesture.enabled = YES; [g_overlayContainerView removeFromSuperview]; g_overlayContainerView = nil; return; }
    
    NSLog(@"[EchoTest] 任务队列构建完成，总计 %lu 个覆盖按钮。", (unsigned long)g_tianDiPanButtonQueue.count);
    [self processTianDiPanDetailsQueue];
}

%new
- (void)processTianDiPanDetailsQueue {
    if (g_tianDiPanButtonQueue.count == 0) {
        NSLog(@"[EchoTest] ======== 天地盘详情提取完成 ========");
        NSArray *sortedKeys = [g_tianDiPanResults.allKeys sortedArrayUsingSelector:@selector(localizedCompare:)];
        for (NSString *key in sortedKeys) { NSLog(@"\n--- %@ ---\n%@", key, g_tianDiPanResults[key]); }
        NSLog(@"[EchoTest] =======================================");

        // 【新】清理工作：恢复原始手势，移除覆盖层
        UITapGestureRecognizer *realTapGesture = nil;
        if (g_overlayContainerView.superview) {
            for (UIGestureRecognizer *gesture in g_overlayContainerView.superview.gestureRecognizers) { if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) { realTapGesture = (UITapGestureRecognizer *)gesture; break; } }
            if (realTapGesture) realTapGesture.enabled = YES;
            [g_overlayContainerView removeFromSuperview];
        }

        g_isExtractingTianDiPanDetail = NO;
        g_tianDiPanButtonQueue = nil; g_tianDiPanTitleQueue = nil; g_tianDiPanResults = nil; g_overlayContainerView = nil;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试完成" message:[NSString stringWithFormat:@"已成功提取 %lu 条详情，请检查日志。", (unsigned long)sortedKeys.count] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIButton *targetButton = g_tianDiPanButtonQueue.firstObject;
    [g_tianDiPanButtonQueue removeObjectAtIndex:0];
    
    // 【新】最安全的方式：模拟真实的按钮点击事件
    [targetButton sendActionsForControlEvents:UIControlEventTouchUpInside];
}

%end

%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[EchoTest] 天地盘详情提取测试脚本已加载 (v1.7 绝对安全版)。");
    }
}
