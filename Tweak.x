#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 极简独立测试版 (V14 - 方法调用版)
// 目标: 放弃直接读取内存，改为调用属性的getter方法
// =========================================================================

#define EchoLog(format, ...) NSLog((@"[EchoAI-Debug] " format), ##__VA_ARGS__)

// 辅助函数: 查找子视图
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// 新辅助函数: 动态查找并调用方法
static id InvokeMethodBySuffix(id object, NSString *methodNameSuffix) {
    unsigned int methodCount;
    Method *methods = class_copyMethodList([object class], &methodCount);
    if (!methods) return nil;

    SEL targetSelector = NULL;
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        SEL selector = method_getName(method);
        const char *name = sel_getName(selector);
        if (name) {
            NSString *methodName = [NSString stringWithUTF8String:name];
            // 匹配方法名后缀
            if ([methodName hasSuffix:methodNameSuffix] && ![methodName containsString:@":"]) { // 确保是无参数的getter
                targetSelector = selector;
                EchoLog(@"找到匹配的方法: %@", methodName);
                break;
            }
        }
    }
    free(methods);

    if (targetSelector) {
        // 使用 performSelector 调用
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        return [object performSelector:targetSelector];
        #pragma clang diagnostic pop
    }
    EchoLog(@"未找到以 '%@' 结尾的无参方法", methodNameSuffix);
    return nil;
}


@interface UIViewController (FinalTweak)
- (void)runMethodProbe;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            [[keyWindow viewWithTag:12345] removeFromSuperview];
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.tag = 12345;
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 120, 45, 110, 36);
            [testButton setTitle:@"方法探测" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor greenColor];
            [testButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(runMethodProbe) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
            [keyWindow bringSubviewToFront:testButton];
        });
    }
}

%new
- (void)runMethodProbe {
    NSMutableString *logOutput = [NSMutableString string];
    [logOutput appendString:@"--- 开始执行V14方法探测 ---\n\n"];
    
    @try {
        // 1. 查找视图
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類");
        if (!plateViewClass) { [logOutput appendString:@"失败: 找不到类定义。\n"]; goto show_log; }
        
        UIWindow *keyWindow = self.view.window;
        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
        if (plateViews.count == 0) { [logOutput appendString:@"失败: 找不到视图实例。\n"]; goto show_log; }
        
        id plateView = plateViews.firstObject;
        [logOutput appendFormat:@"1. 找到视图实例: %@\n\n", plateView];

        // 2. 尝试调用 '地宮宮名列' 的 getter 方法
        [logOutput appendString:@"2. 尝试调用 '地宮宮名列' getter...\n"];
        id diGongObj = InvokeMethodBySuffix(plateView, @"地宮宮名列");
        if (!diGongObj) {
            [logOutput appendString:@"失败: 未找到或调用失败。\n"];
        } else {
            [logOutput appendFormat:@"成功! 返回对象类型: %@\n", NSStringFromClass([diGongObj class])];
            if ([diGongObj isKindOfClass:[NSDictionary class]]) {
                 [logOutput appendFormat:@"数量: %ld\n", (unsigned long)((NSDictionary *)diGongObj).count];
            }
        }
        [logOutput appendString:@"\n"];

        // 3. 尝试调用 '天神宮名列' 的 getter 方法
        [logOutput appendString:@"3. 尝试调用 '天神宮名列' getter...\n"];
        id tianShenObj = InvokeMethodBySuffix(plateView, @"天神宮名列");
        if (!tianShenObj) {
            [logOutput appendString:@"失败: 未找到或调用失败。\n"];
        } else {
            [logOutput appendFormat:@"成功! 返回对象类型: %@\n", NSStringFromClass([tianShenObj class])];
             if ([tianShenObj isKindOfClass:[NSDictionary class]]) {
                 [logOutput appendFormat:@"数量: %ld\n", (unsigned long)((NSDictionary *)tianShenObj).count];
            }
        }
        [logOutput appendString:@"\n"];

        // 4. 尝试调用 '天將宮名列' 的 getter 方法
        [logOutput appendString:@"4. 尝试调用 '天將宮名列' getter...\n"];
        id tianJiangObj = InvokeMethodBySuffix(plateView, @"天將宮名列");
        if (!tianJiangObj) {
            [logOutput appendString:@"失败: 未找到或调用失败。\n"];
        } else {
            [logOutput appendFormat:@"成功! 返回对象类型: %@\n", NSStringFromClass([tianJiangObj class])];
             if ([tianJiangObj isKindOfClass:[NSDictionary class]]) {
                 [logOutput appendFormat:@"数量: %ld\n", (unsigned long)((NSDictionary *)tianJiangObj).count];
            }
        }

    } @catch (NSException *exception) {
        [logOutput appendFormat:@"\n!!! 捕获到异常 !!!\n\n%@\n%@", exception.name, exception.reason];
    }
    
show_log:;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"V14方法探测日志" message:logOutput preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
