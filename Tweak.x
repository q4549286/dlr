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

// =========================================================================
// 2. 核心辅助类与函数
// =========================================================================

// 【修复】创建一个继承自 UITapGestureRecognizer 的、更“逼真”的伪手势类，避免类型不匹配导致的闪退
@interface EchoFakeTapGestureRecognizer : UITapGestureRecognizer
@property (nonatomic, weak) UIView *targetView;
@property (nonatomic, assign) CGPoint mockedLocationInTargetView;
@end

@implementation EchoFakeTapGestureRecognizer
// 关键！重写这个方法，让App以为我们点击了指定的位置
- (CGPoint)locationInView:(UIView *)view {
    // 如果App查询的是在我们指定的目标视图中的位置，就返回我们伪造的坐标
    if (view == self.targetView) {
        return self.mockedLocationInTargetView;
    }
    // 否则，调用父类实现，以防万一
    return [super locationInView:view];
}
@end


// 界面遍历函数 (无需修改)
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if (!view || !storage) return; if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }

// 使用你主脚本中更强大的、通过后缀查找的 GetIvarValueSafely 版本
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) {
    if (!object || !ivarNameSuffix) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) { free(ivars); return nil; }
    id value = nil;
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name) {
            NSString *ivarName = [NSString stringWithUTF8String:name];
            if ([ivarName hasSuffix:ivarNameSuffix]) {
                value = object_getIvar(object, ivar);
                break;
            }
        }
    }
    free(ivars);
    return value;
}

// 提取弹窗文本的通用函数 (无需修改)
static NSString* extractTextFromGenericPopupView(UIView *popupView) {
    NSMutableArray<UILabel *> *allLabels = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], popupView, allLabels);
    [allLabels sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) { return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)]; }];
    NSMutableString *result = [NSMutableString string];
    for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [result appendFormat:@"%@\n", [label.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]; } }
    return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

// 为所有 %new 方法添加前向声明
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
        if ([vcClassName containsString:@"天地盤詳情視圖"]) { 
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

// 在主界面添加我们的测试按钮
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(self.view.bounds.size.width - 120, self.view.bounds.size.height - 60, 100, 44);
            [testButton setTitle:@"天地盘测试" forState:UIControlStateNormal];
            testButton.backgroundColor = [UIColor colorWithRed:1.0 green:0.6 blue:0.0 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            [testButton addTarget:self action:@selector(handleTianDiPanTestButtonTap) forControlEvents:UIControlEventTouchUpInside];
            
            [self.view addSubview:testButton];
            NSLog(@"[EchoTest] 测试按钮已添加到主视图。");
        });
    }
}

// 按钮点击事件
%new
- (void)handleTianDiPanTestButtonTap {
    NSLog(@"[EchoTest] 天地盘测试按钮被点击。");
    [self startExtraction_TianDiPanDetails];
}

// 启动提取流程
%new
- (void)startExtraction_TianDiPanDetails {
    if (g_isExtractingTianDiPanDetail) { NSLog(@"[EchoTest] 提取任务正在进行中，请稍候。"); return; }
    NSLog(@"[EchoTest] 任务启动：开始深度推衍“天地盘”...");
    
    g_isExtractingTianDiPanDetail = YES;
    g_tianDiPanWorkQueue = [NSMutableArray array];
    g_tianDiPanTitleQueue = [NSMutableArray array];
    g_tianDiPanResults = [NSMutableDictionary dictionary];

    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    if (!plateViewClass) { NSLog(@"[EchoTest] 错误: 找不到'天地盤視圖類'。"); g_isExtractingTianDiPanDetail = NO; return; }
    
    NSMutableArray *plateViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);
    if (plateViews.count == 0) { NSLog(@"[EchoTest] 错误: 找不到天地盘视图实例。"); g_isExtractingTianDiPanDetail = NO; return; }
    UIView *plateView = plateViews.firstObject;

    id diGongDict = GetIvarValueSafely(plateView, @"地宮宮名列");
    id tianShenDict = GetIvarValueSafely(plateView, @"天神宮名列");
    id tianJiangDict = GetIvarValueSafely(plateView, @"天將宮名列");

    if (!diGongDict || !tianShenDict || !tianJiangDict) { NSLog(@"[EchoTest] 错误: 无法获取一个或多个宫名列表。"); g_isExtractingTianDiPanDetail = NO; return; }

    void (^addLayersToQueue)(NSDictionary *, NSString *) = ^(NSDictionary *layerDict, NSString *type) {
        for (NSString *key in layerDict) {
            id layer = layerDict[key];
            if (layer && [layer isKindOfClass:[CALayer class]]) {
                [g_tianDiPanWorkQueue addObject:layer];
                [g_tianDiPanTitleQueue addObject:[NSString stringWithFormat:@"%@ - %@", type, key]];
            }
        }
    };

    addLayersToQueue(diGongDict, @"地盘");
    addLayersToQueue(tianShenDict, @"天盘");
    addLayersToQueue(tianJiangDict, @"天将");

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

        g_isExtractingTianDiPanDetail = NO;
        g_tianDiPanWorkQueue = nil;
        g_tianDiPanTitleQueue = nil;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试完成" message:[NSString stringWithFormat:@"已成功提取 %lu 条天地盘详情，请检查Xcode或Console日志。", (unsigned long)g_tianDiPanResults.count] preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        
        g_tianDiPanResults = nil;
        return;
    }

    CALayer *targetLayer = g_tianDiPanWorkQueue.firstObject;
    [g_tianDiPanWorkQueue removeObjectAtIndex:0];
    
    // 【修复】获取正确的坐标系视图
    UIView *plateView = targetLayer.delegate;
    if (!plateView || ![plateView isKindOfClass:NSClassFromString(@"六壬大占.天地盤視圖類")]) {
        NSLog(@"[EchoTest] 警告: 无法从CALayer获取到正确的plateView，将跳过此项。");
        [self processTianDiPanDetailsQueue];
        return;
    }
    
    CGPoint targetPosition = targetLayer.position;

    // 【修复】创建类型正确的伪手势
    EchoFakeTapGestureRecognizer *fakeGesture = [[EchoFakeTapGestureRecognizer alloc] init];
    fakeGesture.targetView = plateView; // 告诉伪手势坐标系
    fakeGesture.mockedLocationInTargetView = targetPosition; // 告诉伪手势点击位置

    SEL selector = NSSelectorFromString(@"顯示天地盤詳情WithSender:");
    if ([self respondsToSelector:selector]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:selector withObject:fakeGesture];
        #pragma clang diagnostic pop
    } else {
        NSLog(@"[EchoTest] 错误: 找不到目标方法 '顯示天地盤詳情WithSender:'");
        [self processTianDiPanDetailsQueue];
    }
}

%end


// =========================================================================
// 5. Tweak加载入口
// =========================================================================
%ctor {
    @autoreleasepool {
        MSHookMessageEx(
            NSClassFromString(@"UIViewController"),
            @selector(presentViewController:animated:completion:),
            (IMP)&Tweak_presentViewController,
            (IMP *)&Original_presentViewController
        );
        NSLog(@"[EchoTest] 天地盘详情提取测试脚本已加载 (v1.2 已修正闪退)。");
    }
}
