#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局状态管理
// =========================================================================
static BOOL g_isExtractingTianDiPanDetail = NO;
static NSMutableArray<UIGestureRecognizer *> *g_tianDiPanGestureQueue = nil; // 【新】队列存储我们创建的、状态完整的手势
static NSMutableArray<NSString *> *g_tianDiPanTitleQueue = nil;
static NSMutableDictionary<NSString *, NSString *> *g_tianDiPanResults = nil;
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static UIView *g_test_plateView = nil; // 存储天地盘视图实例
static id g_real_gesture_target = nil; // 存储真实的目标
static SEL g_real_gesture_action = NULL; // 存储真实的方法

// =========================================================================
// 2. 核心辅助类与函数
// =========================================================================
@interface EchoFakeTapGestureRecognizer : UITapGestureRecognizer
@property (nonatomic, weak) UIView *targetView;
@property (nonatomic, assign) CGPoint mockedLocationInTargetView;
@end

@implementation EchoFakeTapGestureRecognizer
- (CGPoint)locationInView:(UIView *)view {
    if (view == self.targetView) { return self.mockedLocationInTargetView; }
    return [super locationInView:view];
}
@end

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if (!view || !storage) return; if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) { if (!object || !ivarNameSuffix) return nil; unsigned int ivarCount; Ivar *ivars = class_copyIvarList([object class], &ivarCount); if (!ivars) { free(ivars); return nil; } id value = nil; for (unsigned int i = 0; i < ivarCount; i++) { Ivar ivar = ivars[i]; const char *name = ivar_getName(ivar); if (name) { NSString *ivarName = [NSString stringWithUTF8String:name]; if ([ivarName hasSuffix:ivarNameSuffix]) { value = object_getIvar(object, ivar); break; } } } free(ivars); return value; }
static NSString* extractTextFromGenericPopupView(UIView *popupView) { NSMutableArray<UILabel *> *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], popupView, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) { return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)]; }]; NSMutableString *result = [NSMutableString string]; for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [result appendFormat:@"%@\n", [label.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]; } } return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; }

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
    g_tianDiPanGestureQueue = [NSMutableArray array]; g_tianDiPanTitleQueue = [NSMutableArray array]; g_tianDiPanResults = [NSMutableDictionary dictionary];

    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    NSMutableArray *plateViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);
    if (plateViews.count == 0) { /* 错误处理 */ g_isExtractingTianDiPanDetail = NO; return; }
    g_test_plateView = plateViews.firstObject;

    UITapGestureRecognizer *realTapGesture = nil;
    for (UIGestureRecognizer *gesture in g_test_plateView.gestureRecognizers) {
        if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) { realTapGesture = (UITapGestureRecognizer *)gesture; break; }
    }
    if (!realTapGesture) { /* 错误处理 */ g_isExtractingTianDiPanDetail = NO; return; }
    
    id targets = [realTapGesture valueForKey:@"_targets"];
    if ([targets isKindOfClass:[NSArray class]] && [targets count] > 0) {
        id targetProxy = [targets firstObject];
        g_real_gesture_target = [targetProxy valueForKey:@"_target"]; 
        NSValue *actionValue = [targetProxy valueForKey:@"_action"];
        if (actionValue) { g_real_gesture_action = [actionValue pointerValue]; }
    }
    if (!g_real_gesture_target || !g_real_gesture_action) { NSLog(@"[EchoTest] 错误: 无法从真实手势中获取target或action。"); g_isExtractingTianDiPanDetail = NO; return; }

    realTapGesture.enabled = NO;

    id diGongDict = GetIvarValueSafely(g_test_plateView, @"地宮宮名列"); id tianShenDict = GetIvarValueSafely(g_test_plateView, @"天神宮名列"); id tianJiangDict = GetIvarValueSafely(g_test_plateView, @"天將宮名列");

    void (^createGesturesForLayers)(NSDictionary *, NSString *) = ^(NSDictionary *layerDict, NSString *type) {
        for (NSString *key in layerDict) {
            CALayer *layer = layerDict[key];
            if (layer && [layer isKindOfClass:[CALayer class]]) {
                // 为每个Layer创建一个“合法”的伪手势
                EchoFakeTapGestureRecognizer *fakeGesture = [[EchoFakeTapGestureRecognizer alloc] initWithTarget:g_real_gesture_target action:g_real_gesture_action];
                fakeGesture.targetView = g_test_plateView;
                fakeGesture.mockedLocationInTargetView = layer.position;
                [g_test_plateView addGestureRecognizer:fakeGesture]; // 添加到视图使其“激活”

                [g_tianDiPanGestureQueue addObject:fakeGesture];
                [g_tianDiPanTitleQueue addObject:[NSString stringWithFormat:@"%@ - %@", type, key]];
            }
        }
    };

    createGesturesForLayers(diGongDict, @"地盘"); createGesturesForLayers(tianShenDict, @"天盘"); createGesturesForLayers(tianJiangDict, @"天将");

    if (g_tianDiPanGestureQueue.count == 0) { /* 错误处理 */ g_isExtractingTianDiPanDetail = NO; realTapGesture.enabled = YES; return; }
    
    NSLog(@"[EchoTest] 任务队列构建完成，总计 %lu 个伪手势。", (unsigned long)g_tianDiPanGestureQueue.count);
    [self processTianDiPanDetailsQueue];
}

%new
- (void)processTianDiPanDetailsQueue {
    if (g_tianDiPanGestureQueue.count == 0) {
        NSLog(@"[EchoTest] ======== 天地盘详情提取完成 ========");
        NSArray *sortedKeys = [g_tianDiPanResults.allKeys sortedArrayUsingSelector:@selector(localizedCompare:)];
        for (NSString *key in sortedKeys) { NSLog(@"\n--- %@ ---\n%@", key, g_tianDiPanResults[key]); }
        NSLog(@"[EchoTest] =======================================");

        // 清理我们添加的所有手势
        for(UIGestureRecognizer *gesture in g_test_plateView.gestureRecognizers) {
            if ([gesture isKindOfClass:[EchoFakeTapGestureRecognizer class]]) {
                [g_test_plateView removeGestureRecognizer:gesture];
            }
        }
        // 恢复原始手势
        UITapGestureRecognizer *realTapGesture = nil;
        for (UIGestureRecognizer *gesture in g_test_plateView.gestureRecognizers) { if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) { realTapGesture = (UITapGestureRecognizer *)gesture; break; } }
        if (realTapGesture) realTapGesture.enabled = YES;
        
        g_isExtractingTianDiPanDetail = NO; /* ... 清理其他全局变量 ... */
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试完成" message:[NSString stringWithFormat:@"已成功提取 %lu 条详情。", (unsigned long)sortedKeys.count] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    UIGestureRecognizer *targetGesture = g_tianDiPanGestureQueue.firstObject;
    [g_tianDiPanGestureQueue removeObjectAtIndex:0];
    
    // ======================【终极闪退修复核心】======================
    //
    // 1. (关键) 使用KVC强制设置手势状态为 Ended，模拟一次完整的点击
    //
    [targetGesture setValue:@(UIGestureRecognizerStateEnded) forKey:@"state"];
    //
    // 2. 调用手势绑定的真实 Target 和 Action
    //
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [g_real_gesture_target performSelector:g_real_gesture_action withObject:targetGesture];
    #pragma clang diagnostic pop
    //
    // ===============================================================
}

%end

%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[EchoTest] 天地盘详情提取测试脚本已加载 (v1.9 状态模拟终极版)。");
    }
}
