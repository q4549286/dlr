#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-v20-Activation] " format), ##__VA_ARGS__)

static BOOL g_isTestingNianMing = NO;
static NSString *g_currentItemToExtract = nil;
static NSMutableArray *g_capturedZhaiYaoArray = nil; 
static NSMutableArray *g_capturedGeJuArray = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// 模拟点击一个视图的辅助函数
static void SimulateTapOnView(UIView *view) {
    if (!view) return;
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
            EchoLog(@"找到并准备触发Tap手势。");
            // 这是一个技巧，直接获取target和action来执行
            unsigned int count = 0;
            Ivar ivar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
            if (ivar) {
                id targets = object_getIvar(recognizer, ivar);
                if (targets && [targets count] > 0) {
                    id targetContainer = [targets firstObject];
                    id target = [targetContainer valueForKey:@"_target"];
                    SEL action = (SEL)[targetContainer valueForKey:@"_action"];
                    if (target && action) {
                        EchoLog(@"成功触发点击激活！Target: %@, Action: %@", NSStringFromClass([target class]), NSStringFromSelector(action));
                        [target performSelector:action withObject:recognizer];
                        return;
                    }
                }
            }
        }
    }
    EchoLog(@"警告：在视图 %@ 上未找到可直接触发的Tap手势。", view);
}


@interface UIViewController (DelegateTestAddon)
- (void)performActivationExtractTest;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            NSInteger testButtonTag = 999020; // v20
            if ([keyWindow viewWithTag:testButtonTag]) [[keyWindow viewWithTag:testButtonTag] removeFromSuperview];
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 200, 45, 90, 36);
            [testButton setTitle:@"激活提取测试" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            testButton.backgroundColor = [UIColor systemGreenColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            testButton.tag = testButtonTag;
            
            [testButton addTarget:self action:@selector(performActivationExtractTest) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            EchoLog(@"激活提取测试按钮 (v20) 已添加。");
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingNianMing && g_currentItemToExtract) {
        if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertAction *targetAction = nil;
            for (UIAlertAction *action in alert.actions) { if ([action.title isEqualToString:g_currentItemToExtract]) { targetAction = action; break; } }
            if (targetAction) { id handler = [targetAction valueForKey:@"handler"]; if (handler) { ((void (^)(UIAlertAction *))handler)(targetAction); } return; }
        }
        
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);

        if ([g_currentItemToExtract isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) {
            // 这个页面依然简单，直接提取
            UIView *contentView = viewControllerToPresent.view;
            NSMutableArray *allLabels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
            [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) { return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)]; }];
            NSMutableArray *textParts = [NSMutableArray array];
            for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } }
            [g_capturedZhaiYaoArray addObject:[textParts componentsJoinedByString:@"\n"]];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;

        } else if ([g_currentItemToExtract isEqualToString:@"格局方法"] && [vcClassName containsString:@"年命格局視圖"]) {
            // ---【核心修正 V20：模拟点击激活】---
            // 先让VC呈现出来，但不在这里提取和关闭
            // completion block 里才是我们的主战场
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }

                // 延迟 0.2 秒，确保视图完全加载
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    UIView *contentView = viewControllerToPresent.view;

                    // 1. 找到需要点击的单元格 (格局单元)
                    Class geJuCellClass = NSClassFromString(@"六壬大占.格局單元");
                    NSMutableArray *cells = [NSMutableArray array];
                    if (geJuCellClass) { FindSubviewsOfClassRecursive(geJuCellClass, contentView, cells); }
                    
                    // 模拟点击所有找到的格局单元格
                    for (UIView *cell in cells) {
                        SimulateTapOnView(cell);
                    }
                    
                    // 延迟 0.3 秒，等待点击后的UI更新 (内容展开)
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        
                        // 2. 此刻，所有内容已激活，使用最可靠的UILabel抓取法
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
                        
                        [g_capturedGeJuArray addObject:[textParts componentsJoinedByString:@"\n"]];
                        
                        // 3. 提取完毕，关闭视图
                        [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
                    });
                });
            };
            // 用我们自己的completion block替换原来的
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performActivationExtractTest {
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
                // 增加延时以等待动画和网络操作
                [NSThread sleepForTimeInterval:1.0]; 
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
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"激活提取成功 (%lu人)", (unsigned long)allUnitCells.count] message:finalResultString preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:^{ g_isTestingNianMing = NO; }];
        });
    });
}
%end
