#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 极简独立测试版
// 目标: 专注测试天地盘数据提取功能
// =========================================================================

// 日志宏定义
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test] " format), ##__VA_ARGS__)

// 辅助函数: 通过繁体中文变量名后缀从对象中获取Ivar值
static id GetIvarValueByTraditionalChineseSuffix(id object, NSString *ivarNameSuffix) {
    unsigned int ivarCount;
    // 获取指定类的所有实例变量
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
            // 使用 hasSuffix: 来匹配Swift编译后的混淆变量名
            // 例如, 匹配 "$s12六壬大占12天地盤視圖C4地盤SaySSGvg" 中的 "地盤"
            if ([ivarName hasSuffix:ivarNameSuffix]) {
                value = object_getIvar(object, ivar);
                EchoLog(@"成功匹配到变量 '%@' 并获取到值: %@", ivarName, value);
                break; // 找到即跳出循环
            }
        }
    }
    
    // 释放内存
    free(ivars);

    if (!value) {
        EchoLog(@"警告: 未能匹配到以 '%@' 结尾的实例变量。", ivarNameSuffix);
    }
    
    return value;
}

// 递归查找指定类的子视图
static void FindSubviewsOfClass(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClass(aClass, view, storage); // 修正：应为 subview
    }
}


@interface UIViewController (TianDiPanTest)
- (void)runTianDiPanTest;
@end

%hook UIViewController

// 仅在主视图控制器 (ViewController) 加载时添加按钮
- (void)viewDidLoad {
    %orig;
    
    // 目标控制器类名，根据App实际情况可能需要调整
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        // 延迟执行以确保window存在
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            // 创建测试按钮
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 120, 45, 110, 36);
            [testButton setTitle:@"测试天地盘" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor redColor]; // 使用醒目的红色
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
    
    // 1. 定义目标视图类名
    NSString *plateViewClassName = @"六壬大占.天地盤視圖";
    Class plateViewClass = NSClassFromString(plateViewClassName);
    
    if (!plateViewClass) {
        NSString *errorMsg = [NSString stringWithFormat:@"测试失败: 找不到类 '%@'。", plateViewClassName];
        EchoLog(@"%@", errorMsg);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // 2. 在当前视图层级中查找目标视图实例
    NSMutableArray *plateViews = [NSMutableArray array];
    // 修正：调用正确的递归函数
    void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
        if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
        for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
    }
    FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);

    if (plateViews.count == 0) {
        NSString *errorMsg = @"测试失败: 在当前界面找不到天地盘视图的实例。";
        EchoLog(@"%@", errorMsg);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    id plateView = plateViews.firstObject;
    EchoLog(@"成功找到天地盘视图实例: %@", plateView);

    // 3. 直接通过运行时，从实例变量中获取数据 (全部使用繁体字)
    NSArray *diPan = GetIvarValueByTraditionalChineseSuffix(plateView, @"地盤");
    NSArray *tianPan = GetIvarValueByTraditionalChineseSuffix(plateView, @"天盤");
    NSArray *tianJiang = GetIvarValueByTraditionalChineseSuffix(plateView, @"天將");
    
    // 备用名称，以防主名称不匹配
    if (!tianJiang) {
        tianJiang = GetIvarValueByTraditionalChineseSuffix(plateView, @"天神宮名列表");
    }

    // 4. 检查数据并格式化输出
    NSMutableString *resultText = [NSMutableString string];
    if (!diPan || !tianPan || !tianJiang || diPan.count != 12 || tianPan.count != 12 || tianJiang.count != 12) {
        [resultText appendString:@"数据提取不完整或失败！\n\n"];
        [resultText appendFormat:@"地盤: %@ (数量: %ld)\n", diPan ? @"获取成功" : @"获取失败", (unsigned long)diPan.count];
        [resultText appendFormat:@"天盤: %@ (数量: %ld)\n", tianPan ? @"获取成功" : @"获取失败", (unsigned long)tianPan.count];
        [resultText appendFormat:@"天將: %@ (数量: %ld)\n\n", tianJiang ? @"获取成功" : @"获取失败", (unsigned long)tianJiang.count];
        [resultText appendString:@"请检查控制台日志获取详细错误信息。"];
        EchoLog(@"数据检查失败: %@", resultText);

    } else {
        [resultText appendString:@"天地盘数据提取成功！\n\n"];
        for (int i = 0; i < 12; i++) {
            NSString *dp = [diPan[i] isKindOfClass:[NSString class]] ? diPan[i] : @"-";
            NSString *tp = [tianPan[i] isKindOfClass:[NSString class]] ? tianPan[i] : @"-";
            NSString *tj = [tianJiang[i] isKindOfClass:[NSString class]] ? tianJiang[i] : @"--";
            [resultText appendFormat:@"%@宮: %@(%@)\n", dp, tp, tj];
        }
        EchoLog(@"数据格式化成功。");
    }

    // 5. 弹出结果
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"天地盘测试结果" message:resultText preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"复制并关闭" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [UIPasteboard generalPasteboard].string = resultText;
    }]];
     [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
