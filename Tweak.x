#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 辅助函数：获取顶层视图控制器以显示弹窗
// =========================================================================
static UIViewController* getTopmostViewController() {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [[UIApplication sharedApplication] connectedScenes]) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) { keyWindow = window; break; }
                }
            }
        }
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [[UIApplication sharedApplication] keyWindow];
        #pragma clang diagnostic pop
    }
    UIViewController *topController = keyWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    return topController;
}


// =========================================================================
// 2. 核心诊断逻辑：我们用弹窗来报告哪个方法被调用了
// =========================================================================
@interface NSObject (TheOnDeviceDiagnostician)
- (void)my_hooked_didSelectItemAtIndexPath:(id)collectionView didSelectItemAtIndexPath:(id)indexPath;
- (void)my_hooked_showKeChuanSummary:(id)sender;
@end

@implementation NSObject (TheOnDeviceDiagnostician)

// Hook collectionView:didSelectItemAtIndexPath:
- (void)my_hooked_didSelectItemAtIndexPath:(id)collectionView didSelectItemAtIndexPath:(id)indexPath {
    // 【【【核心诊断点 1：弹窗警报器】】】
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"诊断工具" message:@"方法被调用：\n\ncollectionView:\ndidSelectItemAtIndexPath:" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [getTopmostViewController() presentViewController:alert animated:YES completion:nil];
    
    // 调用原始方法，确保App在弹窗消失后能继续运行
    [self my_hooked_didSelectItemAtIndexPath:collectionView didSelectItemAtIndexPath:indexPath];
}

// Hook 顯示課傳摘要WithSender:
- (void)my_hooked_showKeChuanSummary:(id)sender {
    // 【【【核心诊断点 2：弹窗警报器】】】
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"诊断工具" message:@"方法被调用：\n\n顯示課傳摘要WithSender:" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [getTopmostViewController() presentViewController:alert animated:YES completion:nil];
    
    // 调用原始方法
    [self my_hooked_showKeChuanSummary:sender];
}

@end

// =========================================================================
// 3. 方法交换：我们不再需要任何UI，只在后台安装警报器
// =========================================================================
%ctor {
    %init;

    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    
    if (targetClass) {
        // 交换 collectionView:didSelectItemAtIndexPath:
        SEL originalSelector1 = @selector(collectionView:didSelectItemAtIndexPath:);
        SEL newSelector1 = @selector(my_hooked_didSelectItemAtIndexPath:didSelectItemAtIndexPath:);
        Method originalMethod1 = class_getInstanceMethod(targetClass, originalSelector1);
        Method newMethod1 = class_getInstanceMethod([NSObject class], newSelector1);
        if (originalMethod1 && newMethod1) {
            method_exchangeImplementations(originalMethod1, newMethod1);
        }

        // 交换 顯示課傳摘要WithSender:
        SEL originalSelector2 = NSSelectorFromString(@"顯示課傳摘要WithSender:");
        SEL newSelector2 = @selector(my_hooked_showKeChuanSummary:);
        Method originalMethod2 = class_getInstanceMethod(targetClass, originalSelector2);
        Method newMethod2 = class_getInstanceMethod([NSObject class], newSelector2);
        if (originalMethod2 && newMethod2) {
            method_exchangeImplementations(originalMethod2, newMethod2);
        }
    }
}
