#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 日志和辅助函数
// =========================================================================
#define LOG_PREFIX @"[EchoFinalTestV4.1] "
#define Log(format, ...) NSLog(LOG_PREFIX format, ##__VA_ARGS__)

// ========== 修正点: 重新添加宏定义 ==========
#define SUPPRESS_LEAK_WARNING(code) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    code; \
    _Pragma("clang diagnostic pop")
// ===========================================

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
            testButton.frame = CGRectMake([UIScreen mainScreen].bounds.size.width - 120, 140, 110, 36);
            [testButton setTitle:@"终极测试V4.1" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor purpleColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 18;
            [testButton addTarget:self action:@selector(runFinalTest) forControlEvents:UIControlEventTouchUpInside];
            [GetFrontmostWindow() addSubview:testButton];
            Log(@"最终测试按钮V4.1已添加。");
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
    Log(@"================== 最终安全测试V4.1开始 ==================");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            Log(@"Step 1: 进入主执行块。");

            Log(@"Step 2: 开始全局搜索'天地盘视图类'...");
            UIWindow *keyWindow = GetFrontmostWindow();
            if (!keyWindow) {
                Log(@"!! FATAL: 无法获取 Key Window。测试终止。"); return;
            }
            Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
            if (!plateViewClass) {
                Log(@"!! FATAL: NSClassFromString未能找到 '六壬大占.天地盤視圖類'。测试终止。"); return;
            }

            NSMutableArray *plateViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
            if (plateViews.count == 0) {
                Log(@"!! FATAL: 未能在 Key Window 中找到目标实例。测试终止。"); return;
            }
            UIView *plateView = plateViews.firstObject;
            Log(@"Step 2: 成功在 Key Window 中找到实例: %@", plateView);

            Log(@"Step 3: 开始获取'天将宫名列'...");
            id tianJiangDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天將宮名列"];
            if (![tianJiangDict isKindOfClass:[NSDictionary class]] || ((NSDictionary *)tianJiangDict).count == 0) {
                Log(@"!! FATAL: 未能获取天将字典，或字典为空。测试终止。"); return;
            }
            Log(@"Step 3: 成功获取天将字典。");

            Log(@"Step 4: 进入线程和内存安全区...");
            __block NSMutableArray *workQueue = [NSMutableArray array];
            
            @autoreleasepool {
                NSDictionary *strongDictCopy = [tianJiangDict copy];
                [strongDictCopy enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    if (key && obj) {
                        [workQueue addObject:@{ @"targetLayer": obj, @"name": key }];
                    }
                }];
            }
            Log(@"Step 4: 任务队列构建完成，包含 %lu 个任务。", (unsigned long)workQueue.count);
            
            if (workQueue.count == 0) {
                Log(@"!! FATAL: 任务队列为空。测试终止。"); return;
            }
            
            Log(@"Step 5: 选取第一个任务进行测试...");
            NSDictionary *task = workQueue.firstObject;
            CALayer *targetLayer = task[@"targetLayer"];
            NSString *targetName = task[@"name"];
            
            if (![targetLayer isKindOfClass:[CALayer class]] || ![targetName isKindOfClass:[NSString class]]) {
                Log(@"!! FATAL: 队列中的对象类型不正确. Layer: %@, Name: %@", [targetLayer class], [targetName class]); return;
            }

            CGPoint targetPosition = targetLayer.position;
            Log(@"Step 5: 目标: '%@', 坐标: (%.2f, %.2f)", targetName, targetPosition.x, targetPosition.y);
            
            Log(@"Step 6: 准备调用...");
            SEL selector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
            if (![self respondsToSelector:selector]) {
                Log(@"!! FATAL: ViewController 不响应目标方法。"); return;
            }
            
            EchoFakeGestureRecognizer *fakeGesture = [[EchoFakeGestureRecognizer alloc] init];
            fakeGesture.fakeLocation = targetPosition;
            Log(@"Step 7: 伪造手势已创建，即将调用...");

            SUPPRESS_LEAK_WARNING([self performSelector:selector withObject:fakeGesture]);
            
            Log(@"--- CALL SUCCEEDED! --- The app did not crash.");

        } @catch (NSException *exception) {
            Log(@"!!!!!! CATASTROPHIC FAILURE !!!!!! Exception: %@, Reason: %@", exception.name, exception.reason);
        } @finally {
            Log(@"================== 最终安全测试V4.1结束 ==================");
        }
    });
}
%end

%ctor {
    Log(@"最终测试脚本V4.1已加载。");
}
