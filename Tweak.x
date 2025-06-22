#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 极简独立测试版 (V13 - 逐行探测版)
// 目标: 不求成功，只为探测每一步的对象类型，定位闪退点
// =========================================================================

#define EchoLog(format, ...) NSLog((@"[EchoAI-Debug] " format), ##__VA_ARGS__)

// ... (辅助函数 FindSubviewsOfClassRecursive 和 GetIvarValueSafely 保持不变) ...
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) {
    if (!object || !ivarNameSuffix) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) return nil;
    id value = nil;
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name) {
            NSString *ivarName = [NSString stringWithUTF8String:name];
            if ([ivarName hasSuffix:ivarNameSuffix]) {
                ptrdiff_t offset = ivar_getOffset(ivar);
                void **ivar_ptr = (void **)((__bridge void *)object + offset);
                value = (__bridge id)(*ivar_ptr);
                break;
            }
        }
    }
    free(ivars);
    return value;
}

@interface UIViewController (FinalTweak)
- (void)runDebugProbe;
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
            [testButton setTitle:@"調試探测" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor orangeColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(runDebugProbe) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
            [keyWindow bringSubviewToFront:testButton];
        });
    }
}

%new
- (void)runDebugProbe {
    NSMutableString *logOutput = [NSMutableString string];
    [logOutput appendString:@"--- 开始执行V13探测 ---\n\n"];
    EchoLog(@"--- 开始执行V13探测 ---");
    
    @try {
        // 1. 查找视图
        [logOutput appendString:@"1. 正在查找天地盤視圖...\n"];
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類");
        if (!plateViewClass) { [logOutput appendString:@"失败: 找不到类定义。\n"]; goto show_log; }
        
        UIWindow *keyWindow = self.view.window;
        if (!keyWindow) { [logOutput appendString:@"失败: 找不到keyWindow。\n"]; goto show_log; }

        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
        if (plateViews.count == 0) { [logOutput appendString:@"失败: 找不到视图实例。\n"]; goto show_log; }
        
        id plateView = plateViews.firstObject;
        [logOutput appendFormat:@"成功: 找到视图实例: %@\n\n", plateView];
        EchoLog(@"成功: 找到视图实例: %@", plateView);

        // 2. 获取 '地宮宮名列' 字典
        [logOutput appendString:@"2. 正在获取 '地宮宮名列'...\n"];
        id diGongDict = GetIvarValueSafely(plateView, @"地宮宮名列");
        if (!diGongDict) { [logOutput appendString:@"失败: '地宮宮名列' 为nil。\n"]; goto show_log; }
        
        [logOutput appendFormat:@"成功: 获取到对象, 类型: %@\n\n", NSStringFromClass([diGongDict class])];
        EchoLog(@"成功: 获取到 '地宮宮名列' 对象, 类型: %@", NSStringFromClass([diGongDict class]));

        // 3. 检查是否为字典并获取所有Keys
        [logOutput appendString:@"3. 正在检查对象是否为NSDictionary并获取allKeys...\n"];
        if (![diGongDict isKindOfClass:[NSDictionary class]]) {
             [logOutput appendString:@"失败: 该对象不是一个NSDictionary。\n"]; goto show_log;
        }
        
        NSArray *allKeys = [diGongDict allKeys];
        if (!allKeys) { [logOutput appendString:@"失败: allKeys 返回nil。\n"]; goto show_log; }
        
        [logOutput appendFormat:@"成功: 获取到allKeys, 数量: %ld\n\n", (unsigned long)allKeys.count];
        EchoLog(@"成功: 获取到allKeys, 数量: %ld", (unsigned long)allKeys.count);
        
        // 4. 遍历并打印每个Key的类型
        [logOutput appendString:@"4. 正在探测每个Key的类型...\n"];
        for (NSUInteger i = 0; i < allKeys.count; i++) {
            id key = allKeys[i];
            [logOutput appendFormat:@"Key[%ld] 的类型是: %@\n", (unsigned long)i, NSStringFromClass([key class])];
            EchoLog(@"Key[%ld] 的类型是: %@", (unsigned long)i, NSStringFromClass([key class]));
        }
        [logOutput appendString:@"\n探测完成，没有闪退。\n"];


    } @catch (NSException *exception) {
        [logOutput appendFormat:@"\n!!! 在探测过程中捕获到异常 !!!\n\n名称: %@\n原因: %@\n", exception.name, exception.reason];
        EchoLog(@"!!! 在探测过程中捕获到异常: %@, %@", exception.name, exception.reason);
    }
    
show_log:;
    // 无论如何，都弹出日志
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"V13探测日志" message:logOutput preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
