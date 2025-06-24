#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog(@"[KeChuan-Test-Gesture] " format, ##__VA_ARGS__)

static NSInteger const TestButtonTag = 556693; // 保持Tag不变
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_keChuanWorkQueue = nil;
static NSMutableArray *g_keChuanTitleQueue = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Gesture)
- (void)performKeChuanDetailExtractionTest_Gesture;
- (void)processKeChuanQueue_Gesture;
@end

%hook UIViewController

// --- viewDidLoad 和 presentViewController 保持不变 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            if ([keyWindow viewWithTag:TestButtonTag]) { [[keyWindow viewWithTag:TestButtonTag] removeFromSuperview]; }
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"测试课传(手势版)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemIndigoColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Gesture) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            viewControllerToPresent.view.alpha = 0.0f;
            flag = NO;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) {
                        [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            });
            %orig(viewControllerToPresent, flag, completion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performKeChuanDetailExtractionTest_Gesture {
    EchoLog(@"开始执行 [课传详情] 手势版测试");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];

    Class chuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (chuanViewClass) {
        NSMutableArray *allChuanViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(chuanViewClass, self.view, allChuanViews);
        [allChuanViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
            return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)];
        }];
        
        NSArray *rowTitles = @[@"初传", @"中传", @"末传"];
        for (NSUInteger i = 0; i < allChuanViews.count; i++) {
            if (i >= rowTitles.count) break;
            UIView *chuanView = allChuanViews[i];
            for (UIGestureRecognizer *recognizer in chuanView.gestureRecognizers) {
                if ([recognizer isKindOfClass:NSClassFromString(@"UITapGestureRecognizer")]) {
                    [g_keChuanWorkQueue addObject:@{@"recognizer": recognizer}];
                    [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ 的 Tap 手势", rowTitles[i]]];
                }
            }
        }
    }
    
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *skViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, skViews);
        if (skViews.count > 0) {
            UIView *siKeContainer = skViews.firstObject;
            for (UIGestureRecognizer *recognizer in siKeContainer.gestureRecognizers) {
                if ([recognizer isKindOfClass:NSClassFromString(@"UITapGestureRecognizer")]) {
                    [g_keChuanWorkQueue addObject:@{@"recognizer": recognizer}];
                    [g_keChuanTitleQueue addObject:@"四课视图的 Tap 手势"];
                }
            }
        }
    }

    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"测试失败: 未找到任何带有Tap手势的课传视图。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    [self processKeChuanQueue_Gesture];
}

%new
- (void)processKeChuanQueue_Gesture {
    if (g_keChuanWorkQueue.count == 0) {
        // ... 结束逻辑不变 ...
        EchoLog(@"[课传详情] 手势版测试处理完毕");
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"手势版测试完成" message:@"所有详情已提取并复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
        g_isExtractingKeChuanDetail = NO;
        g_keChuanWorkQueue = nil;
        g_capturedKeChuanDetailArray = nil;
        g_keChuanTitleQueue = nil;
        return;
    }
    
    NSDictionary *task = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    UIGestureRecognizer *recognizer = task[@"recognizer"];
    // 【修正】删除了未使用的 targetView 变量
    
    id targets = [recognizer valueForKey:@"targets"];
    if ([targets count] > 0) {
        id targetContainer = targets[0];
        id target = [targetContainer valueForKey:@"target"];
        
        // 【修正】使用 NSSelectorFromString 来安全地处理 SEL
        NSString *actionString = NSStringFromSelector((SEL)[[targetContainer valueForKey:@"action"] pointerValue]);
        SEL action = NSSelectorFromString(actionString);

        if (target && action && [target respondsToSelector:action]) {
            EchoLog(@"尝试触发手势: %@ on %@", NSStringFromSelector(action), target);
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [target performSelector:action withObject:recognizer];
            #pragma clang diagnostic pop
        } else {
             EchoLog(@"警告: 从手势识别器中未能获取到有效的 target 或 action。");
        }
    } else {
        EchoLog(@"警告: 手势识别器没有 target。");
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self processKeChuanQueue_Gesture];
    });
}
%end
