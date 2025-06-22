#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 极简独立测试版 (V14.1 - 修复编译错误)
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
        NSArray *diGong = GetIvarValueSafely(dataSource, @"地宮宮名列");
        NSArray *tianShen = GetIvarValueSafely(dataSource, @"天神宮名列");
        NSArray *tianJiang = GetIvarValueSafely(dataSource, @"天將宮名列");
        
        // 4. 检查数据并格式化
        NSMutableString *resultText = [NSMutableString string];
        BOOL isDataValid = YES;
        
        if (!diGong || ![diGong isKindOfClass:[NSArray class]] || [diGong count] != 12) {
             [resultText appendFormat:@"地宮宫名列 数据异常!\n"];
             isDataValid = NO;
        }
         if (!tianShen || ![tianShen isKindOfClass:[NSArray class]] || [tianShen count] != 12) {
             [resultText appendFormat:@"天神宫名列 数据异常!\n"];
             isDataValid = NO;
        }
         if (!tianJiang || ![tianJiang isKindOfClass:[NSArray class]] || [tianJiang count] != 12) {
             [resultText appendFormat:@"天将宫名列 数据异常!\n"];
             isDataValid = NO;
        }

        if (isDataValid) {
            [resultText appendString:@"从'課盤被動更新器'提取成功！\n\n"];
            for (int i = 0; i < 12; i++) {
                NSString *dp = [diGong[i] isKindOfClass:[NSString class]] ? diGong[i] : @"?";
                NSString *tp = [tianShen[i] isKindOfClass:[NSString class]] ? tianShen[i] : @"?";
                NSString *tj = [tianJiang[i] isKindOfClass:[NSString class]] ? tianJiang[i] : @"??";
                [resultText appendFormat:@"%@宮: %@(%@)\n", dp, tp, tj];
            }
        } else {
             [resultText insertString:@"提取失败！\n\n" atIndex:0];
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取结果 (V14.1)" message:resultText preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

    } @catch (NSException *exception) {
        // ...
    }
}

%end
