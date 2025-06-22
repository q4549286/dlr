#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 极简独立测试版 (V17 - 数据源探测版)
// 目标: 仅探测'課盤被動更新器'内部的数据，不做任何操作
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
    if (!ivars) { free(ivars); return nil; }
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
- (void)runDataSourceProbe;
@end

%hook UIViewController

- (void)viewDidLoad { %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
            [[keyWindow viewWithTag:12345] removeFromSuperview];
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem]; testButton.tag = 12345;
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 120, 45, 110, 36);
            [testButton setTitle:@"探测数据源" forState:UIControlStateNormal]; testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor orangeColor]; [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(runDataSourceProbe) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton]; [keyWindow bringSubviewToFront:testButton];
        });
    }
}

%new
- (void)runDataSourceProbe {
    NSMutableString *logOutput = [NSMutableString string];
    [logOutput appendString:@"--- 开始执行V17数据源探测 ---\n\n"];
    
    @try {
        // 1. 找到显示层 View
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類");
        if (!plateViewClass) { [logOutput appendString:@"1. 失败: 找不到天地盤視圖类。\n"]; goto show_log; }
        
        UIWindow *keyWindow = self.view.window;
        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
        if (plateViews.count == 0) { [logOutput appendString:@"1. 失败: 找不到天地盤視圖实例。\n"]; goto show_log; }
        
        id plateView = plateViews.firstObject;
        [logOutput appendString:@"1. 成功: 找到天地盤視圖实例。\n\n"];

        // 2. 从显示层中获取数据源 "大脑" 对象
        [logOutput appendString:@"2. 正在获取 '課盤被動更新器'...\n"];
        id dataSource = GetIvarValueSafely(plateView, @"課盤被動更新器");
        if (!dataSource) {
             [logOutput appendString:@"失败: '課盤被動更新器' 对象为nil。\n"];
             goto show_log;
        }
        [logOutput appendFormat:@"成功: 获取到数据源对象, 类型: %@\n\n", NSStringFromClass([dataSource class])];

        // 3. 探测'地宮宮名列'
        [logOutput appendString:@"3. 正在探测 '地宮宮名列'...\n"];
        id diGongObj = GetIvarValueSafely(dataSource, @"地宮宮名列");
        if (!diGongObj) {
            [logOutput appendString:@"结果: nil\n\n"];
        } else {
            NSString *type = NSStringFromClass([diGongObj class]);
            NSUInteger count = [diGongObj respondsToSelector:@selector(count)] ? [(id)diGongObj count] : 0;
            [logOutput appendFormat:@"结果: 类型=%@, 数量=%ld\n\n", type, (unsigned long)count];
        }

        // 4. 探测'天神宮名列'
        [logOutput appendString:@"4. 正在探测 '天神宮名列'...\n"];
        id tianShenObj = GetIvarValueSafely(dataSource, @"天神宮名列");
        if (!tianShenObj) {
            [logOutput appendString:@"结果: nil\n\n"];
        } else {
            NSString *type = NSStringFromClass([tianShenObj class]);
            NSUInteger count = [tianShenObj respondsToSelector:@selector(count)] ? [(id)tianShenObj count] : 0;
            [logOutput appendFormat:@"结果: 类型=%@, 数量=%ld\n\n", type, (unsigned long)count];
        }

        // 5. 探测'天將宮名列'
        [logOutput appendString:@"5. 正在探测 '天將宮名列'...\n"];
        id tianJiangObj = GetIvarValueSafely(dataSource, @"天將宮名列");
        if (!tianJiangObj) {
            [logOutput appendString:@"结果: nil\n"];
        } else {
            NSString *type = NSStringFromClass([tianJiangObj class]);
            NSUInteger count = [tianJiangObj respondsToSelector:@selector(count)] ? [(id)tianJiangObj count] : 0;
            [logOutput appendFormat:@"结果: 类型=%@, 数量=%ld\n", type, (unsigned long)count];
        }

    } @catch (NSException *exception) {
        [logOutput appendFormat:@"\n!!! 捕获到异常 !!!\n\n%@\n%@", exception.name, exception.reason];
    }
    
show_log:;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"V17探测日志" message:logOutput preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
