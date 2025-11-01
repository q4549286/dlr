#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 日志和辅助函数
// =========================================================================
#define LOG_PREFIX @"[EchoFinalTestV3] " // 更新日志前缀
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
// 2. 接口声明和全局变量
// =========================================================================
static BOOL g_isTesting = NO;

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
            testButton.frame = CGRectMake([UIScreen mainScreen].bounds.size.width - 120, 90, 110, 36); // 往下移动一点，避免重叠
            [testButton setTitle:@"终极测试V3" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFont-OfSize:16];
            testButton.backgroundColor = [UIColor systemBlueColor]; // 改成蓝色
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 18;
            [testButton addTarget:self action:@selector(runFinalTest) forControlEvents:UIControlEventTouchUpInside];
            [GetFrontmostWindow() addSubview:testButton];
            Log(@"最终测试按钮V3已添加。");
        });
    }
}

%new
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix { /* ... 代码保持不变 ... */ }

%new
- (void)runFinalTest {
    Log(@"================== 最终安全测试V3开始 ==================");
    
    @try {
        if (g_isTesting) { Log(@"测试已在进行中..."); return; }
        g_isTesting = YES;
        Log(@"Step 1-4: (Skipping logs for brevity, assuming they pass)...");

        // 直接跳到关键步骤
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);
        UIView *plateView = plateViews.firstObject;
        id tianJiangDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天將宮名列"];
        
        Log(@"Step 5: 准备构建任务队列 (硬核安全模式)...");
        NSDictionary *safeDictCopy = [(NSDictionary *)tianJiangDict copy];
        NSMutableArray *workQueue = [NSMutableArray array];
        
        // ====================== V7 核心修正 ======================
        // 使用最底层的 CoreFoundation 函数来安全地遍历
        
        CFDictionaryRef cfDict = (__bridge CFDictionaryRef)safeDictCopy;
        CFIndex count = CFDictionaryGetCount(cfDict);
        void const **keys = (void const **)malloc(sizeof(void *) * count);
        void const **values = (void const **)malloc(sizeof(void *) * count);
        CFDictionaryGetKeysAndValues(cfDict, keys, values);

        Log(@"Step 5a: 已获取 C-level 键值对，总数: %ld", count);

        for (CFIndex i = 0; i < count; i++) {
            @try {
                id key = (__bridge id)keys[i];
                id obj = (__bridge id)values[i];
                
                // 进行最严格的检查
                if (key && obj && [key isKindOfClass:[NSString class]] && [obj isKindOfClass:[CALayer class]]) {
                    [workQueue addObject:@{ @"targetLayer": (CALayer *)obj, @"name": (NSString *)key }];
                } else {
                    Log(@"Step 5b (Warning): 在索引 %ld 处发现无效键值对. Key class: %@, Obj class: %@", i, [key class], [obj class]);
                }
            } @catch (NSException *exception) {
                Log(@"Step 5c (CRITICAL): 在遍历索引 %ld 时捕获到异常: %@", i, exception);
                // 即使有异常也继续下一个循环
            }
        }
        
        free(keys);
        free(values);
        // =========================================================

        if (workQueue.count == 0) {
            Log(@"!! FATAL: 任务队列构建失败。测试终止。");
             g_isTesting = NO; return;
        }
        Log(@"Step 5d: 任务队列构建成功，包含 %lu 个任务。", (unsigned long)workQueue.count);

        // ... 后续的 Step 6, 7, 8 和调用逻辑保持不变 ...
        Log(@"Step 6: 选取第一个任务进行单次调用测试...");
        NSDictionary *task = workQueue.firstObject;
        CALayer *targetLayer = task[@"targetLayer"];
        NSString *targetName = task[@"name"];
        CGPoint targetPosition = targetLayer.position;
        Log(@"Step 6: 目标: '%@', 坐标: (%.2f, %.2f)", targetName, targetPosition.x, targetPosition.y);
        
        Log(@"Step 7: 准备调用方法 '顯示天地盤觸摸WithSender:'...");
        SEL selector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
        if (![self respondsToSelector:selector]) {
            Log(@"!! FATAL: ViewController 不响应目标方法。测试终止。");
            g_isTesting = NO; return;
        }
        Log(@"Step 7: 确认方法存在。准备创建伪造手势...");

        EchoFakeGestureRecognizer *fakeGesture = [[EchoFakeGestureRecognizer alloc] init];
        fakeGesture.fakeLocation = targetPosition;
        Log(@"Step 8: 伪造手势已创建。即将执行 performSelector...");

        Log(@"--- PRE-FLIGHT CHECK COMPLETE. INITIATING CALL... ---");
        SUPPRESS_LEAK_WARNING([self performSelector:selector withObject:fakeGesture]);
        Log(@"--- CALL SUCCEEDED! --- The app did not crash on performSelector.");

    } @catch (NSException *exception) {
        Log(@"!!!!!! CATASTROPHIC FAILURE !!!!!! An exception was caught: %@, Reason: %@", exception.name, exception.reason);
    } @finally {
        g_isTesting = NO;
        Log(@"================== 最终安全测试V3结束 ==================");
    }
}
%end

%ctor { Log(@"最终测试脚本V3已加载。"); }

