#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-v10] " format), ##__VA_ARGS__)

static BOOL g_isTestingNianMing = NO;
static NSString *g_currentItemToExtract = nil;
static NSMutableArray *g_capturedZhaiYaoArray = nil; 
static NSMutableArray *g_capturedGeJuArray = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

@interface UIViewController (DelegateTestAddon)
- (void)performFinalRefinedExtractTest;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            NSInteger testButtonTag = 999009;
            if ([keyWindow viewWithTag:testButtonTag]) return;
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 200, 45, 90, 36);
            [testButton setTitle:@"精细提取测试" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            testButton.backgroundColor = [UIColor darkGrayColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            testButton.tag = testButtonTag;
            
            [testButton addTarget:self action:@selector(performFinalRefinedExtractTest) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            EchoLog(@"精细提取测试按钮已添加。");
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
        
        // 【核心修正】为“格局方法”页面实现精细化提取逻辑
        if ([g_currentItemToExtract isEqualToString:@"格局方法"] && [vcClassName containsString:@"年命格局視圖"]) {
            EchoLog(@"检测到 '年命格局视窗'，开始精细化提取...");
            NSMutableArray *textParts = [NSMutableArray array];
            
            // 查找所有的 StackView
            NSMutableArray *stackViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UIStackView class], viewControllerToPresent.view, stackViews);
            [stackViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
            
            // 提取前置信息 (不在StackView内的Label)
            NSMutableArray *prefixLabels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, prefixLabels);
             // 过滤掉已经在StackView中的label
            [prefixLabels filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UILabel *label, id bindings) {
                UIView *superview = label.superview;
                while (superview) {
                    if ([superview isKindOfClass:[UIStackView class]]) return NO;
                    superview = superview.superview;
                }
                return YES;
            }]];
            [prefixLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2){ return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)]; }];
            for(UILabel *label in prefixLabels) {
                if(label.text && label.text.length > 0) [textParts addObject:label.text];
            }


            for (UIStackView *stackView in stackViews) {
                NSArray *arrangedSubviews = stackView.arrangedSubviews;
                if (arrangedSubviews.count >= 2 && [arrangedSubviews[0] isKindOfClass:[UILabel class]] && [arrangedSubviews[1] isKindOfClass:[UILabel class]]) {
                    NSString *title = ((UILabel *)arrangedSubviews[0]).text ?: @"";
                    NSString *desc = ((UILabel *)arrangedSubviews[1]).text ?: @"";
                    // 组合成 "标题→内容" 的格式
                    [textParts addObject:[NSString stringWithFormat:@"%@→%@", title, desc]];
                }
            }
            
            NSString *fullContent = [textParts componentsJoinedByString:@"\n"];
            [g_capturedGeJuArray addObject:fullContent];
            
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;

        } else if ([g_currentItemToExtract isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) {
            // 年命摘要使用通用提取逻辑
            NSMutableString *t = [NSMutableString string];
            if(viewControllerToPresent.title){ [t appendFormat:@"%@\n", viewControllerToPresent.title]; }
            NSMutableArray *v = [NSMutableArray array]; FindSubviewsOfClassRecursive([UIView class],viewControllerToPresent.view,v);
            [v filterUsingPredicate:[NSPredicate predicateWithBlock:^(id o,id b){return[o respondsToSelector:@selector(text)];}]];
            [v sortUsingComparator:^NSComparisonResult(UIView*v1,UIView*v2){return[@(v1.frame.origin.y)compare:@(v2.frame.origin.y)];}];
            for(UIView*view in v){NSString*text=[view valueForKey:@"text"];if(text&&text.length>0&&![t containsString:text]){[t appendFormat:@"%@\n",text];}}

            [g_capturedZhaiYaoArray addObject:[t copy]];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performFinalRefinedExtractTest {
    // 这部分代码与v8/v9完全相同，只是调用了一个新的名字
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
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"精细提取成功 (%lu人)", (unsigned long)allUnitCells.count] message:finalResultString preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:^{ g_isTestingNianMing = NO; }];
        });
    });
}
%end
