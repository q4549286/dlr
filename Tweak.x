#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-v13] " format), ##__VA_ARGS__)

static BOOL g_isTestingNianMing = NO;
static NSString *g_currentItemToExtract = nil;
static NSMutableArray *g_capturedZhaiYaoArray = nil; 
static NSMutableArray *g_capturedGeJuArray = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

@interface UIViewController (DelegateTestAddon)
- (void)performFinalHybridExtractTest;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            NSInteger testButtonTag = 999013; // v13
            if ([keyWindow viewWithTag:testButtonTag]) return;
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 200, 45, 90, 36);
            [testButton setTitle:@"混合提取测试" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            testButton.backgroundColor = [UIColor systemGreenColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            testButton.tag = testButtonTag;
            
            [testButton addTarget:self action:@selector(performFinalHybridExtractTest) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            EchoLog(@"混合提取测试按钮 (v13) 已添加。");
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
        
        if ([g_currentItemToExtract isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) {
            // 年命摘要页面结构简单，用通用提取逻辑即可
            NSMutableString *t = [NSMutableString string];
            NSMutableArray *allLabels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, allLabels);
            [allLabels sortUsingComparator:^NSComparisonResult(UILabel* obj1, UILabel* obj2) {
                return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)];
            }];
            for (UILabel *label in allLabels) {
                if (label.text && label.text.length > 0) { [t appendFormat:@"%@\n", label.text]; }
            }
            [g_capturedZhaiYaoArray addObject:[t stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;

        } else if ([g_currentItemToExtract isEqualToString:@"格局方法"] && [vcClassName containsString:@"年命格局視圖"]) {
            // ---【核心修正：V13 混合提取逻辑】---
            @try {
                UIView *contentView = viewControllerToPresent.view;
                Class geJuCellClass = NSClassFromString(@"六壬大占.格局單元");
                if (!geJuCellClass) { [g_capturedGeJuArray addObject:@"错误：找不到格局单元类"]; [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil]; return; }

                NSMutableArray *contentElements = [NSMutableArray array];
                NSMutableSet *labelsInCells = [NSMutableSet set];
                
                // 1. 找到所有格局单元格，并标记它们内部的UILabel
                NSMutableArray *allCells = [NSMutableArray array];
                FindSubviewsOfClassRecursive(geJuCellClass, contentView, allCells);
                for (UIView *cell in allCells) {
                    [contentElements addObject:cell];
                    NSMutableArray *labels = [NSMutableArray array];
                    FindSubviewsOfClassRecursive([UILabel class], cell, labels);
                    for (UILabel *label in labels) { [labelsInCells addObject:label]; }
                }

                // 2. 找到所有独立的UILabel (即不在格局单元格内的)
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                for (UILabel *label in allLabels) {
                    if (![labelsInCells containsObject:label]) {
                        [contentElements addObject:label];
                    }
                }

                // 3. 按Y坐标排序所有内容元素
                [contentElements sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
                    return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)];
                }];

                // 4. 遍历排序后的元素，生成最终文本
                NSMutableArray *textParts = [NSMutableArray array];
                for (UIView *element in contentElements) {
                    if ([element isKindOfClass:geJuCellClass]) {
                        // 如果是格局单元格，提取标题和内容
                        NSMutableArray *labels = [NSMutableArray array];
                        FindSubviewsOfClassRecursive([UILabel class], element, labels);
                        if (labels.count >= 2) {
                            [labels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2){ return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)]; }];
                            NSString *title = ((UILabel *)labels[0]).text ?: @"";
                            NSString *desc = ((UILabel *)labels[1]).text ?: @"";
                            [textParts addObject:[NSString stringWithFormat:@"%@→%@", title, desc]];
                        }
                    } else if ([element isKindOfClass:[UILabel class]]) {
                        // 如果是独立UILabel，直接添加文本
                        NSString *text = ((UILabel *)element).text;
                        if (text && text.length > 0) {
                           [textParts addObject:text];
                        }
                    }
                }
                
                NSString *finalContent = [textParts componentsJoinedByString:@"\n"];
                [g_capturedGeJuArray addObject:[finalContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                
            } @catch (NSException *exception) {
                [g_capturedGeJuArray addObject:[NSString stringWithFormat:@"提取异常: %@", exception.reason]];
            } @finally {
                 [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
                 return;
            }
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performFinalHybridExtractTest {
    // 这部分代码与v12完全相同
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

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"混合提取成功 (%lu人)", (unsigned long)allUnitCells.count] message:finalResultString preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:^{ g_isTestingNianMing = NO; }];
        });
    });
}
%end
