// =================================================================================
// SinrenFreeTweak.xm
// ---------------------------------------------------------------------------------
// 目标: 针对 "大六壬(工具)" (SixRenFree.app) 的内购破解 Tweak
// 策略: 
// 1. Hook `PurchaseViewController` 的 `viewDidLoad` 方法。
//    (viewDidLoad 是每个视图控制器加载完成时必定会调用的方法)
// 2. 在 `viewDidLoad` 执行后，我们延迟一小段时间（确保所有按钮都已加载）。
// 3. 延迟后，我们找到 "恢复购买" 按钮，并以代码方式模拟一次点击。
// 4. 如果 App 是本地验证，这将触发其内部的解锁逻辑。
//
// 适用于巨魔环境下的 Tweak 注入。
// =================================================================================

#import <UIKit/UIKit.h>

// 声明我们要 Hook 的类，即使我们没有它的头文件
@interface PurchaseViewController : UIViewController
// 根据你的分析，我们知道它有这两个方法
- (void)restorePurchaseButtonClicked:(id)sender;
- (void)purchaseNoAdsButtonClicked:(id)sender;
@end


// 开始 Hook 我们明确的目标类：PurchaseViewController
%hook PurchaseViewController

// 选择一个合适的时机来执行我们的代码。
// - (void)viewDidLoad 是一个完美的选择，因为它在购买页面加载时就会被调用。
- (void)viewDidLoad {
    // 首先，必须调用原始的 viewDidLoad 方法，让页面正常加载。
    %orig;

    // 因为我们是在原始方法执行后进行操作，
    // 所以此时 self (也就是 PurchaseViewController 实例) 已经存在。
    
    NSLog(@"[SinrenFreeTweak] Hooked into PurchaseViewController! Waiting to simulate click...");

    // 我们稍微延迟一下操作，比如 0.5 秒。
    // 这是为了确保页面上的所有元素（特别是按钮）都已经完全准备好了。
    // 直接调用可能会因为按钮还没初始化而失败。
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 检查 self (当前视图控制器) 是否真的响应 "恢复购买点击" 这个方法。
        // 这是一个安全措施，防止 App 更新后方法名改变导致闪退。
        if ([self respondsToSelector:@selector(restorePurchaseButtonClicked:)]) {
            
            NSLog(@"[SinrenFreeTweak] Found restorePurchaseButtonClicked: method. Simulating click now!");
            
            // 直接调用恢复购买的方法！参数传 nil 即可。
            // 这就相当于我们用代码帮用户按下了“恢复购买”按钮。
            [self restorePurchaseButtonClicked:nil];

        } else {
            NSLog(@"[SinrenFreeTweak] Error: Could not find restorePurchaseButtonClicked: method. Maybe the app was updated?");
        }
    });
}

%end


// 构造函数，可选。用来确认 Tweak 是否被成功加载。
%ctor {
    %init;
    NSLog(@"[SinrenFreeTweak] Tweak loaded successfully into SinrenFree.app!");
}
