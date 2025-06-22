#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 极简独立测试版 (V4 - 双重类名检查)
// 目标: 专注测试天地盘数据提取功能
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

// 辅助函数: 通过繁体中文变量名后缀从对象中获取Ivar值
static id GetIvarValueByTraditionalChineseSuffix(id object, NSString *ivarNameSuffix) {
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) {
        EchoLog(@"无法获取类 %@ 的实例变量列表。", NSStringFromClass([object class]));
        return nil;
    }

    id value = nil;
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name) {
            NSString *ivarName = [NSString stringWithUTF8String:name];
            if ([ivarName hasSuffix:ivarNameSuffix]) {
                value = object_getIvar(object, ivar);
                EchoLog(@"成功匹配到变量 '%@' 并获取到值: %@", ivarName, value);
                break;
            }
        }
    }
    
    free(ivars);

    if (!value) {
        EchoLog(@"警告: 未能匹配到以 '%@' 结尾的实例变量。", ivarNameSuffix);
    }
    
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
            EchoLog(@"测试按钮已添加。");
        });
    }
}

%new
- (void)runTianDiPanTest {
    EchoLog(@"--- 开始执行天地盘提取测试 ---");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 1. 定义两个可能的类名
        NSString *className1 = @"六壬大占.天地盤視圖";
        NSString *className2 = @"六壬大占.天地盤視圖類";
        
        Class plateViewClass = NSClassFromString(className1);
        if (!plateViewClass) {
            EchoLog(@"尝试类名 '%@' 失败，现在尝试 '%@'...", className1, className2);
            plateViewClass = NSClassFromString(className2);
        }

        if (!plateViewClass) {
            NSString *errorMsg = [NSString stringWithFormat:@"測試失敗: 两个可能的类名 ('%@' 和 '%@') 都找不到。", className1, className2];
            EchoLog(@"%@", errorMsg);
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"錯誤" message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        
        EchoLog(@"成功找到类: %@", NSStringFromClass(plateViewClass));

        // 2. 从最顶层的 window 开始搜索
        UIWindow *keyWindow = self.view.window;
        if (!keyWindow) {
             // ... 错误处理 ...
             return;
        }

        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);

        if (plateViews.count == 0) {
            NSString *errorMsg = [NSString stringWithFormat:@"測試失敗: 在整個App界面中都找不到 '%@' 的實例。", NSStringFromClass(plateViewClass)];
            EchoLog(@"%@", errorMsg);
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"錯誤" message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        
        id plateView = plateViews.firstObject;
        EchoLog(@"成功找到天地盘视图实例: %@", plateView);

        // 3. 提取数据
        NSArray *diPan = GetIvarValueByTraditionalChineseSuffix(plateView, @"地盤");
        NSArray *tianPan = GetIvarValueByTraditionalChineseSuffix(plateView, @"天盤");
        NSArray *tianJiang = GetIvarValueByTraditionalChineseSuffix(plateView, @"天將");
        
        if (!tianJiang) {
            tianJiang = GetIvarValueByTraditionalChineseSuffix(plateView, @"天神宮名列表");
        }

        // 4. 格式化并显示结果
        NSMutableString *resultText = [NSMutableString string];
        if (!diPan || !tianPan || !tianJiang || diPan.count != 12 || tianPan.count != 12 || tianJiang.count != 12) {
            [resultText appendString:@"數據提取不完整或失敗！\n\n"];
            [resultText appendFormat:@"地盤: %@ (數量: %ld)\n", diPan ? @"獲取成功" : @"獲取失敗", (unsigned long)diPan.count];
            [resultText appendFormat:@"天盤: %@ (數量: %ld)\n", tianPan ? @"獲取成功" : @"獲取失敗", (unsigned long)tianPan.count];
            [resultText appendFormat:@"天將: %@ (數量: %ld)\n\n", tianJiang ? @"獲取成功" : @"獲取失敗", (unsigned long)tianJiang.count];
            [resultText appendString:@"請檢查 Xcode 或設備日誌獲取詳細信息。"];
            EchoLog(@"数据检查失败: %@", resultText);

        } else {
            [resultText appendString:@"天地盤數據提取成功！\n\n"];
            for (int i = 0; i < 12; i++) {
                NSString *dp = [diPan[i] isKindOfClass:[NSString class]] ? diPan[i] : @"-";
                NSString *tp = [tianPan[i] isKindOfClass:[NSString class]] ? tianPan[i] : @"-";
                NSString *tj = [tianJiang[i] isKindOfClass:[NSString class]] ? tianJiang[i] : @"--";
                [resultText appendFormat:@"%@宮: %@(%@)\n", dp, tp, tj];
            }
            EchoLog(@"数据格式化成功。");
        }

        // 5. 弹出结果
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"天地盤測試結果" message:resultText preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"複製並關閉" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = resultText;
        }]];
         [alert addAction:[UIAlertAction actionWithTitle:@"關閉" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

%end
