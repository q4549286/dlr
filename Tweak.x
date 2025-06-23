#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-v7] " format), ##__VA_ARGS__)

static BOOL g_isTestingNianMing = NO;
// 【修正】使用两个独立的数组，避免逻辑混乱
static NSMutableArray *g_capturedZhaiYaoArray = nil; 
static NSMutableArray *g_capturedGeJuArray = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

@interface UIViewController (DelegateTestAddon)
- (void)performFixedMultiExtractTest;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            NSInteger testButtonTag = 999006;
            if ([keyWindow viewWithTag:testButtonTag]) return;
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 200, 45, 90, 36);
            [testButton setTitle:@"测试多项(修复)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            testButton.backgroundColor = [UIColor systemTealColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            testButton.tag = testButtonTag;
            
            [testButton addTarget:self action:@selector(performFixedMultiExtractTest) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            EchoLog(@"修复版多项提取测试按钮已添加。");
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingNianMing) {
        if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertController *alert = (UIAlertController *)viewControllerToPresent;
            UIAlertAction *zhaiYaoAction = nil, *geJuAction = nil;
            for (UIAlertAction *action in alert.actions) {
                if ([action.title isEqualToString:@"年命摘要"]) { zhaiYaoAction = action; }
                if ([action.title isEqualToString:@"格局方法"]) { geJuAction = action; }
            }

            if (zhaiYaoAction || geJuAction) {
                EchoLog(@"已拦截操作表。");
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    if (zhaiYaoAction) {
                        dispatch_sync(dispatch_get_main_queue(), ^{
                            id handler = [zhaiYaoAction valueForKey:@"handler"];
                            if (handler) { ((void (^)(UIAlertAction *))handler)(zhaiYaoAction); }
                        });
                        [NSThread sleepForTimeInterval:0.4];
                    }
                    if (geJuAction) {
                        dispatch_sync(dispatch_get_main_queue(), ^{
                            id handler = [geJuAction valueForKey:@"handler"];
                            if (handler) { ((void (^)(UIAlertAction *))handler)(geJuAction); }
                        });
                         [NSThread sleepForTimeInterval:0.4];
                    }
                });
                return;
            }
        }
        
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        NSString *vcTitle = viewControllerToPresent.title ?: @"";
        
        // 通用文本提取逻辑
        NSString* (^extractTextFromVC)(void) = ^NSString* {
            NSMutableString *capturedText = [NSMutableString string];
            if (vcTitle) { [capturedText appendFormat:@"%@\n", vcTitle]; }
            NSMutableArray *textualViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UIView class], viewControllerToPresent.view, textualViews);
            [textualViews filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id o, id b){ return [o respondsToSelector:@selector(text)]; }]];
            [textualViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
            for (UIView *view in textualViews) {
                NSString *text = [view valueForKey:@"text"];
                if (text && text.length > 0 && ![capturedText containsString:text]) { [capturedText appendFormat:@"%@\n", text]; }
            }
            return [capturedText copy];
        };
        
        // 【修正】根据页面类型，存入对应的数组
        if ([vcClassName containsString:@"年命摘要視圖"]) {
            NSString *text = extractTextFromVC();
            [g_capturedZhaiYaoArray addObject:text];
            EchoLog(@"已提取 '年命摘要'，当前数量: %lu", (unsigned long)g_capturedZhaiYaoArray.count);
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;
        } else if ([vcTitle containsString:@"格局方法"]) {
            NSString *text = extractTextFromVC();
            [g_capturedGeJuArray addObject:text];
            EchoLog(@"已提取 '格局方法'，当前数量: %lu", (unsigned long)g_capturedGeJuArray.count);
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performFixedMultiExtractTest {
    EchoLog(@"--- 开始(修复版)多项提取所有年命信息测试 ---");
    
    g_isTestingNianMing = YES;
    // 【修正】初始化两个数组
    g_capturedZhaiYaoArray = [NSMutableArray array];
    g_capturedGeJuArray = [NSMutableArray array];
    
    UICollectionView *targetCollectionView = nil;
    Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    NSMutableArray *collectionViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], self.view, collectionViews);
    for (UICollectionView *cv in collectionViews) { if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) { targetCollectionView = cv; break; } }
    if (!targetCollectionView) { EchoLog(@"测试中止: 未找到目标 CollectionView。"); g_isTestingNianMing = NO; return; }
    
    NSMutableArray *allUnitCells = [NSMutableArray array];
    for (UIView *cell in targetCollectionView.visibleCells) { if([cell isKindOfClass:unitClass]){ [allUnitCells addObject:cell]; } }
    [allUnitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)]; }];
    EchoLog(@"找到 %lu 个行年单元，将处理...", (unsigned long)allUnitCells.count);

    dispatch_queue_t serialQueue = dispatch_queue_create("com.echoai.fixed.queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(serialQueue, ^{
        for (UIView *cell in allUnitCells) {
            @autoreleasepool {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    id delegate = targetCollectionView.delegate;
                    NSIndexPath *indexPath = [targetCollectionView indexPathForCell:(UICollectionViewCell *)cell];
                    if (delegate && indexPath) {
                        EchoLog(@"正在处理单元: item %ld", (long)indexPath.item);
                        SEL selector = @selector(collectionView:didSelectItemAtIndexPath:);
                        if ([delegate respondsToSelector:selector]) {
                            #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") code; _Pragma("clang diagnostic pop")
                            SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([delegate performSelector:selector withObject:targetCollectionView withObject:indexPath];);
                        }
                    }
                });
                [NSThread sleepForTimeInterval:1.0];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            EchoLog(@"所有年命多项提取完毕，准备显示最终结果。");
            
            NSMutableString *finalResultString = [NSMutableString string];
            NSUInteger count = allUnitCells.count;

            for (NSUInteger i = 0; i < count; i++) {
                // 【修正】从各自的数组中按顺序取出数据
                NSString *zhaiYao = (i < g_capturedZhaiYaoArray.count) ? g_capturedZhaiYaoArray[i] : @"[年命摘要未提取到]\n";
                NSString *geJu = (i < g_capturedGeJuArray.count) ? g_capturedGeJuArray[i] : @"[格局方法未提取到]\n";
                
                [finalResultString appendString:zhaiYao];
                [finalResultString appendString:@"\n--- 格局方法 ---\n"];
                [finalResultString appendString:geJu];
                [finalResultString appendString:@"\n====================\n"];
            }
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"提取成功 (%lu人)", (unsigned long)count] message:finalResultString preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            
            g_isTestingNianMing = NO;
        });
    });
}
%end
