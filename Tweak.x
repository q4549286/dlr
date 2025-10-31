#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量与常量
// =========================================================================
static const NSInteger kEchoExtractorPanelTag = 789012;
static const NSInteger kEchoExtractorButtonTag = 345678;

static UIView *g_extractorPanelView = nil;
static UITextView *g_logTextView = nil;

// 存储提取结果
static NSMutableArray<NSString *> *g_rawResults = nil;
static BOOL g_isExtracting = NO;

// 声明我们将要用到的App内部方法
@interface UIView (EchoExtractor)
- (void)處理點擊WithSender:(id)sender;
@end

// =========================================================================
// 2. UI创建与管理 (简化版)
// =========================================================================
@interface UIViewController (EchoExtractor)
- (void)createOrShowExtractorPanel;
- (void)handleExtractorButtonTap:(UIButton *)sender;
- (void)startRawExtraction;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            if (!keyWindow || [keyWindow viewWithTag:kEchoExtractorButtonTag]) return;

            UIButton *extractorButton = [UIButton buttonWithType:UIButtonTypeSystem];
            extractorButton.frame = CGRectMake(10, 45, 140, 36);
            extractorButton.tag = kEchoExtractorButtonTag;
            [extractorButton setTitle:@"原始数据提取" forState:UIControlStateNormal];
            extractorButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.8 alpha:1.0];
            [extractorButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            extractorButton.layer.cornerRadius = 18;
            [extractorButton addTarget:self action:@selector(createOrShowExtractorPanel) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:extractorButton];
        });
    }
}

%new
- (void)createOrShowExtractorPanel {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) return;

    if (g_extractorPanelView) {
        [UIView animateWithDuration:0.3 animations:^{ g_extractorPanelView.alpha = 0; } completion:^(BOOL finished) {
            [g_extractorPanelView removeFromSuperview];
            g_extractorPanelView = nil;
            g_logTextView = nil;
        }];
        return;
    }

    g_extractorPanelView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    g_extractorPanelView.tag = kEchoExtractorPanelTag;
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blurView.frame = g_extractorPanelView.bounds;
    [g_extractorPanelView addSubview:blurView];

    UIView *contentView = blurView.contentView;
    CGFloat panelWidth = contentView.bounds.size.width;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 50, panelWidth, 30)];
    titleLabel.text = @"天地盘原始数据提取器";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:titleLabel];

    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    startButton.frame = CGRectMake(panelWidth/2 - 100, 100, 200, 44);
    [startButton setTitle:@"开始提取12宫详情" forState:UIControlStateNormal];
    startButton.tag = 201;
    [startButton addTarget:self action:@selector(handleExtractorButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:startButton];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(panelWidth/2 - 100, 150, 200, 44);
    [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    closeButton.tag = 202;
    [closeButton addTarget:self action:@selector(handleExtractorButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:closeButton];

    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 210, panelWidth - 20, contentView.bounds.size.height - 220)];
    g_logTextView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.8];
    g_logTextView.layer.cornerRadius = 10;
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO;
    g_logTextView.textColor = [UIColor whiteColor];
    g_logTextView.text = @"点击“开始提取”以启动流程。\n";
    [contentView addSubview:g_logTextView];

    g_extractorPanelView.alpha = 0;
    [keyWindow addSubview:g_extractorPanelView];
    [UIView animateWithDuration:0.3 animations:^{ g_extractorPanelView.alpha = 1.0; }];
}

%new
- (void)handleExtractorButtonTap:(UIButton *)sender {
    switch(sender.tag) {
        case 201: // Start
            [self startRawExtraction];
            break;
        case 202: // Close
            [self createOrShowExtractorPanel];
            break;
    }
}

%new
- (void)startRawExtraction {
    if (g_isExtracting) {
        g_logTextView.text = [g_logTextView.text stringByAppendingString:@"[错误] 提取任务已在进行中。\n"];
        return;
    }
    
    g_isExtracting = YES;
    g_rawResults = [NSMutableArray array];
    g_logTextView.text = @"[任务启动] 开始提取天地盘12宫原始详情...\n";

    // 1. 定位天地盘视图
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    if (!plateViewClass) {
        g_logTextView.text = [g_logTextView.text stringByAppendingString:@"[错误] 找不到类 `六壬大占.天地盤視圖類`\n"];
        g_isExtracting = NO;
        return;
    }
    
    NSMutableArray *plateViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);
    if (plateViews.count == 0) {
        g_logTextView.text = [g_logTextView.text stringByAppendingString:@"[错误] 找不到天地盘视图实例。\n"];
        g_isExtracting = NO;
        return;
    }
    UIView *plateView = plateViews.firstObject;

    // 2. 计算12个宫位的中心点坐标
    // (复用原脚本的几何分析逻辑，但只为获取坐标)
    Ivar diGongIvar = class_getInstanceVariable(plateViewClass, "_$_lazy_storage_$_地宮宮名列");
    if (!diGar) { // typo fix
        g_logTextView.text = [g_logTextView.text stringByAppendingString:@"[错误] 找不到地宫宫名列表的实例变量。\n"];
        g_isExtracting = NO;
        return;
    }
    NSDictionary *diGongDict = object_getIvar(plateView, diGongIvar);
    if (!diGongDict) {
        g_logTextView.text = [g_logTextView.text stringByAppendingString:@"[错误] 地宫宫名列表为空。\n"];
        g_isExtracting = NO;
        return;
    }
    
    NSArray<CALayer *> *diGongLayers = [diGongDict allValues];
    NSMutableArray<NSValue *> *centerPoints = [NSMutableArray array];
    for (CALayer *layer in diGongLayers) {
        // 将 CALayer 的中心点转换到 plateView 的坐标系
        CGPoint centerInPlateView = layer.position;
        [centerPoints addObject:[NSValue valueWithCGPoint:centerInPlateView]];
    }

    g_logTextView.text = [g_logTextView.text stringByAppendingFormat:@"[信息] 成功计算出 %lu 个宫位的点击坐标。\n", (unsigned long)centerPoints.count];
    
    // 3. 循环模拟点击
    __block int currentIndex = 0;
    __block void (^processNextPoint)();

    SEL actionSelector = NSSelectorFromString(@"處理點擊WithSender:");
    if (![plateView respondsToSelector:actionSelector]) {
        g_logTextView.text = [g_logTextView.text stringByAppendingString:@"[致命错误] 天地盘视图不响应 `處理點擊WithSender:` 方法！\n"];
        g_isExtracting = NO;
        return;
    }

    processNextPoint = [^{
        if (currentIndex >= centerPoints.count) {
            // 所有点击都已完成
            g_logTextView.text = [g_logTextView.text stringByAppendingString:@"\n[任务完成] 所有12宫详情已提取完毕！\n\n--- 原始数据 ---\n\n"];
            
            NSMutableString *finalReport = [NSMutableString string];
            for (NSString *result in g_rawResults) {
                [finalReport appendString:result];
                [finalReport appendString:@"\n--------------------------------\n"];
            }
            g_logTextView.text = [g_logTextView.text stringByAppendingString:finalReport];
            
            // 复制到剪贴板
            [UIPasteboard generalPasteboard].string = finalReport;
            g_logTextView.text = [g_logTextView.text stringByAppendingString:@"\n[成功] 原始数据已复制到剪贴板！\n"];

            g_isExtracting = NO;
            processNextPoint = nil;
            return;
        }

        CGPoint pointToClick = [centerPoints[currentIndex] CGPointValue];

        // **【核心模拟】**
        // 创建一个假的 UITapGestureRecognizer
        UITapGestureRecognizer *mockGesture = [[UITapGestureRecognizer alloc] init];
        
        // **【关键】** 使用KVC强制设置私有变量来伪造点击位置
        // 我们需要找到存储 `location` 的私有 ivar。通过 Hopper 或 FLEX 观察，
        // `UITapGestureRecognizer` 内部有一个 `_locationInView` 变量。
        // 我们需要 swizzle `locationInView:` 方法来返回我们想要的值。
        
        // 更简单的方法是直接调用 `處理點擊WithSender:`
        // 并在内部 hook `locationInView:`
        // (为了简化这个独立脚本，我们先直接调用，看 App 是否会崩溃或行为异常)
        // 很多时候，App的开发者可能没有严格检查sender，而是直接从其他地方获取位置。

        g_logTextView.text = [g_logTextView.text stringByAppendingFormat:@"[模拟点击 %d/12] 坐标: (%.1f, %.1f)...\n", currentIndex + 1, pointToClick.x, pointToClick.y];
        
        // **风险尝试**：直接传递一个空的 gesture。如果App崩溃，我们需要更复杂的伪造。
        // [plateView 處理點擊WithSender:mockGesture];
        // **更正**：传递一个真实的gesture，但它的location是空的。
        [plateView 處理點擊WithSender:plateView.gestureRecognizers.firstObject];


        currentIndex++;
        // 等待弹窗处理
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), processNextPoint);
        
    } copy];

    processNextPoint();
}
%end

// =========================================================================
// 3. 核心拦截与数据捕获
// =========================================================================
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    
    // 只在提取任务进行时拦截
    if (g_isExtracting) {
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
        
        // 我们需要知道详情弹窗的类名，这里先用一个通用的名字，你需要用监控脚本确认
        if ([vcClassName containsString:@"摘要視圖"] || [vcClassName containsString:@"DetailViewController"]) {
            
            // 立即提取，然后阻止弹窗
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSMutableString *rawContent = [NSMutableString string];
                
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], vcToPresent.view, allLabels);
                
                // 按Y坐标排序，模拟视觉顺序
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2){
                    return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)];
                }];

                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) {
                        [rawContent appendFormat:@"%@\n", label.text];
                    }
                }
                
                [g_rawResults addObject:rawContent];
                g_logTextView.text = [g_logTextView.text stringByAppendingString:@"  -> 成功捕获并提取原始数据。\n"];
            });

            // 不调用 original 方法，直接返回，这样弹窗就不会出现
            return;
        }
    }

    // 如果不是我们的目标，就正常显示弹窗
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

// 辅助函数
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if (!view || !storage) return; if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }

// =========================================================================
// 4. 初始化
// =========================================================================
%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[EchoRawExtractor] 原始数据提取脚本已加载。");
    }
}
