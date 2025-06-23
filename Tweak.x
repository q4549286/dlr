#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-v6] " format), ##__VA_ARGS__)

static BOOL g_isTestingNianMing = NO;
static NSMutableArray *g_capturedNianMingArray = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

@interface UIViewController (DelegateTestAddon)
- (void)performMultiExtractTest;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            NSInteger testButtonTag = 999005;
            if ([keyWindow viewWithTag:testButtonTag]) return;
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 200, 45, 90, 36);
            testButton.tag = testButtonTag;
            [testButton setTitle:@"测试多项提取" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor systemBlueColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            
            [testButton addTarget:self action:@selector(performMultiExtractTest) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            EchoLog(@"多项提取测试按钮已添加。");
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingNianMing) {
        // --- 步骤2: 拦截操作表，并依次点击多个选项 ---
        if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertController *alert = (UIAlertController *)viewControllerToPresent;
            UIAlertAction *zhaiYaoAction = nil;
            UIAlertAction *geJuAction = nil;

            for (UIAlertAction *action in alert.actions) {
                if ([action.title isEqualToString:@"年命摘要"]) { zhaiYaoAction = action; }
                if ([action.title isEqualToString:@"格局方法"]) { geJuAction = action; }
            }

            if (zhaiYaoAction || geJuAction) {
                EchoLog(@"已拦截操作表。");
                // 串行执行点击，确保抓取顺序
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    if (zhaiYaoAction) {
                        dispatch_sync(dispatch_get_main_queue(), ^{
                            EchoLog(@"正在自动点击 '年命摘要'...");
                            id handler = [zhaiYaoAction valueForKey:@"handler"];
                            if (handler) { ((void (^)(UIAlertAction *))handler)(zhaiYaoAction); }
                        });
                        [NSThread sleepForTimeInterval:0.4]; // 等待抓取完成
                    }
                    if (geJuAction) {
                        dispatch_sync(dispatch_get_main_queue(), ^{
                            EchoLog(@"正在自动点击 '格局方法'...");
                            id handler = [geJuAction valueForKey:@"handler"];
                            if (handler) { ((void (^)(UIAlertAction *))handler)(geJuAction); }
                        });
                         [NSThread sleepForTimeInterval:0.4]; // 等待抓取完成
                    }
                });
                return; // 阻止原始操作表显示
            }
        }
        
        // --- 步骤3: 拦截内容页 ---
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        NSMutableDictionary *currentPersonData = [g_capturedNianMingArray lastObject]; // 获取当前正在处理的人的字典
        
        // 抓取文本的通用逻辑
        void (^extractText)(NSString *) = ^(NSString *key) {
            NSMutableString *capturedText = [NSMutableString string];
            if (viewControllerToPresent.title) { [capturedText appendFormat:@"%@\n", viewControllerToPresent.title]; }
            NSMutableArray *textualViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UIView class], viewControllerToPresent.view, textualViews);
            [textualViews filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id o, id b){ return [o respondsToSelector:@selector(text)]; }]];
            [textualViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
            for (UIView *view in textualViews) {
                NSString *text = [view valueForKey:@"text"];
                if (text && text.length > 0 && ![capturedText containsString:text]) { [capturedText appendFormat:@"%@\n", text]; }
            }
            [currentPersonData setObject:capturedText forKey:key]; // 存入字典
            EchoLog(@"已提取 '%@' 内容并存入字典。", key);
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        };

        if ([vcClassName containsString:@"年命摘要視圖"]) {
            extractText(@"年命摘要");
            return;
        } else if (viewControllerToPresent.title && [viewControllerToPresent.title containsString:@"格局方法"]) {
            // 这里假设“格局方法”页面的标题包含“格局方法”
            extractText(@"格局方法");
            return;
        } else if ([vcClassName containsString:@"六壬大占.課體視圖"]) { 
            // 如果“格局方法”的类名是唯一的，用类名判断更可靠
             extractText(@"格局方法");
             return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performMultiExtractTest {
    EchoLog(@"--- 开始多项提取所有年命信息测试 ---");
    
    g_isTestingNianMing = YES;
    g_capturedNianMingArray = [NSMutableArray array];
    
    // 查找目标 CollectionView
    UICollectionView *targetCollectionView = nil;
    Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    NSMutableArray *collectionViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], self.view, collectionViews);
    for (UICollectionView *cv in collectionViews) { if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) { targetCollectionView = cv; break; } }
    if (!targetCollectionView) { EchoLog(@"测试中止: 未找到目标 CollectionView。"); g_isTestingNianMing = NO; return; }
    
    // 获取所有行年单元并排序
    NSMutableArray *allUnitCells = [NSMutableArray array];
    for (UIView *cell in targetCollectionView.visibleCells) { if([cell isKindOfClass:unitClass]){ [allUnitCells addObject:cell]; } }
    [allUnitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)]; }];
    EchoLog(@"找到 %lu 个行年单元，将处理 A, B, C...", (unsigned long)allUnitCells.count);

    // 串行队列保证一个一个处理
    dispatch_queue_t serialQueue = dispatch_queue_create("com.echoai.multiextract.queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(serialQueue, ^{
        for (UIView *cell in allUnitCells) {
            @autoreleasepool {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    // 为当前这个人创建一个新的字典来存储他的多项信息
                    [g_capturedNianMingArray addObject:[NSMutableDictionary dictionary]];
                    
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
                // 等待足够长的时间让两个页面的抓取都完成 (0.4 * 2)
                [NSThread sleepForTimeInterval:1.0];
            }
        }
        
        // 所有循环结束后，在主线程显示最终结果
        dispatch_async(dispatch_get_main_queue(), ^{
            EchoLog(@"所有年命多项提取完毕，准备显示最终结果。");
            
            NSMutableString *finalResultString = [NSMutableString string];
            for (NSDictionary *personData in g_capturedNianMingArray) {
                NSString *zhaiYao = personData[@"年命摘要"] ?: @"[年命摘要未提取到]\n";
                NSString *geJu = personData[@"格局方法"] ?: @"[格局方法未提取到]\n";
                [finalResultString appendString:zhaiYao];
                [finalResultString appendString:@"\n--- 格局方法 ---\n"];
                [finalResultString appendString:geJu];
                [finalResultString appendString:@"\n====================\n"];
            }
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"提取成功 (%lu人)", (unsigned long)g_capturedNianMingArray.count] message:finalResultString preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            
            g_isTestingNianMing = NO;
        });
    });
}
%end
