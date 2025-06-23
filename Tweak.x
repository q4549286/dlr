#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-v16] " format), ##__VA_ARGS__)

static BOOL g_isTestingNianMing = NO;
static NSString *g_currentItemToExtract = nil;
static NSMutableArray *g_capturedZhaiYaoArray = nil; 
static NSMutableArray *g_capturedGeJuArray = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

@interface UIViewController (DelegateTestAddon)
- (void)performFinalPreciseCompileFixTest;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            NSInteger testButtonTag = 999016; // v16
            if ([keyWindow viewWithTag:testButtonTag]) [[keyWindow viewWithTag:testButtonTag] removeFromSuperview];
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 200, 45, 90, 36);
            [testButton setTitle:@"编译修复测试" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            testButton.backgroundColor = [UIColor systemPurpleColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            testButton.tag = testButtonTag;
            
            [testButton addTarget:self action:@selector(performFinalPreciseCompileFixTest) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            EchoLog(@"编译修复测试按钮 (v16) 已添加。");
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

        void (^extractSimplePage)(NSMutableArray *) = ^(NSMutableArray *storageArray) {
            UIView *contentView = viewControllerToPresent.view;
            NSMutableArray *allLabels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
            [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
                if (roundf(l1.frame.origin.y) < roundf(l2.frame.origin.y)) return NSOrderedAscending;
                if (roundf(l1.frame.origin.y) > roundf(l2.frame.origin.y)) return NSOrderedDescending;
                return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)];
            }];
            NSMutableArray *textParts = [NSMutableArray array];
            for (UILabel *label in allLabels) {
                if (label.text && label.text.length > 0) { [textParts addObject:label.text]; }
            }
            [storageArray addObject:[textParts componentsJoinedByString:@"\n"]];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        };

        if ([g_currentItemToExtract isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) {
            extractSimplePage(g_capturedZhaiYaoArray);
            return;

        } else if ([g_currentItemToExtract isEqualToString:@"格局方法"] && [vcClassName containsString:@"年命格局視圖"]) {
            @try {
                UIView *contentView = viewControllerToPresent.view;
                NSMutableDictionary *elementsByYPos = [NSMutableDictionary dictionary];
                
                Class tableViewClass = NSClassFromString(@"六壬大占.IntrinsicTableView");
                NSMutableArray *tableViews = [NSMutableArray array];
                if (tableViewClass) { FindSubviewsOfClassRecursive(tableViewClass, contentView, tableViews); }

                UITableView *theTableView = tableViews.firstObject;
                if (theTableView && [theTableView isKindOfClass:[UITableView class]]) {
                    for (UITableViewCell *cell in theTableView.visibleCells) {
                        if ([cell isKindOfClass:NSClassFromString(@"六壬大占.格局單元")]) {
                            NSMutableArray *labelsInCell = [NSMutableArray array];
                            FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labelsInCell);
                            if (labelsInCell.count >= 2) {
                                [labelsInCell sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) { return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)]; }];
                                NSString *title = ((UILabel *)labelsInCell[0]).text ?: @"";
                                NSString *desc = ((UILabel *)labelsInCell[1]).text ?: @"";
                                NSString *formattedText = [NSString stringWithFormat:@"%@→%@", title, desc];
                                // --- 编译修复 ---
                                [elementsByYPos setObject:formattedText forKey:@(cell.frame.origin.y)];
                            }
                        }
                    }
                }
                
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                for (UILabel *label in allLabels) {
                    BOOL isInsideTableView = NO;
                    if (theTableView) { isInsideTableView = [label isDescendantOfView:theTableView]; }
                    
                    if (!isInsideTableView && label.text.length > 0) {
                        // --- 编译修复 ---
                        [elementsByYPos setObject:label.text forKey:@(label.frame.origin.y)];
                    }
                }

                NSArray *sortedKeys = [[elementsByYPos allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                    return [obj1 compare:obj2];
                }];

                NSMutableArray *finalParts = [NSMutableArray array];
                for (NSNumber *key in sortedKeys) { [finalParts addObject:elementsByYPos[key]]; }
                
                [g_capturedGeJuArray addObject:[finalParts componentsJoinedByString:@"\n"]];

            } @catch (NSException *exception) {
                [g_capturedGeJuArray addObject:[NSString stringWithFormat:@"提取异常: %@", exception.reason]];
            } @finally {
                 [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            }
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performFinalPreciseCompileFixTest {
    // 触发逻辑不变
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
                        #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") code; _Pragma("clang diagnostic pop")
                        SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([delegate performSelector:@selector(collectionView:didSelectItemAtIndexPath:) withObject:targetCollectionView withObject:indexPath];);
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
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"精准提取成功 (%lu人)", (unsigned long)allUnitCells.count] message:finalResultString preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:^{ g_isTestingNianMing = NO; }];
        });
    });
}
%end
