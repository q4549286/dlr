#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-v14] " format), ##__VA_ARGS__)

static BOOL g_isTestingNianMing = NO;
static NSString *g_currentItemToExtract = nil;
static NSMutableArray *g_capturedZhaiYaoArray = nil; 
static NSMutableArray *g_capturedGeJuArray = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

@interface UIViewController (DelegateTestAddon)
- (void)performTheFinalTest_V14;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            NSInteger testButtonTag = 999014; // v14
            if ([keyWindow viewWithTag:testButtonTag]) [[keyWindow viewWithTag:testButtonTag] removeFromSuperview];
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 200, 45, 90, 36);
            [testButton setTitle:@"终极坐标测试" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            testButton.backgroundColor = [UIColor systemGreenColor]; // Use a confident green
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            testButton.tag = testButtonTag;
            
            [testButton addTarget:self action:@selector(performTheFinalTest_V14) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            EchoLog(@"终极坐标测试按钮 (v14) 已添加。");
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingNianMing && g_currentItemToExtract) {
        // --- Intercept specific modals ---
        if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertController *alert = (UIAlertController *)viewControllerToPresent;
            UIAlertAction *targetAction = nil;
            for (UIAlertAction *action in alert.actions) { if ([action.title isEqualToString:g_currentItemToExtract]) { targetAction = action; break; } }
            if (targetAction) {
                id handler = [targetAction valueForKey:@"handler"]; if (handler) { ((void (^)(UIAlertAction *))handler)(targetAction); }
                return;
            }
        }
        
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        
        if ([g_currentItemToExtract isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) {
            // This view is simple, old logic is fine
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSMutableString *t = [NSMutableString string];
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel* o1, UILabel* o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) { [t appendFormat:@"%@\n", label.text]; }
                }
                [g_capturedZhaiYaoArray addObject:[t stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            });
            return;

        } else if ([g_currentItemToExtract isEqualToString:@"格局方法"] && [vcClassName containsString:@"年命格局視圖"]) {
             // ---【V14 CORE FIX: Absolute Coordinate Extraction】---
             dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *viewsWithAbsoluteFrames = [NSMutableArray array];
                
                // Find all UILabels and UIStackViews
                NSMutableArray *allViews = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UIStackView class], contentView, allViews);
                FindSubviewsOfClassRecursive([UILabel class], contentView, allViews);
                
                // Convert each view's frame to the window's coordinate system
                for (UIView *view in allViews) {
                    if (view.window) { // Ensure the view is actually on screen
                        CGRect absoluteFrame = [view.superview convertRect:view.frame toView:nil];
                        [viewsWithAbsoluteFrames addObject:@{ @"view": view, @"frame": [NSValue valueWithCGRect:absoluteFrame] }];
                    }
                }
                
                // Sort views based on their ABSOLUTE Y coordinate
                [viewsWithAbsoluteFrames sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
                    CGRect frame1 = [obj1[@"frame"] CGRectValue];
                    CGRect frame2 = [obj2[@"frame"] CGRectValue];
                    return [@(frame1.origin.y) compare:@(frame2.origin.y)];
                }];
                
                // Process the correctly sorted views
                NSMutableArray *allContentParts = [NSMutableArray array];
                NSMutableSet *processedLabels = [NSMutableSet set];
                
                for (NSDictionary *info in viewsWithAbsoluteFrames) {
                    UIView *view = info[@"view"];
                    if ([view isKindOfClass:[UIStackView class]]) {
                        UIStackView *stackView = (UIStackView *)view;
                        if (stackView.arrangedSubviews.count >= 2 && [stackView.arrangedSubviews[0] isKindOfClass:[UILabel class]] && [stackView.arrangedSubviews[1] isKindOfClass:[UILabel class]]) {
                            UILabel *titleLabel = stackView.arrangedSubviews[0];
                            UILabel *descLabel = stackView.arrangedSubviews[1];
                            
                            [allContentParts addObject:[NSString stringWithFormat:@"%@→%@", titleLabel.text ?: @"", descLabel.text ?: @""]];
                            
                            [processedLabels addObject:titleLabel];
                            [processedLabels addObject:descLabel];
                        }
                    } else if ([view isKindOfClass:[UILabel class]]) {
                        UILabel *label = (UILabel *)view;
                        if (![processedLabels containsObject:label] && label.text.length > 0) {
                            [allContentParts addObject:label.text];
                            [processedLabels addObject:label];
                        }
                    }
                }
                
                NSString *finalContent = [allContentParts componentsJoinedByString:@"\n"];
                [g_capturedGeJuArray addObject:[finalContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            });
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performTheFinalTest_V14 {
    g_isTestingNianMing = YES;
    g_capturedZhaiYaoArray = [NSMutableArray array];
    g_capturedGeJuArray = [NSMutableArray array];
    
    UICollectionView *targetCollectionView = nil;
    Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    NSMutableArray *collectionViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], self.view, collectionViews);
    for (UICollectionView *cv in collectionViews) { if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) { targetCollectionView = cv; break; } }
    if (!targetCollectionView) { EchoLog(@"错误：未找到行年单元的CollectionView"); g_isTestingNianMing = NO; return; }
    
    NSMutableArray *allUnitCells = [NSMutableArray array];
    for (UIView *cell in targetCollectionView.visibleCells) { if([cell isKindOfClass:unitClass]){ [allUnitCells addObject:cell]; } }
    [allUnitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)]; }];

    void (^extractItem)(NSString *, void(^)(void)) = ^(NSString *itemNameToExtract, void(^completionBlock)(void)){
        dispatch_queue_t queue = dispatch_queue_create("com.echoai.extract.queue", DISPATCH_QUEUE_SERIAL);
        dispatch_async(queue, ^{
            g_currentItemToExtract = itemNameToExtract;
            for (UIView *cell in allUnitCells) {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    id delegate = targetCollectionView.delegate;
                    NSIndexPath *indexPath = [targetCollectionView indexPathForCell:(UICollectionViewCell *)cell];
                    if (delegate && indexPath) {
                        SEL selector = @selector(collectionView:didSelectItemAtIndexPath:);
                        if ([delegate respondsToSelector:selector]) {
                            #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") code; _Pragma("clang diagnostic pop")
                            SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([delegate performSelector:selector withObject:targetCollectionView withObject:indexPath];);
                        }
                    }
                });
                [NSThread sleepForTimeInterval:0.5];
            }
            g_currentItemToExtract = nil;
            if (completionBlock) { dispatch_async(dispatch_get_main_queue(), completionBlock); }
        });
    };
    
    extractItem(@"年命摘要", ^{
        extractItem(@"格局方法", ^{
            NSMutableString *finalResultString = [NSMutableString string];
            for (NSUInteger i = 0; i < allUnitCells.count; i++) {
                NSString *zhaiYao = (i < g_capturedZhaiYaoArray.count) ? g_capturedZhaiYaoArray[i] : @"[年命摘要未提取到]";
                NSString *geJu = (i < g_capturedGeJuArray.count) ? g_capturedGeJuArray[i] : @"[格局方法未提取到]";
                [finalResultString appendFormat:@"--- 人员 %lu ---\n", (unsigned long)i+1];
                [finalResultString appendString:@"【年命摘要】\n"];
                [finalResultString appendString:zhaiYao];
                [finalResultString appendString:@"\n\n【格局方法】\n"];
                [finalResultString appendString:geJu];
                [finalResultString appendString:@"\n\n====================\n\n"];
            }
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"终极提取成功 (%lu人)", (unsigned long)allUnitCells.count] message:finalResultString preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:^{ g_isTestingNianMing = NO; }];
        });
    });
}
%end
