#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <os/log.h> // 引入日志头文件

// =========================================================================
// 核心诊断逻辑：我们只记录哪个方法被调用了
// =========================================================================
@interface NSObject (TheUltimateDiagnostic)
- (void)my_hooked_didSelectItemAtIndexPath:(id)collectionView didSelectItemAtIndexPath:(id)indexPath;
- (void)my_hooked_showKeChuanSummary:(id)sender;
@end

@implementation NSObject (TheUltimateDiagnostic)

// Hook collectionView:didSelectItemAtIndexPath:
- (void)my_hooked_didSelectItemAtIndexPath:(id)collectionView didSelectItemAtIndexPath:(id)indexPath {
    // 【【【核心诊断点 1】】】
    // 在系统日志中打印一条明确的消息
    os_log(OS_LOG_TYPE_DEFAULT, "[MY_DIAGNOSTIC_TOOL] >>> Method 'collectionView:didSelectItemAtIndexPath:' was CALLED! <<<");
    
    // 调用原始方法，确保App正常运行
    [self my_hooked_didSelectItemAtIndexPath:collectionView didSelectItemAtIndexPath:indexPath];
}

// Hook 顯示課傳摘要WithSender:
- (void)my_hooked_showKeChuanSummary:(id)sender {
    // 【【【核心诊断点 2】】】
    // 在系统日志中打印一条明确的消息
    os_log(OS_LOG_TYPE_DEFAULT, "[MY_DIAGNOSTIC_TOOL] >>> Method '顯示課傳摘要WithSender:' was CALLED! <<<");
    
    // 调用原始方法，确保App正常运行
    [self my_hooked_showKeChuanSummary:sender];
}

@end

// =========================================================================
// 方法交换：我们不再需要UI，只需要在后台默默监听
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
