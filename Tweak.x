#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 日志和辅助函数
// =========================================================================

#define LOG_PREFIX @"[EchoScout] "
#define Log(format, ...) NSLog(LOG_PREFIX format, ##__VA_ARGS__)

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

// =========================================================================
// 2. 接口声明
// =========================================================================

@interface UIViewController (EchoScout)
- (void)runScoutMission;
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix;
@end

// =========================================================================
// 3. 核心 Hook
// =========================================================================

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    // 使用 hasSuffix 确保我们只匹配主 ViewController，而不是其他也叫 ViewController 的类
    if ([NSStringFromClass([self class]) hasSuffix:@"ViewController"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIButton *scoutButton = [UIButton buttonWithType:UIButtonTypeSystem];
            scoutButton.frame = CGRectMake([UIScreen mainScreen].bounds.size.width - 120, 45, 110, 36);
            [scoutButton setTitle:@"信息侦察" forState:UIControlStateNormal];
            scoutButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            scoutButton.backgroundColor = [UIColor systemGreenColor];
            [scoutButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            scoutButton.layer.cornerRadius = 18;
            [scoutButton addTarget:self action:@selector(runScoutMission) forControlEvents:UIControlEventTouchUpInside];
            [GetFrontmostWindow() addSubview:scoutButton];
            Log(@"侦察兵已就位。");
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
                // 安全地获取值
                // 使用 object_getIvar 可能会因为类型不匹配而出问题，但对于字典通常是安全的
                @try {
                    value = object_getIvar(object, ivars[i]);
                } @catch (NSException *e) {
                    Log(@"!! 安全警告: 获取 ivar '%s' 时发生异常: %@", name, e);
                    value = nil;
                }
                break;
            }
        }
        free(ivars);
    }
    return value;
}

%new
- (void)runScoutMission {
    Log(@">>>>> 开始执行信息侦察任务 <<<<<");
    
    // --- 侦察点 1: 确认 ViewController 自身 ---
    Log(@"侦察点 1: self (ViewController) 信息");
    Log(@"  - self 的类名: %@", NSStringFromClass([self class]));
    Log(@"  - self 的描述: %@", self);

    // --- 侦察点 2: 查找天地盘视图 ---
    Log(@"侦察点 2: 查找 '六壬大占.天地盤視圖類'...");
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    if (!plateViewClass) {
        Log(@"  - 结果: 失败! NSClassFromString 无法找到该类。");
        // 尝试备用名称
        plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
         if (!plateViewClass) {
             Log(@"  - 备用结果: 失败! NSClassFromString 也无法找到繁体名称。");
         } else {
             Log(@"  - 备用结果: 成功! 通过繁体名称找到了类: %@", plateViewClass);
         }
    } else {
        Log(@"  - 结果: 成功! 找到了类: %@", plateViewClass);
    }

    if (!plateViewClass) {
        Log(@"!!!!! 任务失败: 无法定位天地盤視圖類，后续侦察无法进行。");
        Log(@">>>>> 侦察任务结束 <<<<<");
        return;
    }
    
    NSMutableArray *plateViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);
    if (plateViews.count == 0) {
        Log(@"  - 搜索实例结果: 失败! 在 self.view 中未找到该类的实例。");
        Log(@"!!!!! 任务失败: 无法定位天地盘视图实例，后续侦察无法进行。");
        Log(@">>>>> 侦察任务结束 <<<<<");
        return;
    }
    UIView *plateView = plateViews.firstObject;
    Log(@"  - 搜索实例结果: 成功! 找到实例: %@", plateView);

    // --- 侦察点 3: 检查天地盘视图的实例变量 ---
    Log(@"侦察点 3: 检查天地盘实例变量...");
    id tianJiangDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天將宮名列"];
    if (tianJiangDict) {
        Log(@"  - '天將宮名列': 找到了!");
        Log(@"    - 类型: %@", NSStringFromClass([tianJiangDict class]));
        if ([tianJiangDict isKindOfClass:[NSDictionary class]]) {
            Log(@"    - 条目数量: %lu", (unsigned long)((NSDictionary *)tianJiangDict).count);
            // 安全地打印前几个键值对
            __block int count = 0;
            [(NSDictionary *)tianJiangDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if (count < 3) {
                    Log(@"      - Key: %@ (类型: %@), Value: %@ (类型: %@)", key, NSStringFromClass([key class]), obj, NSStringFromClass([obj class]));
                }
                count++;
                if (count >= 3) *stop = YES;
            }];
        }
    } else {
        Log(@"  - '天將宮名列': 未找到!");
    }

    id tianShenDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天神宮名列"];
     if (tianShenDict) {
        Log(@"  - '天神宮名列': 找到了!");
        Log(@"    - 类型: %@", NSStringFromClass([tianShenDict class]));
        if ([tianShenDict isKindOfClass:[NSDictionary class]]) {
            Log(@"    - 条目数量: %lu", (unsigned long)((NSDictionary *)tianShenDict).count);
        }
    } else {
        Log(@"  - '天神宮名列': 未找到!");
    }

    // --- 侦察点 4: 检查 ViewController 的目标方法 ---
    Log(@"侦察点 4: 检查目标方法 '顯示天地盤觸摸WithSender:'...");
    SEL selector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
    if ([self respondsToSelector:selector]) {
        Log(@"  - 结果: 成功! self (ViewController) 确实响应此方法。");
        Method method = class_getInstanceMethod([self class], selector);
        if (method) {
            const char* typeEncoding = method_getTypeEncoding(method);
            Log(@"    - 方法签名编码 (Type Encoding): %s", typeEncoding);
        }
    } else {
        Log(@"  - 结果: 失败! self (ViewController) 不响应此方法。");
    }
    
    Log(@">>>>> 信息侦察任务完成 <<<<<");
}

%end

%ctor {
    Log(@"侦察兵脚本已加载。");
}

