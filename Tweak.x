#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 极简独立测试版 (V14 - 数据源探测版)
// 目标: 从'課盤被動更新器'中提取数据
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

@interface UIViewController (FinalTweak)
- (void)runFinalExtraction;
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
            [testButton setTitle:@"提取天地盤" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(runFinalExtraction) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
            [keyWindow bringSubviewToFront:testButton];
        });
    }
}

%new
- (void)runFinalExtraction {
    @try {
        // 1. 查找视图
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類");
        if (!plateViewClass) return;
        
        UIWindow *keyWindow = self.view.window;
        if (!keyWindow) return;

        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
        if (plateViews.count == 0) return;
        
        id plateView = plateViews.firstObject;

        // 2. 从视图中获取'課盤被動更新器'对象
        id dataSource = GetIvarValueSafely(plateView, @"課盤被動更新器");
        
        if (!dataSource) {
             UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"測試失敗" message:@"未能獲取到'課盤被動更新器'對象。" preferredStyle:UIAlertControllerStyleAlert];
             [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
             [self presentViewController:alert animated:YES completion:nil];
             return;
        }
        EchoLog(@"成功获取到数据源: %@", dataSource);

        // 3. 从'課盤被動更新器'中提取数据
        // 注意：我们现在直接从 dataSource 中获取数据，而不是 plateView
        NSArray *diGong = GetIvarValueSafely(dataSource, @"地宮宮名列");
        NSArray *tianShen = GetIvarValueSafely(dataSource, @"天神宮名列");
        NSArray *tianJiang = GetIvarValueSafely(dataSource, @"天將宮名列");
        
        // 4. 检查数据并格式化
        if (!diGong || ![diGong isKindOfClass:[NSArray class]] || diGong.count != 12) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取失败" message:@"从更新器中未能获取到正确的'地宮宮名列'。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        // ... (对 tianShen 和 tianJiang 进行类似检查) ...

        // 5. 排序和输出
        NSMutableArray *palaceData = [NSMutableArray array];
        for (NSUInteger i = 0; i < 12; i++) {
            // 注意：这次我们直接使用数组，因为数据源里的数组很可能是已经排好序的
            NSString *diGongStr = [diGong[i] isKindOfClass:[NSString class]] ? diGong[i] : @"?";
            // 这里我们假设天神和天将也是排好序的数组，但它们可能不是，我们先做简单提取
            // 为了安全，我们只显示地宫，验证数据是否正确和实时
             NSDictionary *entry = @{@"diPan": diGongStr};
            [palaceData addObject:entry];
        }

        // 暂时不排序，直接按获取到的顺序输出，看看是不是子丑寅卯...
        NSMutableString *resultText = [NSMutableString string];
        [resultText appendString:@"来自'課盤被動更新器'的数据 (V14)\n\n"];
        for (NSDictionary *entry in palaceData) {
            [resultText appendFormat:@"%@宮\n", entry[@"diPan"]];
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取结果" message:resultText preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

    } @catch (NSException *exception) {
        // ...
    }
}

%end
