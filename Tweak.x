#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-v15] " format), ##__VA_ARGS__)

static BOOL g_isTestingNianMing = NO;
static NSString *g_currentItemToExtract = nil;
static NSMutableArray *g_capturedZhaiYaoArray = nil; 
static NSMutableArray *g_capturedGeJuArray = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// ======================= HOOK 1: 主 VC 和 年命摘要 VC =======================

@interface UIViewController (DelegateTestAddon)
- (void)performFinalTimingExtractTest;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            NSInteger testButtonTag = 999015; // v15
            if ([keyWindow viewWithTag:testButtonTag]) return;
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 200, 45, 90, 36);
            [testButton setTitle:@"时机最终测试" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            testButton.backgroundColor = [UIColor systemPurpleColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            testButton.tag = testButtonTag;
            
            [testButton addTarget:self action:@selector(performFinalTimingExtractTest) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            EchoLog(@"时机最终测试按钮 (v15) 已添加。");
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingNianMing && g_currentItemToExtract) {
        if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertAction *targetAction = nil;
            for (UIAlertAction *action in ((UIAlertController *)viewControllerToPresent).actions) { if ([action.title isEqualToString:g_currentItemToExtract]) { targetAction = action; break; } }
            if (targetAction) { id handler = [targetAction valueForKey:@"handler"]; if (handler) { ((void (^)(UIAlertAction *))handler)(targetAction); } return; }
        }
        
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        
        // 只处理 "年命摘要"，"格局方法" 的逻辑已经移到下面的新 hook 中
        if ([g_currentItemToExtract isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) {
            UIView *contentView = viewControllerToPresent.view;
            NSMutableArray *allLabels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
            [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
                if (roundf(l1.frame.origin.y) < roundf(l2.frame.origin.y)) return NSOrderedAscending;
                if (roundf(l1.frame.origin.y) > roundf(l2.frame.origin.y)) return NSOrderedDescending;
                return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)];
            }];
            NSMutableArray *textParts = [NSMutableArray array];
            for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } }
            [g_capturedZhaiYaoArray addObject:[textParts componentsJoinedByString:@"\n"]];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performFinalTimingExtractTest {
    // 这部分代码不变
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
                NSString *zhaiYao = (i < g_capturedZhaiYaoArray.count) ? g_capturedZhaiYaoArray[i] : @"[年命摘要未提取到]";
                NSString *geJu = (i < g_capturedGeJuArray.count) ? g_capturedGeJuArray[i] : @"[格局方法未提取到]";
                
                [finalResultString appendFormat:@"--- 人员 %lu ---\n", (unsigned long)i+1];
                [finalResultString appendString:@"【年命摘要】\n"];
                [finalResultString appendString:zhaiYao];
                [finalResultString appendString:@"\n\n【格局方法】\n"];
                [finalResultString appendString:geJu];
                [finalResultString appendString:@"\n\n====================\n\n"];
            }

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"最终提取成功 (%lu人)", (unsigned long)allUnitCells.count] message:finalResultString preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:^{ g_isTestingNianMing = NO; }];
        });
    });
}
%end

// ======================= HOOK 2: 专门拦截“格局方法”的视图控制器 =======================

// 视图控制器类名是根据视图类名推断的，如果不行，需要您确认一下
%hook 六壬大占.年命格局視圖控制器 

- (void)viewDidAppear:(BOOL)animated {
    // 只有在我们的测试进行时才执行特殊逻辑
    if (g_isTestingNianMing && [g_currentItemToExtract isEqualToString:@"格局方法"]) {
        EchoLog(@"成功拦截到“格局方法”视图控制器，时机正确！开始提取...");
        
        // 在这里，视图已经完全加载，可以安全地提取所有UILabel
        UIView *contentView = self.view;
        NSMutableArray *allLabels = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
        
        [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
            if (roundf(l1.frame.origin.y) < roundf(l2.frame.origin.y)) return NSOrderedAscending;
            if (roundf(l1.frame.origin.y) > roundf(l2.frame.origin.y)) return NSOrderedDescending;
            return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)];
        }];
        
        NSMutableArray *textParts = [NSMutableArray array];
        for (UILabel *label in allLabels) {
            if (label.text && label.text.length > 0) {
                [textParts addObject:label.text];
            }
        }
        
        NSString *finalContent = [textParts componentsJoinedByString:@"\n"];
        [g_capturedGeJuArray addObject:finalContent];
        EchoLog(@"提取内容:\n%@", finalContent);
        
        // 立即关闭这个VC，实现无感抓取
        [self dismissViewControllerAnimated:NO completion:nil];
        
        // 因为我们已经处理并关闭了它，所以不需要再执行原始的 viewDidAppear
        return;
    }
    
    // 如果不是我们的测试，就正常执行
    %orig(animated);
}

%end
