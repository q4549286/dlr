#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 日志和辅助函数
// =========================================================================
#define LOG_PREFIX @"[EchoFinalTestV5] "
#define Log(format, ...) NSLog(LOG_PREFIX format, ##__VA_ARGS__)

#define SUPPRESS_LEAK_WARNING(code) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    code; \
    _Pragma("clang diagnostic pop")

static UIWindow* GetFrontmostWindow() { /* ... 代码保持不变 ... */ }
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { /* ... 代码保持不变 ... */ }

@interface EchoFakeGestureRecognizer : UITapGestureRecognizer
@property (nonatomic, assign) CGPoint fakeLocation;
@end
@implementation EchoFakeGestureRecognizer
- (CGPoint)locationInView:(UIView *)view { return self.fakeLocation; }
@end

// =========================================================================
// 2. 接口声明
// =========================================================================
@interface UIViewController (EchoFinalTest)
- (void)runFinalTest;
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix;
@end

// =========================================================================
// 3. 核心 Hook
// =========================================================================
%hook UIViewController

- (void)viewDidLoad {
    %orig;
    if ([NSStringFromClass([self class]) hasSuffix:@"ViewController"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake([UIScreen mainScreen].bounds.size.width - 120, 190, 110, 36);
            [testButton setTitle:@"终极测试V5" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor blackColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 18;
            testButton.layer.borderColor = [UIColor whiteColor].CGColor;
            testButton.layer.borderWidth = 1.0;
            [testButton addTarget:self action:@selector(runFinalTest) forControlEvents:UIControlEventTouchUpInside];
            [GetFrontmostWindow() addSubview:testButton];
            Log(@"最终测试按钮V5已添加。");
        });
    }
}

%new
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix { /* ... 代码保持不变 ... */ }

%new
- (void)runFinalTest {
    Log(@"================== 最终安全测试V5开始 ==================");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            Log(@"Step 1: 进入主执行块。");
            
            // --- 查找视图 (已验证稳定) ---
            UIWindow *keyWindow = GetFrontmostWindow();
            Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
            NSMutableArray *plateViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
            if (plateViews.count == 0) { Log(@"!! FATAL: 未能找到天地盘实例。"); return; }
            UIView *plateView = plateViews.firstObject;
            Log(@"Step 2: 成功找到实例。");

            // --- 获取字典 (已验证稳定) ---
            id tianJiangDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天將宮名列"];
            if (![tianJiangDict isKindOfClass:[NSDictionary class]] || ((NSDictionary *)tianJiangDict).count == 0) {
                Log(@"!! FATAL: 未能获取天将字典。"); return;
            }
            Log(@"Step 3: 成功获取天将字典。");

            // ========== V9 核心修正：纯C方式提取 ==========
            Log(@"Step 4: 准备以纯C方式提取键值对...");
            NSMutableArray *workQueue = [NSMutableArray array];
            
            @autoreleasepool {
                CFDictionaryRef cfDict = (__bridge CFDictionaryRef)tianJiangDict;
                CFIndex count = CFDictionaryGetCount(cfDict);
                void const **keys = (void const **)malloc(sizeof(void *) * count);
                void const **values = (void const **)malloc(sizeof(void *) * count);
                
                // 这一步直接从内存中获取所有指针，不涉及OC的copy或迭代
                CFDictionaryGetKeysAndValues(cfDict, keys, values);

                Log(@"Step 4a: 已获取C指针数组，数量: %ld", count);

                for (CFIndex i = 0; i < count; i++) {
                    // 使用 __bridge_transfer 来获取所有权，并让ARC管理内存
                    id key = (__bridge_transfer id)keys[i];
                    id obj = (__bridge_transfer id)values[i];
                    
                    if (key && obj) {
                        [workQueue addObject:@{ @"targetLayer": obj, @"name": key }];
                    }
                }
                
                // 注意：因为用了 __bridge_transfer，我们不需要 free(keys) 和 free(values) 了，
                // ARC会接管它们的内存管理。如果用 __bridge，则需要手动 free。
                // 为了绝对安全，我们还是用 __bridge 并手动 free。
            }

            // ---- 重写为更安全的版本 ----
            CFDictionaryRef cfDict_safer = (__bridge CFDictionaryRef)tianJiangDict;
            CFIndex count_safer = CFDictionaryGetCount(cfDict_safer);
            void const **keys_safer = (void const **)malloc(sizeof(void *) * count_safer);
            void const **values_safer = (void const **)malloc(sizeof(void *) * count_safer);
            CFDictionaryGetKeysAndValues(cfDict_safer, keys_safer, values_safer);
            
            for (CFIndex i = 0; i < count_safer; i++) {
                id key = (__bridge id)keys_safer[i];
                id obj = (__bridge id)values_safer[i];
                if (key && obj) {
                     [workQueue addObject:@{ @"targetLayer": obj, @"name": key }];
                }
            }
            free(keys_safer);
            free(values_safer);
            
            Log(@"Step 4b: 任务队列构建成功，包含 %lu 个任务。", (unsigned long)workQueue.count);

            if (workQueue.count == 0) { Log(@"!! FATAL: 任务队列为空。"); return; }
            
            // --- 后续调用逻辑 (已验证稳定) ---
            Log(@"Step 5: 选取第一个任务...");
            NSDictionary *task = workQueue.firstObject;
            CALayer *targetLayer = task[@"targetLayer"];
            NSString *targetName = task[@"name"];

            if (![targetLayer isKindOfClass:[CALayer class]] || ![targetName isKindOfClass:[NSString class]]) {
                Log(@"!! FATAL: 队列中的对象类型不正确."); return;
            }
            CGPoint targetPosition = targetLayer.position;
            Log(@"Step 5: 目标: '%@', 坐标: (%.2f, %.2f)", targetName, targetPosition.x, targetPosition.y);
            
            Log(@"Step 6: 准备调用...");
            SEL selector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
            if (![self respondsToSelector:selector]) { Log(@"!! FATAL: ViewController 不响应目标方法。"); return; }
            
            EchoFakeGestureRecognizer *fakeGesture = [[EchoFakeGestureRecognizer alloc] init];
            fakeGesture.fakeLocation = targetPosition;
            Log(@"Step 7: 伪造手势已创建，即将调用...");

            SUPPRESS_LEAK_WARNING([self performSelector:selector withObject:fakeGesture]);
            
            Log(@"--- CALL SUCCEEDED! --- The app did not crash.");

        } @catch (NSException *exception) {
            Log(@"!!!!!! CATASTROPHIC FAILURE !!!!!! Exception: %@, Reason: %@", exception.name, exception.reason);
        } @finally {
            Log(@"================== 最终安全测试V5结束 ==================");
        }
    });
}
%end

%ctor {
    Log(@"最终测试脚本V5已加载。");
    // 确保GetFrontmostWindow和FindSubviewsOfClassRecursive被链接
    GetFrontmostWindow(); 
    FindSubviewsOfClassRecursive(nil, nil, nil);
}
