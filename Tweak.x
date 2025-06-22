#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 极简独立测试版 (V7 - 精准打击版)
// 目标: 直接获取'宮名列'系列变量
// =========================================================================

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test] " format), ##__VA_ARGS__)

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

@interface UIViewController (TianDiPanTest)
- (void)runTianDiPanTest;
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
            [testButton setTitle:@"測試天地盤" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0]; // 换回蓝色
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(runTianDiPanTest) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
            [keyWindow bringSubviewToFront:testButton];
        });
    }
}

%new
- (void)runTianDiPanTest {
    @try {
        EchoLog(@"--- 开始执行天地盘提取测试 V7 ---");
    
        // 1. 查找视图
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類");
        if (!plateViewClass) { /* ... 错误处理 ... */ return; }
        
        UIWindow *keyWindow = self.view.window;
        if (!keyWindow) { return; }

        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
        if (plateViews.count == 0) { /* ... 错误处理 ... */ return; }
        
        id plateView = plateViews.firstObject;
        EchoLog(@"成功找到天地盘视图实例: %@", plateView);

        // 2. 直接命中目标变量
        NSArray *diGong = GetIvarValueSafely(plateView, @"地宮宮名列");
        NSArray *tianShen = GetIvarValueSafely(plateView, @"天神宮名列");
        NSArray *tianJiang = GetIvarValueSafely(plateView, @"天將宮名列");

        // 3. 严格检查数据并格式化
        NSMutableString *resultText = [NSMutableString string];
        BOOL isDataValid = YES;
        
        if (!diGong || ![diGong isKindOfClass:[NSArray class]] || [diGong count] != 12) {
             [resultText appendFormat:@"地宮宮名列 数据异常! 类型:%@, 数量:%ld\n", NSStringFromClass([diGong class]), (long)[(id)diGong count]];
             isDataValid = NO;
        }
         if (!tianShen || ![tianShen isKindOfClass:[NSArray class]] || [tianShen count] != 12) {
             [resultText appendFormat:@"天神宮名列 数据异常! 类型:%@, 数量:%ld\n", NSStringFromClass([tianShen class]), (long)[(id)tianShen count]];
             isDataValid = NO;
        }
         if (!tianJiang || ![tianJiang isKindOfClass:[NSArray class]] || [tianJiang count] != 12) {
             [resultText appendFormat:@"天將宮名列 数据异常! 类型:%@, 数量:%ld\n", NSStringFromClass([tianJiang class]), (long)[(id)tianJiang count]];
             isDataValid = NO;
        }

        if (isDataValid) {
            [resultText appendString:@"天地盤數據提取成功！\n\n"];
            // 注意：这里的地神/天神/天将 对应关系需要根据App实际逻辑确认。
            // 目前的假设是：diGong是地盘, tianShen是天盘, tianJiang是天将
            for (int i = 0; i < 12; i++) {
                NSString *dp = [diGong[i] isKindOfClass:[NSString class]] ? diGong[i] : @"?";
                NSString *tp = [tianShen[i] isKindOfClass:[NSString class]] ? tianShen[i] : @"?";
                NSString *tj = [tianJiang[i] isKindOfClass:[NSString class]] ? tianJiang[i] : @"??";
                [resultText appendFormat:@"%@宮: %@(%@)\n", dp, tp, tj];
            }
        } else {
             [resultText insertString:@"数据有效性检查失败！\n\n" atIndex:0];
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"天地盤測試結果(V7)" message:resultText preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

    } @catch (NSException *exception) {
        // ... 异常捕获代码保持不变 ...
    }
}

%end
