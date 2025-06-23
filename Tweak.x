#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-v10] " format), ##__VA_ARGS__)

static BOOL g_isTestingNianMing = NO;
static NSString *g_currentItemToExtract = nil;
static NSMutableArray *g_capturedZhaiYaoArray = nil; 
static NSMutableArray *g_capturedGeJuArray = nil;

// --- 【新增】读取 Ivar 的辅助函数 ---
static id GetIvarValue(id object, const char *ivarName) {
    Ivar ivar = class_getInstanceVariable([object class], ivarName);
    if (ivar) {
        return object_getIvar(object, ivar);
    }
    return nil;
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

@interface UIViewController (DelegateTestAddon)
- (void)performFinalIvarExtractTest;
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
            [testButton setTitle:@"最终完美提取" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            testButton.backgroundColor = [UIColor colorWithRed:0 green:0.5 blue:0.5 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            testButton.tag = testButtonTag;
            
            [testButton addTarget:self action:@selector(performFinalIvarExtractTest) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            EchoLog(@"最终完美提取测试按钮已添加。");
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingNianMing && g_currentItemToExtract) {
        if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertAction *targetAction = nil;
            for (UIAlertAction *action in [(UIAlertController *)viewControllerToPresent actions]) {
                if ([action.title isEqualToString:g_currentItemToExtract]) { targetAction = action; break; }
            }
            if (targetAction) {
                EchoLog(@"已拦截操作表，将自动点击 '%@'...", g_currentItemToExtract);
                id handler = [targetAction valueForKey:@"handler"];
                if (handler) { ((void (^)(UIAlertAction *))handler)(targetAction); }
                return;
            }
        }
        
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);

        if ([g_currentItemToExtract isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) {
            // 年命摘要视图使用通用方法提取
            NSMutableString *t = [NSMutableString string];
            if(viewControllerToPresent.title){ [t appendFormat:@"%@\n", viewControllerToPresent.title]; }
            NSMutableArray *v = [NSMutableArray array]; FindSubviewsOfClassRecursive([UIView class],viewControllerToPresent.view,v);
            [v filterUsingPredicate:[NSPredicate predicateWithBlock:^(id o,id b){return[o respondsToSelector:@selector(text)];}]];
            [v sortUsingComparator:^NSComparisonResult(UIView*v1,UIView*v2){return[@(v1.frame.origin.y)compare:@(v2.frame.origin.y)];}];
            for(UIView*view in v){NSString*text=[view valueForKey:@"text"];if(text&&text.length>0&&![t containsString:text]){[t appendFormat:@"%@\n",text];}}
            [g_capturedZhaiYaoArray addObject:[t copy]];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;
        } else if ([g_currentItemToExtract isEqualToString:@"格局方法"] && [vcClassName containsString:@"年命格局視圖"]) {
            // ---【核心修正】年命格局视图，使用 Ivar 读取法 ---
            EchoLog(@"检测到 '年命格局視圖'，使用 Ivar 读取法...");
            NSMutableString *resultText = [NSMutableString string];
            if (viewControllerToPresent.title) {
                [resultText appendFormat:@"%@\n", viewControllerToPresent.title];
            }
            
            // 读取两个关键的数组 ivar
            // 注意：ivar 名称可能因为 Swift 版本而变化，例如 `_年命格局列` 或 `__lazy_storage_$_年命格局列`
            NSArray *geJuList = GetIvarValue(viewControllerToPresent, "_$s12sixren_dazhan20nianMingGeJuShiTuC0cdE1LieSo7NSArrayCSgvp");
            if (!geJuList) geJuList = GetIvarValue(viewControllerToPresent, "__lazy_storage_$_年命格局列"); // 备用名称
            
            NSArray *fangFaList = GetIvarValue(viewControllerToPresent, "_$s12sixren_dazhan20nianMingGeJuShiTuC0cdF2LieSo7NSArrayCSgvp");
            if (!fangFaList) fangFaList = GetIvarValue(viewControllerToPresent, "__lazy_storage_$_年命方法列"); // 备用名称

            if (geJuList) {
                for (id item in geJuList) {
                    if ([item isKindOfClass:[NSString class]]) {
                        [resultText appendFormat:@"%@\n", item];
                    } else if ([item isKindOfClass:[NSArray class]] && ((NSArray *)item).count >= 2) {
                        [resultText appendFormat:@"%@: %@\n", ((NSArray *)item)[0], ((NSArray *)item)[1]];
                    }
                }
            } else {
                 [resultText appendString:@"[年命格局列 未读取到]\n"];
            }
            
            if (fangFaList) {
                [resultText appendString:@"\n--- 方法 ---\n"];
                for (id item in fangFaList) {
                     if ([item isKindOfClass:[NSString class]]) {
                        [resultText appendFormat:@"%@\n", item];
                    } else if ([item isKindOfClass:[NSArray class]] && ((NSArray *)item).count >= 2) {
                        [resultText appendFormat:@"%@: %@\n", ((NSArray *)item)[0], ((NSArray *)item)[1]];
                    }
                }
            }
            
            [g_capturedGeJuArray addObject:[resultText copy]];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performFinalIvarExtractTest {
    // 这部分与 v8/v9 完全相同，无需修改
    EchoLog(@"--- 开始(最终版 Ivar 读取)测试 ---");
    g_isTestingNianMing = YES;
    g_capturedZhaiYaoArray = [NSMutableArray array];
    g_capturedGeJuArray = [NSMutableArray array];
    
    UICollectionView *targetCollectionView = nil;
    Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    NSMutableArray *collectionViews = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], self.view, collectionViews);
    for (UICollectionView *cv in collectionViews) { if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) { targetCollectionView = cv; break; } }
    if (!targetCollectionView) { g_isTestingNianMing = NO; return; }
    
    NSMutableArray *allUnitCells = [NSMutableArray array];
    for (UIView *cell in targetCollectionView.visibleCells) { if([cell isKindOfClass:unitClass]){ [allUnitCells addObject:cell]; } }
    [allUnitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)]; }];

    void (^extractItem)(NSString *, void(^)(void)) = ^(NSString *itemNameToExtract, void(^completionBlock)(void)){
        dispatch_queue_t queue = dispatch_queue_create("com.echoai.extract.queue", DISPATCH_QUEUE_SERIAL);
        dispatch_async(queue, ^{
            g_currentItemToExtract = itemNameToExtract;
            EchoLog(@"===== 开始提取: %@ =====", itemNameToExtract);
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
            EchoLog(@"===== %@ 提取完成 =====", itemNameToExtract);
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
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"最终提取成功 (%lu人)", (unsigned long)allUnitCells.count] message:finalResultString preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:^{ g_isTestingNianMing = NO; }];
        });
    });
}
%end
