#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 日志和辅助函数
// =========================================================================

#define LOG_PREFIX @"[EchoSafeClick] "
#define Log(format, ...) NSLog(LOG_PREFIX format, ##__VA_ARGS__)

#define SUPPRESS_LEAK_WARNING(code) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    code; \
    _Pragma("clang diagnostic pop")

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

// 伪造手势类
@interface EchoFakeGestureRecognizer : UITapGestureRecognizer
@property (nonatomic, assign) CGPoint fakeLocation;
@end
@implementation EchoFakeGestureRecognizer
- (CGPoint)locationInView:(UIView *)view { return self.fakeLocation; }
@end


// =========================================================================
// 2. 接口声明
// =========================================================================

@interface UIViewController (EchoSafeClick)
- (void)runSafeClickTest;
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix;
- (NSString *)GetStringFromLayer:(id)layer;
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
            testButton.frame = CGRectMake([UIScreen mainScreen].bounds.size.width - 150, 45, 140, 36);
            [testButton setTitle:@"天地盘安全点击" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemBlueColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 18;
            [testButton addTarget:self action:@selector(runSafeClickTest) forControlEvents:UIControlEventTouchUpInside];
            [GetFrontmostWindow() addSubview:testButton];
            Log(@"安全点击测试按钮已添加。");
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
- (NSString *)GetStringFromLayer:(id)layer {
    if (layer && [layer respondsToSelector:@selector(string)]) {
        id stringValue = [layer valueForKey:@"string"];
        if ([stringValue isKindOfClass:[NSString class]]) return stringValue;
        if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string;
    }
    return @"?";
}

%new
- (void)runSafeClickTest {
    Log(@">>>>> 开始执行天地盘安全点击测试 <<<<<");
    
    @try {
        // 1. 查找天地盘视图
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盘视图类");
        if (!plateViewClass) {
            Log(@"!! 失败: 找不到 '六壬大占.天地盘视图类'");
            return;
        }
        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);
        if (plateViews.count == 0) {
            Log(@"!! 失败: 找不到天地盘视图实例");
            return;
        }
        UIView *plateView = plateViews.firstObject;
        Log(@"Step 1: 成功找到天地盘视图: %@", plateView);

        // 2. 安全地获取天将图层字典
        id tianJiangDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天將宮名列"];
        if (!tianJiangDict) {
            Log(@"!! 失败: 无法获取'天將宮名列'变量");
            return;
        }
        // 我们现在知道它不是NSDictionary，但它响应 allValues
        if (![tianJiangDict respondsToSelector:@selector(allValues)]) {
            Log(@"!! 失败: '天將宮名列'对象不响应 allValues");
            return;
        }
        NSArray *tianJiangLayers = [tianJiangDict allValues];
        Log(@"Step 2: 成功获取天将 CALayer 列表，数量: %lu", (unsigned long)tianJiangLayers.count);

        // 3. 选取第一个天将 CALayer 作为测试目标
        CALayer *targetLayer = nil;
        for (id obj in tianJiangLayers) {
            if ([obj isKindOfClass:[CALayer class]]) {
                targetLayer = (CALayer *)obj;
                break;
            }
        }
        if (!targetLayer) {
            Log(@"!! 失败: 在列表中未找到任何 CALayer 对象");
            return;
        }
        CGPoint targetPosition = targetLayer.position;
        Log(@"Step 3: 成功选取目标 CALayer: %@, 文本: '%@', 坐标: (%.2f, %.2f)", targetLayer, [self GetStringFromLayer:targetLayer], targetPosition.x, targetPosition.y);
        
        // 4. 检查目标方法
        SEL selector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
        if (![self respondsToSelector:selector]) {
            Log(@"!! 失败: ViewController 不响应目标方法");
            return;
        }
        Log(@"Step 4: 确认目标方法存在");

        // 5. 创建伪造手势并调用
        Log(@"Step 5: 创建并配置伪造手势...");
        EchoFakeGestureRecognizer *fakeGesture = [[EchoFakeGestureRecognizer alloc] init];
        fakeGesture.fakeLocation = targetPosition;

        Log(@"--- 即将使用伪造手势调用目标方法... ---");
        SUPPRESS_LEAK_WARNING([self performSelector:selector withObject:fakeGesture]);
        Log(@"--- 调用完成！如果App没有崩溃，并且弹出了窗口，则测试成功！ ---");

    } @catch (NSException *exception) {
        Log(@"!!!!!! 测试过程中捕获到异常 !!!!!!: %@, 原因: %@", exception.name, exception.reason);
    } @finally {
        Log(@">>>>> 安全点击测试结束 <<<<<");
    }
}
%end

%ctor {
    Log(@"安全点击测试脚本已加载。");
}
