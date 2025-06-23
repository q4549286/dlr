#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-v3] " format), ##__VA_ARGS__)

// =========================================================================
// 辅助函数
// =========================================================================
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 测试专用 Hook
// =========================================================================

@interface UIViewController (DelegateTestAddon)
- (void)performCollectionViewDelegateTest;
@end

%hook UIViewController

// 在主界面加载时，添加我们的“测试按钮”
- (void)viewDidLoad {
    %orig;
    
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            NSInteger testButtonTag = 999002;
            if ([keyWindow viewWithTag:testButtonTag]) return;
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 200, 45, 90, 36);
            testButton.tag = testButtonTag;
            [testButton setTitle:@"测试代理" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            
            // --- 【修复】修改颜色设置方法 ---
            testButton.backgroundColor = [UIColor purpleColor];
            
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            
            [testButton addTarget:self action:@selector(performCollectionViewDelegateTest) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            EchoLog(@"代理测试按钮已添加。");
        });
    }
}

// 新的测试方法：模拟CollectionView代理调用
%new
- (void)performCollectionViewDelegateTest {
    EchoLog(@"--- 开始 CollectionView 代理方法模拟测试 ---");

    // 1. 查找包含行年单元的 CollectionView
    NSMutableArray *collectionViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], self.view, collectionViews);

    UICollectionView *targetCollectionView = nil;
    Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    if (!unitClass) {
        EchoLog(@"测试失败: 找不到 '六壬大占.行年單元' 类。");
        return;
    }
    EchoLog(@"成功找到 '六壬大占.行年單元' 类。");

    for (UICollectionView *cv in collectionViews) {
        NSArray *visibleCells = [cv visibleCells];
        if (visibleCells.count > 0 && [visibleCells.firstObject isKindOfClass:unitClass]) {
            targetCollectionView = cv;
            break;
        }
    }

    if (!targetCollectionView) {
        EchoLog(@"测试失败: 未能找到包含 '行年單元' 的 UICollectionView。");
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试失败" message:@"未找到目标 UICollectionView。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    EchoLog(@"成功找到目标 UICollectionView: %@", targetCollectionView);

    // 2. 获取 CollectionView 的代理 (通常是当前的 ViewController)
    id delegate = targetCollectionView.delegate;
    if (!delegate) {
        EchoLog(@"测试失败: 目标 UICollectionView 没有设置 delegate。");
        return;
    }
    EchoLog(@"找到代理对象: %@", delegate);

    // 3. 检查代理是否响应目标方法
    SEL selector = @selector(collectionView:didSelectItemAtIndexPath:);
    if (![delegate respondsToSelector:selector]) {
        EchoLog(@"测试失败: 代理对象 %@ 不响应方法 %@", delegate, NSStringFromSelector(selector));
        return;
    }
    EchoLog(@"代理对象响应方法: collectionView:didSelectItemAtIndexPath:");

    // 4. 找到第一个行年单元（即'A'）的 IndexPath
    NSIndexPath *targetIndexPath = nil;
    for (UICollectionViewCell *cell in [targetCollectionView visibleCells]) {
        if ([cell isKindOfClass:unitClass]) {
            targetIndexPath = [targetCollectionView indexPathForCell:cell];
            // 我们只测试第一个，所以找到就跳出
            break;
        }
    }

    if (!targetIndexPath) {
        EchoLog(@"测试失败: 未能获取到第一个 '行年單元' 的 IndexPath。");
        return;
    }
    EchoLog(@"找到目标 IndexPath: section=%ld, item=%ld", (long)targetIndexPath.section, (long)targetIndexPath.item);

    // 5. 【核心】直接调用代理方法，模拟用户点击
    EchoLog(@">>> 正在调用代理方法...");

    #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) \
        _Pragma("clang diagnostic push") \
        _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
        code; \
        _Pragma("clang diagnostic pop")
    
    SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(
        [delegate performSelector:selector withObject:targetCollectionView withObject:targetIndexPath];
    );

    EchoLog(@"<<< 已调用代理方法。请观察界面是否有 '年命摘要' 菜单弹出。");

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试完成" message:@"已尝试通过调用代理方法模拟点击。请观察是否弹出了操作表，并检查日志。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
