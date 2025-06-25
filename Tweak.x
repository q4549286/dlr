#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
//  主逻辑 - 使用方法交换进行安全探测
// =========================================================================

// 我们将交换 NSObject 的方法，这样可以捕获到所有对象的调用
%hook NSObject

// - (id)forwardingTargetForSelector:(SEL)aSelector
// 这是消息转发的第一步。如果一个对象自己不能实现某个方法，系统会调用这个函数。
// 我们可以利用它来窥探是哪个对象被调用了哪个方法。
- (id)forwardingTargetForSelector:(SEL)aSelector {
    
    // 我们只关心目标App中的类
    NSString *className = NSStringFromClass([self class]);
    if ([className hasPrefix:@"六壬大占"]) {
         // 在系统日志中打印我们捕获到的信息
         NSLog(@"[Probe] Target: %@ | Received Selector: %@", className, NSStringFromSelector(aSelector));
    }

    // 调用原始的实现，确保App正常运行
    return %orig;
}

// respondsToSelector: 也是一个非常好的监控点
- (BOOL)respondsToSelector:(SEL)aSelector {
    NSString *className = NSStringFromClass([self class]);
    if ([className hasPrefix:@"六壬大占"]) {
         // 我们只打印包含 "WithSender" 或 "摘要" 或 "詳情" 的方法，以减少干扰信息
         NSString *selectorName = NSStringFromSelector(aSelector);
         if ([selectorName containsString:@"WithSender"] || [selectorName containsString:@"摘要"] || [selectorName containsString:@"詳情"] || [selectorName containsString:@"课体"] || [selectorName containsString:@"課體"]) {
            NSLog(@"[Probe] Target: %@ | Responds to Selector: %@", className, selectorName);
         }
    }
    return %orig;
}

%end


// 我们不再需要按钮了，因为现在是全局监控
// 所以 ViewController 的 hook 可以暂时移除或注释掉

/*
%hook UIViewController

- (void)viewDidLoad {
    %orig;
    // ... 不再需要添加按钮 ...
}

%end
*/
