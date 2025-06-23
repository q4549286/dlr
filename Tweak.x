#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-v12] " format), ##__VA_ARGS__)

static BOOL g_isTestingNianMing = NO;
static NSString *g_currentItemToExtract = nil;
static NSMutableArray *g_capturedZhaiYaoArray = nil; 
static NSMutableArray *g_capturedGeJuArray = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

@interface UIViewController (DelegateTestAddon)
- (void)performFinalPreciseExtractTest;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            NSInteger testButtonTag = 999011;
            if ([keyWindow viewWithTag:testButtonTag]) return;
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 200, 45, 90, 36);
            [testButton setTitle:@"最终精准测试" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            testButton.backgroundColor = [UIColor colorWithRed:0 green:0.5 blue:0.5 alpha:1.0]; // 青色
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            testButton.tag = testButtonTag;
            
            [testButton addTarget:self action:@selector(performFinalPreciseExtractTest) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            EchoLog(@"最终精准测试按钮已添加。");
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingNianMing && g_currentItemToExtract) {
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
        
        // ---【核心修正】---
        if ([g_currentItemToExtract isEqualToString:@"格局方法"] && [vcClassName containsString:@"年命格局視圖"]) {
            EchoLog(@"检测到 '年命格局视窗'，开始精准定位 '格局单元'...");
            
            NSMutableString *fullContent = [NSMutableString string];
            Class gejuUnitClass = NSClassFromString(@"六壬大占.格局單元");
            
            if (gejuUnitClass) {
                NSMutableArray *gejuUnits = [NSMutableArray array];
                FindSubviewsOfClassRecursive(gejuUnitClass, viewControllerToPresent.view, gejuUnits);
                [gejuUnits sortUsingComparator:^NSComparisonResult(UIView* obj1, UIView* obj2) {
                    return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)];
                }];
                
                EchoLog(@"找到 %lu 个 '格局单元'。", (unsigned long)gejuUnits.count);
                
                for (UIView *unitView in gejuUnits) {
                    NSMutableArray *labelsInUnit = [NSMutableArray array];
                    FindSubviewsOfClassRecursive([UILabel class], unitView, labelsInUnit);
                     [labelsInUnit sortUsingComparator:^NSComparisonResult(UILabel* obj1, UILabel* obj2) {
                        if (roundf(obj1.frame.origin.y) < roundf(obj2.frame.origin.y)) return NSOrderedAscending;
                        if (roundf(obj1.frame.origin.y) > roundf(obj2.frame.origin.y)) return NSOrderedDescending;
                        return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)];
                    }];
                    
                    for (UILabel *label in labelsInUnit) {
                        if (label.text && label.text.length > 0) {
                            [fullContent appendFormat:@"%@\n", label.text];
                        }
                    }
                }
            } else {
                EchoLog(@"错误: 找不到 '六壬大占.格局單元' 类！");
                [fullContent appendString:@"[错误: 找不到格局单元类]"];
            }

            [g_capturedGeJuArray addObject:[fullContent copy]];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;

        } else if ([g_currentItemToExtract isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) {
            // 年命摘要的提取方式保持不变 (这个之前已验证是正确的)
            NSMutableString *t = [NSMutableString string];
            NSMutableArray *allLabels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, allLabels);
            [allLabels sortUsingComparator:^NSComparisonResult(UILabel* o1, UILabel* o2){return [@(o1.frame.origin.y)compare:@(o2.frame.origin.y)];}];
            for(UILabel*l in allLabels){if(l.text&&l.text.length>0)[t appendFormat:@"%@\n",l.text];}
            [g_capturedZhaiYaoArray addObject:[t copy]];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performFinalPreciseExtractTest {
    // 这部分循环逻辑已经稳定，无需修改
    g_isTestingNianMing = YES;
    g_capturedZhaiYaoArray = [NSMutableArray array];
    g_capturedGeJuArray = [NSMutableArray array];
    
    UICollectionView *targetCollectionView = nil;
    Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    NSMutableArray *collectionViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], self.view, collectionViews);
    for (UICollectionView *cv in collectionViews) { if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) { targetCollectionView = cv; break; } }
    if (!targetCollectionView) { g_isTestingNianMing = NO; return; }
    
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
                NSString *zhaiYao = (i < g_capturedZhaiYaoArray.count) ? g_capturedZhaiYaoArray[i] : @"[年命摘要未提取到]\n";
                NSString *geJu = (i < g_capturedGeJuArray.count) ? g_capturedGeJuArray[i] : @"[格局方法未提取到]\n";
                [finalResultString appendString:zhaiYao];
                [finalResultString appendString:@"\n--- 格局方法 ---\n"];
                [finalResultString appendString:geJu];
                [finalResultString appendString:@"\n====================\n"];
            }
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"精准提取成功 (%lu人)", (unsigned long)allUnitCells.count] message:finalResultString preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:^{ g_isTestingNianMing = NO; }];
        });
    });
}
%end
