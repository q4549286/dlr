#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 极简独立测试版 (V6 - 探测数据源)
// 目标: 尝试从'排盤更新器'中获取数据
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
            testButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
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
        EchoLog(@"--- 开始执行天地盘提取测试 V6 ---");
    
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

        // 2. 尝试获取数据源对象 '排盤更新器'
        id dataSource = GetIvarValueSafely(plateView, @"排盤更新器");
        if (!dataSource) {
             UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"測試失敗" message:@"未能獲取到'排盤更新器'對象。" preferredStyle:UIAlertControllerStyleAlert];
             [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
             [self presentViewController:alert animated:YES completion:nil];
             return;
        }
        EchoLog(@"成功找到数据源 '排盤更新器': %@", dataSource);

        // 3. 从数据源对象中提取最终数据
        NSArray *diPan = GetIvarValueSafely(dataSource, @"地盤");
        NSArray *tianPan = GetIvarValueSafely(dataSource, @"天盤");
        NSArray *tianJiang = GetIvarValueSafely(dataSource, @"天將") ?: GetIvarValueSafely(dataSource, @"天神宮名列表");

        // 4. 严格检查数据并格式化
        NSMutableString *resultText = [NSMutableString string];
        BOOL isDataValid = YES;
        
        if (!diPan || ![diPan isKindOfClass:[NSArray class]] || [diPan count] != 12) {
             [resultText appendFormat:@"地盤数据异常! 类型:%@\n", NSStringFromClass([diPan class])];
             isDataValid = NO;
        }
         if (!tianPan || ![tianPan isKindOfClass:[NSArray class]] || [tianPan count] != 12) {
             [resultText appendFormat:@"天盤数据异常! 类型:%@\n", NSStringFromClass([tianPan class])];
             isDataValid = NO;
        }
         if (!tianJiang || ![tianJiang isKindOfClass:[NSArray class]] || [tianJiang count] != 12) {
             [resultText appendFormat:@"天將数据异常! 类型:%@\n", NSStringFromClass([tianJiang class])];
             isDataValid = NO;
        }

        if (isDataValid) {
            [resultText appendString:@"天地盤數據提取成功！\n\n"];
            for (int i = 0; i < 12; i++) {
                NSString *dp = [diPan[i] isKindOfClass:[NSString class]] ? diPan[i] : @"?";
                NSString *tp = [tianPan[i] isKindOfClass:[NSString class]] ? tianPan[i] : @"?";
                NSString *tj = [tianJiang[i] isKindOfClass:[NSString class]] ? tianJiang[i] : @"??";
                [resultText appendFormat:@"%@宮: %@(%@)\n", dp, tp, tj];
            }
        } else {
             [resultText insertString:@"从'排盤更新器'提取数据失败！\n\n" atIndex:0];
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"天地盤測試結果(V6)" message:resultText preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

    } @catch (NSException *exception) {
        // ... 异常捕获代码保持不变 ...
    }
}

%end
