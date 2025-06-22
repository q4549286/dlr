#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 极简独立测试版 (V5 - 终极安全版)
// 目标: 通过严格的安全检查来防止闪退，并定位问题
// =========================================================================

// 日志宏定义
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test] " format), ##__VA_ARGS__)

// 辅助函数: 递归查找指定类的子视图
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}

// 辅助函数: 安全地获取Ivar值
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
                // 直接使用C指针，避免OC方法调用可能带来的崩溃
                ptrdiff_t offset = ivar_getOffset(ivar);
                // 从对象的起始地址加上偏移量，获取ivar的地址
                void **ivar_ptr = (void **)((__bridge void *)object + offset);
                // 读取地址中的值
                value = (__bridge id)(*ivar_ptr);
                EchoLog(@"成功匹配到变量 '%@'，已获取其值。", ivarName);
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
        EchoLog(@"--- 开始执行天地盘提取测试 ---");
    
        // 1. 查找视图
        NSString *className1 = @"六壬大占.天地盤視圖";
        NSString *className2 = @"六壬大占.天地盤視圖類";
        Class plateViewClass = NSClassFromString(className1) ?: NSClassFromString(className2);

        if (!plateViewClass) {
            // ... 错误处理 ...
            return;
        }
        
        UIWindow *keyWindow = self.view.window;
        if (!keyWindow) { return; }

        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);

        if (plateViews.count == 0) {
            // ... 错误处理 ...
            return;
        }
        
        id plateView = plateViews.firstObject;
        EchoLog(@"成功找到天地盘视图实例: %@", plateView);

        // 2. 安全地获取数据
        id diPanObj = GetIvarValueSafely(plateView, @"地盤");
        id tianPanObj = GetIvarValueSafely(plateView, @"天盤");
        id tianJiangObj = GetIvarValueSafely(plateView, @"天將") ?: GetIvarValueSafely(plateView, @"天神宮名列表");

        // 3. 极其严格地检查数据类型和内容
        NSMutableString *resultText = [NSMutableString string];
        BOOL isDataValid = YES;
        
        if (!diPanObj || ![diPanObj isKindOfClass:[NSArray class]] || [((NSArray *)diPanObj) count] != 12) {
            [resultText appendFormat:@"地盤数据异常! 类型:%@, 数量:%ld\n", NSStringFromClass([diPanObj class]), (long)[(id)diPanObj count]];
            isDataValid = NO;
        }
        
        if (!tianPanObj || ![tianPanObj isKindOfClass:[NSArray class]] || [((NSArray *)tianPanObj) count] != 12) {
            [resultText appendFormat:@"天盤数据异常! 类型:%@, 数量:%ld\n", NSStringFromClass([tianPanObj class]), (long)[(id)tianPanObj count]];
            isDataValid = NO;
        }
        
        if (!tianJiangObj || ![tianJiangObj isKindOfClass:[NSArray class]] || [((NSArray *)tianJiangObj) count] != 12) {
            [resultText appendFormat:@"天將数据异常! 类型:%@, 数量:%ld\n", NSStringFromClass([tianJiangObj class]), (long)[(id)tianJiangObj count]];
            isDataValid = NO;
        }

        // 4. 如果数据有效，则格式化
        if (isDataValid) {
            [resultText appendString:@"天地盤數據提取成功！\n\n"];
            NSArray *diPan = (NSArray *)diPanObj;
            NSArray *tianPan = (NSArray *)tianPanObj;
            NSArray *tianJiang = (NSArray *)tianJiangObj;
            
            for (int i = 0; i < 12; i++) {
                // 再次检查数组成员的类型
                NSString *dp = [diPan[i] isKindOfClass:[NSString class]] ? diPan[i] : @"?";
                NSString *tp = [tianPan[i] isKindOfClass:[NSString class]] ? tianPan[i] : @"?";
                NSString *tj = [tianJiang[i] isKindOfClass:[NSString class]] ? tianJiang[i] : @"??";
                [resultText appendFormat:@"%@宮: %@(%@)\n", dp, tp, tj];
            }
        } else {
             [resultText insertString:@"数据有效性检查失败！\n\n" atIndex:0];
        }

        // 5. 弹出结果
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"天地盤測試結果" message:resultText preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"複製並關閉" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = resultText;
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"關閉" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

    } @catch (NSException *exception) {
        NSString *errorMsg = [NSString stringWithFormat:@"捕获到严重异常，导致闪退！\n\n名称: %@\n原因: %@\n\n调用栈: %@", exception.name, exception.reason, exception.callStackSymbols];
        EchoLog(@"%@", errorMsg);
        
        // 在主线程上安全地弹出错误信息
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"捕获到闪退" message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        });
    }
}

%end
