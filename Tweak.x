#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test] " format), ##__VA_ARGS__)

// =========================================================================
// 辅助函数 (仅保留测试所需)
// =========================================================================
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}

// =========================================================================
// 测试专用 Hook
// =========================================================================

@interface UIViewController (ClickTestAddon)
- (void)performNianMingClickTest;
@end

%hook UIViewController

// 在主界面加载时，添加我们的“测试按钮”
- (void)viewDidLoad {
    %orig;
    
    // 仅在目标主界面控制器上操作
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        
        // 使用一个延迟确保界面已完全布局
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            // 防止重复添加
            NSInteger testButtonTag = 999000;
            if ([keyWindow viewWithTag:testButtonTag]) {
                return;
            }
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            // 放在“提取课盘”按钮的左边
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 200, 45, 90, 36);
            testButton.tag = testButtonTag;
            [testButton setTitle:@"测试点击A" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.7 blue:0.3 alpha:1.0]; // 绿色，以示区分
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            
            // 关键：将按钮的目标和动作指向我们新的测试方法
            [testButton addTarget:self action:@selector(performNianMingClickTest) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            EchoLog(@"测试按钮已添加。");
        });
    }
}

// 我们新的测试方法
%new
- (void)performNianMingClickTest {
    EchoLog(@"--- 开始年命按钮点击测试 ---");

    // 1. 查找目标类
    Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    if (!unitClass) {
        EchoLog(@"测试失败: 找不到 '六壬大占.行年單元' 类。");
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试失败" message:@"找不到 '六壬大占.行年單元' 类。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    EchoLog(@"成功找到 '六壬大占.行年單元' 类。");

    // 2. 在当前视图中查找所有行年单元实例
    NSMutableArray *unitViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(unitClass, self.view, unitViews);

    if (unitViews.count == 0) {
        EchoLog(@"测试失败: 在当前视图中未找到 '行年單元' 的实例。");
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试失败" message:@"未找到行年单元视图。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    EchoLog(@"找到 %ld 个 '行年單元' 实例。", (long)unitViews.count);

    // 3. 假设我们要点击第一个（通常是'A'）
    UIView *targetUnitView = unitViews.firstObject;
    EchoLog(@"目标行年单元: %@", targetUnitView);

    // 4. 在这个单元中查找按钮
    NSMutableArray *buttons = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UIButton class], targetUnitView, buttons);

    if (buttons.count == 0) {
        EchoLog(@"测试失败: 在目标行年单元中未找到任何 UIButton。");
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试失败" message:@"在目标行年单元中未找到任何按钮。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    UIButton *buttonToClick = buttons.firstObject;
    EchoLog(@"找到目标按钮: '%@'", buttonToClick.titleLabel.text);

    // 5. 【关键诊断】检查按钮及其父视图的交互状态
    EchoLog(@"检查按钮状态: isEnabled = %d", buttonToClick.isEnabled);
    UIView *v = buttonToClick;
    int depth = 0;
    while (v) {
        EchoLog(@"层级 %d: %@, userInteractionEnabled = %d", depth, v.class, v.isUserInteractionEnabled);
        if (!v.isUserInteractionEnabled && v != self.view) { // 如果有父视图禁止交互，这就是问题所在
             EchoLog(@"警告: 发现层级 %d (%@) 的 userInteractionEnabled 为 NO, 这可能会阻止点击事件！", depth, v.class);
        }
        v = v.superview;
        depth++;
    }

    // 6. 执行点击
    EchoLog(@">>> 正在模拟点击按钮...");
    [buttonToClick sendActionsForControlEvents:UIControlEventTouchUpInside];
    EchoLog(@"<<< 已发送点击事件。请观察界面是否有 '年命摘要' 菜单弹出。");
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试完成" message:@"已尝试点击第一个行年按钮。请观察是否弹出了操作表，并检查日志输出。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
