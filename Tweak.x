#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 日志和辅助函数
// =========================================================================
#define LOG_PREFIX @"[EchoFinalTestV3.1] " // 更新日志前缀
#define Log(format, ...) NSLog(LOG_PREFIX format, ##__VA_ARGS__)

#define SUPPRESS_LEAK_WARNING(code) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    code; \
    _Pragma("clang diagnostic pop")

// ========== 修正点 1: 恢复函数体 ==========
static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) { if (window.isKeyWindow) { frontmostWindow = window; break; } }
                if (frontmostWindow) break;
            }
        }
    }
    if (!frontmostWindow) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        frontmostWindow = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
    }
    return frontmostWindow;
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

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
            testButton.frame = CGRectMake([UIScreen mainScreen].bounds.size.width - 120, 90, 110, 36);
            [testButton setTitle:@"终极测试V3.1" forState:UIControlStateNormal];
            // ========== 修正点 2: 移除多余的连字符 ==========
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemBlueColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 18;
            [testButton addTarget:self action:@selector(runFinalTest) forControlEvents:UIControlEventTouchUpInside];
            [GetFrontmostWindow() addSubview:testButton];
            Log(@"最终测试按钮V3.1已添加。");
        });
    }
}

%new
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix {
    if (!object || !ivarNameSuffix) return nil;
    id value = nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (ivars) {
        for (unsigned int i = 0; i < ivarCount; i++) {
            const char *name = ivar_getName(ivars[i]);
            if (name && [[NSString stringWithUTF8String:name] hasSuffix:ivarNameSuffix]) {
                value = object_getIvar(object, ivars[i]);
                break;
            }
        }
        free(ivars);
    }
    return value;
}

%new
- (void)runFinalTest {
    Log(@"================== 最终安全测试V3.1开始 ==================");
    
    @try {
        if (g_isTesting) { Log(@"测试已在进行中..."); return; }
        g_isTesting = YES;
        Log(@"Step 1: 状态旗标设置成功。");

        Log(@"Step 2: 开始定位目标类...");
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盘视图类");
        if (!plateViewClass) {
            Log(@"!! FATAL: NSClassFromString未能找到 '六壬大占.天地盘视图类'。测试终止。");
            g_isTesting = NO; return;
        }
        Log(@"Step 2: 成功获取目标类: %@", plateViewClass);

        Log(@"Step 3: 开始在视图层级中搜索实例...");
        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);
        if (plateViews.count == 0) {
            Log(@"!! FATAL: 未能在 self.view 中找到目标实例。测试终止。");
            g_isTesting = NO; return;
        }
        UIView *plateView = plateViews.firstObject;
        Log(@"Step 3: 成功找到目标实例: %@", plateView);

        Log(@"Step 4: 开始获取'天将宫名列'实例变量...");
        id tianJiangDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天將宮名列"];
        if (![tianJiangDict isKindOfClass:[NSDictionary class]] || ((NSDictionary *)tianJiangDict).count == 0) {
            Log(@"!! FATAL: 未能获取天将字典，或字典为空。测试终止。");
            g_isTesting = NO; return;
        }
        Log(@"Step 4: 成功获取天将字典，包含 %lu 个对象。", (unsigned long)((NSDictionary *)tianJiangDict).count);
        
        Log(@"Step 5: 准备构建任务队列 (硬核安全模式)...");
        NSDictionary *safeDictCopy = [(NSDictionary *)tianJiangDict copy];
        NSMutableArray *workQueue = [NSMutableArray array];
        
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
                
                if (key && obj && [key isKindOfClass:[NSString class]] && [obj isKindOfClass:[CALayer class]]) {
                    [workQueue addObject:@{ @"targetLayer": (CALayer *)obj, @"name": (NSString *)key }];
                } else {
                    Log(@"Step 5b (Warning): 在索引 %ld 处发现无效键值对. Key class: %@, Obj class: %@", i, [key class], [obj class]);
                }
            } @catch (NSException *exception) {
                Log(@"Step 5c (CRITICAL): 在遍历索引 %ld 时捕获到异常: %@", i, exception);
            }
        }
        
        free(keys);
        free(values);

        if (workQueue.count == 0) {
            Log(@"!! FATAL: 任务队列构建失败。测试终止。");
             g_isTesting = NO; return;
        }
        Log(@"Step 5d: 任务队列构建成功，包含 %lu 个任务。", (unsigned long)workQueue.count);

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
        Log(@"================== 最终安全测试V3.1结束 ==================");
    }
}
%end

%ctor {
    Log(@"最终测试脚本V3.1已加载。");
}
