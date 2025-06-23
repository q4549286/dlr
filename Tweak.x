#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-v5] " format), ##__VA_ARGS__)

// =========================================================================
// 全局变量
// =========================================================================
static BOOL g_isTestingNianMing = NO;
static NSMutableArray *g_capturedNianMingArray = nil; // 改为数组，存储多次抓取的结果

// =========================================================================
// 辅助函数
// =========================================================================
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 测试专用 Hook
// =========================================================================

@interface UIViewController (DelegateTestAddon)
- (void)performLoopingNianMingTest;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            NSInteger testButtonTag = 999004;
            if ([keyWindow viewWithTag:testButtonTag]) return;
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 200, 45, 90, 36);
            testButton.tag = testButtonTag;
            [testButton setTitle:@"测试循环提取" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor systemGreenColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            
            [testButton addTarget:self action:@selector(performLoopingNianMingTest) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            EchoLog(@"循环提取测试按钮已添加。");
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingNianMing) {
        if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertController *alert = (UIAlertController *)viewControllerToPresent;
            UIAlertAction *targetAction = nil;
            for (UIAlertAction *action in alert.actions) { if ([action.title isEqualToString:@"年命摘要"]) { targetAction = action; break; } }
            if (targetAction) {
                EchoLog(@"已拦截 '年命摘要' 操作表，自动点击。");
                id handler = [targetAction valueForKey:@"handler"];
                if (handler) { ((void (^)(UIAlertAction *))handler)(targetAction); }
                return; 
            }
        }
        
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"年命摘要視圖"]) {
            EchoLog(@"已拦截 '年命摘要視圖'，开始提取文本。");
            
            NSMutableString *capturedText = [NSMutableString string];
            if (viewControllerToPresent.title) { [capturedText appendFormat:@"%@\n", viewControllerToPresent.title]; }
            
            NSMutableArray *textualViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UIView class], viewControllerToPresent.view, textualViews);
            [textualViews filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, id bind){ return [obj respondsToSelector:@selector(text)]; }]];
            [textualViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
            
            for (UIView *view in textualViews) {
                NSString *text = [view valueForKey:@"text"];
                if (text && text.length > 0 && ![capturedText containsString:text]) { [capturedText appendFormat:@"%@\n", text]; }
            }
            
            [g_capturedNianMingArray addObject:capturedText]; // 添加到结果数组中
            EchoLog(@"本次提取完成，已存入结果数组 (当前数量: %lu)", (unsigned long)g_capturedNianMingArray.count);
            
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performLoopingNianMingTest {
    EchoLog(@"--- 开始循环提取所有年命信息测试 ---");
    
    g_isTestingNianMing = YES;
    g_capturedNianMingArray = [NSMutableArray array]; // 初始化结果数组
    
    // 查找目标 CollectionView
    NSMutableArray *collectionViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], self.view, collectionViews);
    UICollectionView *targetCollectionView = nil;
    Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    for (UICollectionView *cv in collectionViews) {
        if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) {
            targetCollectionView = cv;
            break;
        }
    }
    
    if (!targetCollectionView) {
        EchoLog(@"测试中止: 未找到目标 CollectionView。");
        g_isTestingNianMing = NO;
        return;
    }
    
    // 获取所有行年单元并排序
    NSMutableArray *allUnitCells = [NSMutableArray array];
    for (UIView *cell in targetCollectionView.visibleCells) {
        if([cell isKindOfClass:unitClass]){
            [allUnitCells addObject:cell];
        }
    }
    [allUnitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
        return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)];
    }];

    EchoLog(@"找到 %lu 个行年单元，将按顺序处理。", (unsigned long)allUnitCells.count);

    // 使用 dispatch_queue 实现带延时的串行循环
    dispatch_queue_t serialQueue = dispatch_queue_create("com.echoai.nianming.queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(serialQueue, ^{
        for (UIView *cell in allUnitCells) {
            @autoreleasepool {
                // 在主线程执行UI操作
                dispatch_sync(dispatch_get_main_queue(), ^{
                    id delegate = targetCollectionView.delegate;
                    NSIndexPath *indexPath = [targetCollectionView indexPathForCell:(UICollectionViewCell *)cell];
                    if (delegate && indexPath) {
                         EchoLog(@"正在处理 IndexPath: section=%ld, item=%ld", (long)indexPath.section, (long)indexPath.item);
                        SEL selector = @selector(collectionView:didSelectItemAtIndexPath:);
                        if ([delegate respondsToSelector:selector]) {
                            #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) \
                                _Pragma("clang diagnostic push") \
                                _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
                                code; \
                                _Pragma("clang diagnostic pop")
                            SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([delegate performSelector:selector withObject:targetCollectionView withObject:indexPath];);
                        }
                    }
                });
                // 等待，给抓取流程留出时间
                [NSThread sleepForTimeInterval:0.5];
            }
        }
        
        // 所有循环结束后，在主线程显示最终结果
        dispatch_async(dispatch_get_main_queue(), ^{
            EchoLog(@"所有年命提取完毕，准备显示最终结果。");
            
            NSString *resultTitle;
            NSString *resultMessage;
            
            if (g_capturedNianMingArray.count > 0) {
                resultTitle = [NSString stringWithFormat:@"提取成功 (%lu个)！", (unsigned long)g_capturedNianMingArray.count];
                resultMessage = [g_capturedNianMingArray componentsJoinedByString:@"\n----------\n"];
            } else {
                resultTitle = @"提取失败";
                resultMessage = @"未能抓取到任何年命摘要。请检查日志。";
            }
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:resultTitle message:resultMessage preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            
            g_isTestingNianMing = NO;
        });
    });
}

%end
