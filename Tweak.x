#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 伪造手势类
// =========================================================================
@interface EchoFakeGestureRecognizer : UIGestureRecognizer
@property (nonatomic, assign) CGPoint fakeLocation;
@end

@implementation EchoFakeGestureRecognizer
- (CGPoint)locationInView:(UIView *)view {
    return self.fakeLocation;
}
@end

// =========================================================================
// 2. 全局变量、UI与辅助函数
// =========================================================================
static UIView *g_extractorView = nil;
static UITextView *g_logTextView = nil;

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static BOOL g_isExtractingDetails = NO;
static void (^g_detailCompletionHandler)(NSString *result);

// 辅助函数...
static id GetIvarValueSafely(id, NSString *);
static void LogToScreen(NSString *, ...);
static NSString* extractTextFromPopup(UIView *);

// =========================================================================
// 3. 核心Hook与提取逻辑
// =========================================================================

static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    if (g_isExtractingDetails) {
        if ([vcToPresent isKindOfClass:[UINavigationController class]]) {
            animated = NO;
            void (^extractionCompletion)(void) = ^{
                if (completion) completion();
                NSString *extractedText = extractTextFromPopup(vcToPresent.view);
                if (g_detailCompletionHandler) g_detailCompletionHandler(extractedText);
                [vcToPresent dismissViewControllerAnimated:NO completion:nil];
            };
            Original_presentViewController(self, _cmd, vcToPresent, animated, extractionCompletion);
            return;
        }
    }
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

@interface UIViewController (EchoExtractor)
- (void)startFullExtraction;
@end

// 【【【 最终结构修正 】】】
%hook 六壬大占.ViewController

- (void)viewDidLoad {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([self.view.window viewWithTag:777888]) return;
        UIButton *extractorButton = [UIButton buttonWithType:UIButtonTypeSystem];
        extractorButton.frame = CGRectMake(self.view.bounds.size.width - 150, 45, 140, 36);
        extractorButton.tag = 777888;
        [extractorButton setTitle:@"提取天地盘详情" forState:UIControlStateNormal];
        extractorButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.35 alpha:1.0];
        [extractorButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        extractorButton.layer.cornerRadius = 18;
        [extractorButton addTarget:self action:@selector(startFullExtraction) forControlEvents:UIControlEventTouchUpInside];
        [self.view.window addSubview:extractorButton];
    });
}

%new
- (void)startFullExtraction {
    if (g_extractorView) {
        [g_extractorView removeFromSuperview];
        g_extractorView = nil; g_logTextView = nil;
        return;
    }
    
    g_extractorView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, self.view.bounds.size.width - 20, 500)];
    g_extractorView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    g_extractorView.layer.cornerRadius = 15;
    g_extractorView.layer.borderColor = [UIColor greenColor].CGColor;
    g_extractorView.layer.borderWidth = 1.0;
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectInset(g_extractorView.bounds, 10, 10)];
    g_logTextView.backgroundColor = [UIColor clearColor]; g_logTextView.textColor = [UIColor whiteColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:11]; g_logTextView.editable = NO; g_logTextView.text = @"";
    [g_extractorView addSubview:g_logTextView];
    [self.view.window addSubview:g_extractorView];

    LogToScreen(@"[INFO] 开始提取天地盘所有宫位详情...");

    UIViewController *vc = self;
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    __block UIView *plateView = nil;
    
    // 使用弱引用 self 防止 block 循环引用
    __weak typeof(self) weakSelf = self;
    void (^__block findViewRecursive)(UIView *) = ^(UIView *view) {
        if (plateView) return; 
        if ([view isKindOfClass:plateViewClass]) { plateView = view; return; }
        for (UIView *subview in view.subviews) {
             findViewRecursive(subview);
        }
    };
    findViewRecursive(self.view.window);
    
    if (!plateView) {
        LogToScreen(@"[CRITICAL] 找不到天地盘视图实例。");
        return;
    }
    LogToScreen(@"[SUCCESS] 成功定位到天地盘视图实例: <%p>", plateView);

    id tianShenObject = GetIvarValueSafely(plateView, @"天神宮名列");
    id tianJiangObject = GetIvarValueSafely(plateView, @"天將宮名列");

    if (!tianShenObject || ![tianShenObject isKindOfClass:[NSDictionary class]] || !tianJiangObject || ![tianJiangObject isKindOfClass:[NSDictionary class]]) {
        LogToScreen(@"[CRITICAL] 无法获取天神/天将宫名列。");
        return;
    }
    NSDictionary *tianShenDict = (NSDictionary *)tianShenObject;
    NSDictionary *tianJiangDict = (NSDictionary *)tianJiangObject;
    LogToScreen(@"[INFO] 成功获取天神/天将宫名列。");
    
    NSMutableArray *tasks = [NSMutableArray array];
    NSArray *sortedKeys = [tianShenDict.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (id key in sortedKeys) {
        CALayer *shenLayer = tianShenDict[key];
        CALayer *jiangLayer = tianJiangDict[key];
        
        if (!shenLayer || !jiangLayer) continue;

        CGPoint layerPosition = [jiangLayer.superlayer convertPoint:jiangLayer.position toLayer:plateView.layer];
        
        id shenString = [shenLayer valueForKey:@"string"];
        id jiangString = [jiangLayer valueForKey:@"string"];

        NSString *shenText = [shenString isKindOfClass:[NSAttributedString class]] ? ((NSAttributedString*)shenString).string : shenString;
        NSString *jiangText = [jiangString isKindOfClass:[NSAttributedString class]] ? ((NSAttributedString*)jiangString).string : jiangString;

        NSString *fullName = [NSString stringWithFormat:@"%@(%@)", shenText ?: @"?", jiangText ?: @"?"];
        [tasks addObject:@{@"name": fullName, @"position": [NSValue valueWithCGPoint:layerPosition]}];
    }
    
    SEL clickSelector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
    if (![vc respondsToSelector:clickSelector]) {
        LogToScreen(@"[CRITICAL] ViewController 上找不到方法 '顯示天地盤觸摸WithSender:'");
        return;
    }
    
    __block void (^processNextTask)();
    __block NSInteger currentTaskIndex = 0;
    
    processNextTask = [^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || currentTaskIndex >= tasks.count) {
            LogToScreen(@"\n--- [COMPLETE] 所有12个宫位详情提取完毕 ---");
            processNextTask = nil;
            return;
        }
        
        NSDictionary *task = tasks[currentTaskIndex];
        NSString *palaceName = task[@"name"];
        CGPoint position = [task[@"position"] CGPointValue];
        
        LogToScreen(@"\n--- [TASK %ld/12] 正在模拟点击: %@ ---", (long)currentTaskIndex + 1, palaceName);
        
        EchoFakeGestureRecognizer *fakeGesture = [[EchoFakeGestureRecognizer alloc] init];
        fakeGesture.fakeLocation = position;
        
        g_isExtractingDetails = YES;
        g_detailCompletionHandler = ^(NSString *result) {
            LogToScreen(@"[RESULT] 提取到 %@ 的详情:\n---\n%@\n---", palaceName, result);
            
            g_isExtractingDetails = NO;
            g_detailCompletionHandler = nil;
            currentTaskIndex++;
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if(processNextTask) processNextTask();
            });
        };
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [strongSelf performSelector:clickSelector withObject:fakeGesture];
        #pragma clang diagnostic pop
    } copy];
    
    processNextTask();
}

%end // %hook 六壬大占.ViewController

%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[EchoTianDiPanExtractor] Final Production Version Loaded.");
    }
}

// =========================================================================
// 辅助函数实现
// =========================================================================
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
            NSString *ivarNameStr = [NSString stringWithUTF8String:name];
            if ([ivarNameStr hasSuffix:ivarNameSuffix]) {
                value = object_getIvar(object, ivar);
                break;
            }
        }
    }
    free(ivars);
    return value;
}

static NSString* extractTextFromPopup(UIView *popupView) {
    NSMutableArray *allLabels = [NSMutableArray array];
    
    void (^__block __weak weak_findLabelsRecursive)(UIView *);
    void (^findLabelsRecursive)(UIView *);
    weak_findLabelsRecursive = findLabelsRecursive = ^(UIView *view) {
        if ([view isKindOfClass:[UILabel class]]) {
            [allLabels addObject:view];
        }
        for (UIView *subview in view.subviews) {
            weak_findLabelsRecursive(subview);
        }
    };
    findLabelsRecursive(popupView);

    [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
        return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)];
    }];

    NSMut
