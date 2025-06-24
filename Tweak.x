#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 宏定义、全局变量与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[KeChuan-Test] " format), ##VA_ARGS)

// --- 全局状态变量 for this test ---
static NSInteger const TestButtonTag = 556678;
static BOOL g_isTestingKeChuan = NO;
static NSMutableArray *g_capturedTestDetails = nil;

// --- 辅助函数 (Copied from your main script for standalone functionality) ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

static id GetIvarValueSafely(id object, NSString *ivarName) {
    Ivar ivar = class_getInstanceVariable([object class], [ivarName cStringUsingEncoding:NSUTF8StringEncoding]);
    if (!ivar) {
        // Fallback for properties which generate ivars with a leading underscore
        ivar = class_getInstanceVariable([object class], [[NSString stringWithFormat:@"_%@", ivarName] cStringUsingEncoding:NSUTF8StringEncoding]);
    }
    if (ivar) {
        return object_getIvar(object, ivar);
    }
    return nil;
}

// =========================================================================
// 2. 主功能区：创建测试入口和核心逻辑
// =========================================================================
@interface UIViewController (EchoAITestAddons)
- (void)performKeChuanDetailExtractionTest;
@end

%hook UIViewController

// --- 2.1: 添加一个独立的测试按钮 ---
(void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            if ([keyWindow viewWithTag:TestButtonTag]) { [[keyWindow viewWithTag:TestButtonTag] removeFromSuperview]; }
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            // Position it below your existing button
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 40, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"测试课传详情" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.2 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// --- 2.2: 拦截弹窗，抓取信息 ---
(void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingKeChuan) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"]) {
            EchoLog(@"拦截到目标弹窗: %@", vcClassName);
            
            // Give the view a moment to render its contents
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];

                // Let's robustly grab all labels and sort them by position
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];

                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) {
                        [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedTestDetails addObject:fullDetail];
                EchoLog(@"提取到的内容:\n%@", fullDetail);

                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            });
            // We still call orig to let the presentation start, but we will dismiss it immediately.
            %orig(viewControllerToPresent, NO, completion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
// --- 2.3: 核心测试流程 ---
(void)performKeChuanDetailExtractionTest {
    EchoLog(@"--- 开始执行 [课传详情] 测试 ---");
    g_isTestingKeChuan = YES;
    g_capturedTestDetails = [NSMutableArray array];

    NSMutableArray *clickableItems = [NSMutableArray array];
    NSMutableArray *itemTitles = [NSMutableArray array];

    // --- Part A: Find all clickable items (San Chuan & Si Ke) ---
    // Find San Chuan items (傳視圖)
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanViewClass) {
        NSMutableArray *scViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews);
        [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        NSArray *titles = @[@"初传", @"中传", @"末传"];
        for (NSUInteger i = 0; i < scViews.count; i++) {
            [clickableItems addObject:scViews[i]];
            [itemTitles addObject:(i < titles.count) ? titles[i] : @"其他传"];
        }
        EchoLog(@"找到 %ld 个三传项目。", (unsigned long)scViews.count);
    }

    // Find Si Ke items (四課視圖)
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *skViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, skViews);
        if (skViews.count > 0) {
            UIView *siKeContainer = skViews.firstObject;
            // The logic from your script to find columns is excellent. Let's reuse it.
            // We will treat each column's top label as the clickable target.
            NSMutableArray *labels=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], siKeContainer, labels);
            NSMutableDictionary *cols = [NSMutableDictionary dictionary];
            for(UILabel *label in labels){
                NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))];
                if(!cols[key]){ cols[key]=[NSMutableArray array]; } [cols[key] addObject:label];
            }
            if (cols.allKeys.count == 4) {
                NSArray *keys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }];
                // The columns are extracted right-to-left in the UI (课一, 课二, ...), so we reverse the titles
                NSArray *titles = @[@"第四课", @"第三课", @"第二课", @"第一课"];
                for (NSUInteger i = 0; i < keys.count; i++) {
                    NSMutableArray *colLabels = cols[keys[i]];
                    [colLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                    if (colLabels.count > 0) {
                        // The whole column view might be the target, but clicking a label is often enough
                        [clickableItems addObject:colLabels.firstObject];
                        [itemTitles addObject:titles[i]];
                    }
                }
                EchoLog(@"找到 4 个四课项目。");
            }
        }
    }

    if (clickableItems.count == 0) {
        EchoLog(@"测试失败: 未找到任何可点击的课传项目。");
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"测试失败" message:@"未找到任何可点击的四课或三传项目。" preferredStyle:UIAlertControllerStyleAlert];
        [errorAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:errorAlert animated:YES completion:nil];
        g_isTestingKeChuan = NO;
        return;
    }
    
    __block void (^processQueue)(void);
    NSMutableArray *workQueue = [clickableItems mutableCopy];
    NSMutableArray *titleQueue = [itemTitles mutableCopy];

    // --- Part B: Process items one by one asynchronously ---
    processQueue = ^{
        if (workQueue.count == 0) {
            // --- Part C: All items processed, show results ---
            EchoLog(@"--- [课传详情] 测试处理完毕 ---");
            NSMutableString *resultStr = [NSMutableString string];
            for (NSUInteger i = 0; i < g_capturedTestDetails.count; i++) {
                NSString *title = (i < itemTitles.count) ? itemTitles[i] : @"未知项目";
                [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, g_capturedTestDetails[i]];
            }
            
            UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"测试完成" message:resultStr preferredStyle:UIAlertControllerStyleAlert];
            [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:successAlert animated:YES completion:nil];
            
            g_isTestingKeChuan = NO;
            processQueue = nil;
            return;
        }

        UIView *itemToClick = workQueue.firstObject;
        NSString *itemTitle = titleQueue.firstObject;
        [workQueue removeObjectAtIndex:0];
        [titleQueue removeObjectAtIndex:0];
        
        EchoLog(@"正在处理: %@", itemTitle);
        
        // --- Part D: Simulate the click ---
        // This is the most likely point of failure. We try to find a tap gesture recognizer.
        BOOL didClick = NO;
        for (UIGestureRecognizer *recognizer in itemToClick.superview.gestureRecognizers) { // Sometimes gesture is on the superview
            if ([recognizer isKindOfClass:[UITapGestureRecognizer class]] && recognizer.state != UIGestureRecognizerStateFailed) {
                CGPoint touchLocation = [recognizer locationInView:itemToClick];
                if (CGRectContainsPoint(itemToClick.bounds, touchLocation)) {
                    id targets = GetIvarValueSafely(recognizer, @"targets"); // This is an array of targets
                    if ([targets count] > 0) {
                        id targetContainer = targets[0];
                        id target = GetIvarValueSafely(targetContainer, @"target");
                        SEL action = (SEL)[GetIvarValueSafely(targetContainer, @"action") pointerValue];

                        if (target && action && [target respondsToSelector:action]) {
                            EchoLog(@"通过 Gesture Recognizer 点击: %@", itemTitle);
                            #pragma clang diagnostic push
                            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                            [target performSelector:action withObject:recognizer];
                            #pragma clang diagnostic pop
                            didClick = YES;
                            break;
                        }
                    }
                }
            }
        }
        
        if (!didClick) {
            EchoLog(@"警告: 未能在 [%@] 上找到有效的 Tap Gesture。请检查点击事件的处理方式。", itemTitle);
        }

        // Wait for the pop-up to be presented and dismissed, then process the next item.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            processQueue();
        });
    };

    // Start the process
    processQueue();
}
%end
