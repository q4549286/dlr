#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_keChuanWorkQueue = nil;
static NSMutableArray *g_keChuanTitleQueue = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view) return;
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (TheFinalTweak)
- (void)performKeChuanDetailExtraction_TheFinalTweak;
- (void)processKeChuanQueue_TheFinalTweak;
@end

%hook UIViewController

// --- viewDidLoad: 创建按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) { return; }
            NSInteger TestButtonTag = 556706; // The Final Tag
            UIView *existingButton = [keyWindow viewWithTag:TestButtonTag];
            if (existingButton) { [existingButton removeFromSuperview]; }
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"课传提取" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemGreenColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtraction_TheFinalTweak) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// --- presentViewController: 捕获弹窗并驱动队列 ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            viewControllerToPresent.view.alpha = 0.0f;
            flag = NO;
            
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if (roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if (roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
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
                
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processKeChuanQueue_TheFinalTweak];
                    });
                }];
            };
            
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
// --- performKeChuanDetailExtraction_TheFinalTweak: 构建任务队列 ---
- (void)performKeChuanDetailExtraction_TheFinalTweak {
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
    
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanContainerClass) {
        NSMutableArray *containers = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, containers);
        if (containers.count > 0) {
            UIView *sanChuanContainer = containers.firstObject;
            const char *ivarNames[] = {"初傳", "中傳", "末傳"};
            NSString *rowTitles[] = {@"初传", @"中传", @"末传"};
            
            for (int i = 0; i < 3; ++i) {
                Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, ivarNames[i]);
                if (ivar) {
                    UIView *chuanView = object_getIvar(sanChuanContainer, ivar);
                    if (chuanView) {
                        NSMutableArray *labels = [NSMutableArray array];
                        FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
                        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){
                            return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                        }];
                        
                        if (labels.count >= 2) {
                            UILabel *dizhiLabel = labels[labels.count - 2];
                            UILabel *tianjiangLabel = labels[labels.count - 1];
                            
                            [g_keChuanWorkQueue addObject:dizhiLabel];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                            
                            [g_keChuanWorkQueue addObject:tianjiangLabel];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
                        }
                    }
                }
            }
        }
    }
    
    if (g_keChuanWorkQueue.count == 0) {
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    [self processKeChuanQueue_TheFinalTweak];
}

%new
// --- processKeChuanQueue_TheFinalTweak: 动态触发手势 ---
- (void)processKeChuanQueue_TheFinalTweak {
    if (g_keChuanWorkQueue.count == 0) {
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"所有详情已复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
        
        g_isExtractingKeChuanDetail = NO;
        g_keChuanWorkQueue = nil;
        g_capturedKeChuanDetailArray = nil;
        g_keChuanTitleQueue = nil;
        return;
    }
    
    UILabel *targetLabel = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    for (UIGestureRecognizer *gesture in targetLabel.gestureRecognizers) {
        if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
            Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
            if (targetsIvar) {
                id targetActionPairs = object_getIvar(gesture, targetsIvar);
                if ([targetActionPairs count] > 0) {
                    id firstTargetActionPair = [targetActionPairs objectAtIndex:0];
                    id target = [firstTargetActionPair performSelector:@selector(target)];
                    
                    // 【【【 THE ONLY FIX THAT MATTERS 】】】
                    // Safely get the SEL from the NSValue wrapper.
                    id actionValue = [firstTargetActionPair performSelector:@selector(action)];
                    SEL action = [actionValue pointerValue];

                    if (target && action && [target respondsToSelector:action]) {
                        #pragma clang diagnostic push
                        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                        [target performSelector:action withObject:gesture];
                        #pragma clang diagnostic pop
                        return;
                    }
                }
            }
        }
    }

    // Failsafe: continue queue if gesture not found/triggered.
    [self processKeChuanQueue_TheFinalTweak];
}
%end
