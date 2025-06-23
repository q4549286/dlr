#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-v8] " format), ##__VA_ARGS__)

static BOOL g_isTestingNianMing = NO;
static NSString *g_currentItemToExtract = nil; // "年命摘要" 或 "格局方法"
static NSMutableArray *g_capturedZhaiYaoArray = nil; 
static NSMutableArray *g_capturedGeJuArray = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

@interface UIViewController (DelegateTestAddon)
- (void)performStepByStepExtractTest;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            NSInteger testButtonTag = 999007;
            if ([keyWindow viewWithTag:testButtonTag]) return;
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 200, 45, 90, 36);
            [testButton setTitle:@"测试分步提取" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            testButton.backgroundColor = [UIColor blackColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            testButton.tag = testButtonTag;
            
            [testButton addTarget:self action:@selector(performStepByStepExtractTest) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            EchoLog(@"分步提取测试按钮已添加。");
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingNianMing && g_currentItemToExtract) {
        // 步骤2: 拦截操作表，只点击当前需要的一项
        if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertController *alert = (UIAlertController *)viewControllerToPresent;
            UIAlertAction *targetAction = nil;
            for (UIAlertAction *action in alert.actions) {
                if ([action.title isEqualToString:g_currentItemToExtract]) { // 只找当前目标的action
                    targetAction = action;
                    break;
                }
            }
            if (targetAction) {
                EchoLog(@"已拦截操作表，将自动点击 '%@'...", g_currentItemToExtract);
                id handler = [targetAction valueForKey:@"handler"];
                if (handler) { ((void (^)(UIAlertAction *))handler)(targetAction); }
                return;
            }
        }
        
        // 步骤3: 拦截内容页
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        NSString *vcTitle = viewControllerToPresent.title ?: @"";
        
        NSString* (^extractTextFromVC)(void) = ^NSString* { /* ... 提取文本的实现 ... */
            NSMutableString *t = [NSMutableString string];
            if(vcTitle){ [t appendFormat:@"%@\n", vcTitle]; }
            NSMutableArray *v = [NSMutableArray array]; FindSubviewsOfClassRecursive([UIView class],viewControllerToPresent.view,v);
            [v filterUsingPredicate:[NSPredicate predicateWithBlock:^(id o,id b){return[o respondsToSelector:@selector(text)];}]];
            [v sortUsingComparator:^NSComparisonResult(UIView*v1,UIView*v2){return[@(v1.frame.origin.y)compare:@(v2.frame.origin.y)];}];
            for(UIView*view in v){NSString*text=[view valueForKey:@"text"];if(text&&text.length>0&&![t containsString:text]){[t appendFormat:@"%@\n",text];}}
            return[t copy];
        };

        if ([g_currentItemToExtract isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) {
            [g_capturedZhaiYaoArray addObject:extractTextFromVC()];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;
        } else if ([g_currentItemToExtract isEqualToString:@"格局方法"] && [vcTitle containsString:@"格局方法"]) {
            [g_capturedGeJuArray addObject:extractTextFromVC()];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performStepByStepExtractTest {
    EchoLog(@"--- 开始(分步)提取所有年命信息测试 ---");
    
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
    EchoLog(@"找到 %lu 个行年单元。", (unsigned long)allUnitCells.count);

    // 封装单项提取的循环逻辑
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
            if (completionBlock) {
                dispatch_async(dispatch_get_main_queue(), completionBlock);
            }
        });
    };
    
    // 步骤1: 提取所有人的 "年命摘要"
    extractItem(@"年命摘要", ^{
        // 步骤2: 年命摘要提取完后，接着提取所有人的 "格局方法"
        extractItem(@"格局方法", ^{
            // 步骤3: 全部完成后，显示结果
            EchoLog(@"所有提取任务完成，显示最终结果。");
            
            NSMutableString *finalResultString = [NSMutableString string];
            for (NSUInteger i = 0; i < allUnitCells.count; i++) {
                NSString *zhaiYao = (i < g_capturedZhaiYaoArray.count) ? g_capturedZhaiYaoArray[i] : @"[年命摘要未提取到]\n";
                NSString *geJu = (i < g_capturedGeJuArray.count) ? g_capturedGeJuArray[i] : @"[格局方法未提取到]\n";
                
                [finalResultString appendString:zhaiYao];
                [finalResultString appendString:@"\n--- 格局方法 ---\n"];
                [finalResultString appendString:geJu];
                [finalResultString appendString:@"\n====================\n"];
            }
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"分步提取成功 (%lu人)", (unsigned long)allUnitCells.count] message:finalResultString preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            
            g_isTestingNianMing = NO;
        });
    });
}
%end
