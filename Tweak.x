#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>**执行**:
    *   打开 App，进入课盘。
    *   **手动点击**天地盘上的**一个天将**。
    *   **手动点击**天地盘上的**一个上神**。

3

// =========================================================================
// 全局变量、常量定义与辅助函数 (保持不变)
.  **提供结果**:
    *   把控制台所有 `[初始化侦察兵]` 开头的日志给我。

这份日志会告诉我们，App 到底是用了哪个 `init` 方法，以及传入了什么类型的参数。一旦// =========================================================================
#pragma mark - Constants & Colors
static const NSInteger kEchoControlButtonTag    = 556699;
static const NSInteger kEchoMainPanelTag        = 7我们知道了这个，我们就可以自己调用它来创建 VC，然后呈现并拦截。

---

**【初始化侦察兵脚本】**

```objc
#import <UIKit/UIKit.h>
#import <objc/runtime.h>78899;
#define ECHO_COLOR_MAIN_BLUE        [UIColor colorWithRed:0.17
#import <substrate.h>

// =========================================================================
// 核心 Hook
// ================= green:0.31 blue:0.51 alpha:1.0]
#define ECHO_COLOR_MAIN_TEAL        [UIColor colorWithRed:0.23 green:0.49 blue:0.4========================================================

// --- Hook 1: 监控天将摘要视图的创建 ---
%hook 六9 alpha:1.0]
#define ECHO_COLOR_LOG_INFO         [UIColor lightGrayColor]
#define壬大占_天將摘要視圖
// 监控标准 init
- (id)init {
    NSLog ECHO_COLOR_LOG_ERROR        [UIColor redColor]
#define ECHO_COLOR_SUCCESS          [UIColor colorWith(@"[初始化侦察兵] 天將摘要視圖 -> 标准 init 被调用!");
    return %orig;
}
Red:0.4 green:1.0 blue:0.4 alpha:1.0]
#define// 监控最常见的自定义 init
- (id)initWithCoder:(NSCoder *)coder {
    NSLog(@"[初始化侦察兵] 天將摘要視圖 -> initWithCoder: 被调用! Coder: %@", coder);
    return %orig;
}
// Swift 中常见的自定义 init (通过 hook 其在 OC 中的表现形式)
+ (id)alloc {
    NSLog(@"[初始化侦察兵] 天將摘要視圖 -> alloc 被调用! 可能是自定义 ECHO_COLOR_LOG_DEBUG        [UIColor orangeColor]
#define ECHO_COLOR_CARD_BG          [UIColor colorWithWhite:0.2 alpha:1.0]

#pragma mark - Global State & Flags
static UIView *g_mainControlPanelView = nil;
static UITextView *g_logTextView = nil;
static BOOL g_isExtractingTianDiPanDetail = NO;
static NSMutableArray *g_tianDiPan_ init 的前奏。");
    return %orig;
}
%end

// --- Hook 2: workQueue = nil;
static NSMutableArray<NSString *> *g_tianDiPan_resultsArray = nil;
监控天地盘宫位摘要视图的创建 ---
%hook 六壬大占_天地盤宮位摘要視圖
// 监控标准 init
- (id)init {
    NSLog(@"[初始化侦察兵] 天地盤static __weak UIViewController *g_mainViewController = nil;

#pragma mark - Coordinate Database
static NSArray *g_t宮位摘要視圖 -> 标准 init 被调用!");
    return %orig;
}
// 监控最常见的自定义 initianDiPan_fixedCoordinates = nil;
static void initializeTianDiPanCoordinates() {
    if (g_tian
- (id)initWithCoder:(NSCoder *)coder {
    NSLog(@"[初始化侦察兵] 天DiPan_fixedCoordinates) return;
    g_tianDiPan_fixedCoordinates = @[
        @地盤宮位摘要視圖 -> initWithCoder: 被调用! Coder: %@", coder);
    return %orig;
}
// Swift 中常见的自定义 init
+ (id)alloc {
    NSLog(@"[初始化侦察兵] 天地盤宮位摘要視圖 -> alloc 被调用! 可能是自定义 init 的前奏。");
    return %orig;
}
%end

%ctor {
    // Theos 会自动处理 %hook 指令
    NSLog(@"[初始化侦察兵] 已加载。请手动点击天地盘上的天将{@"name": @"天将-午位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(180.38, 108.57)]}, @{@"name": @"天将-巳位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(144.48, 118.19)]},
和上神。");
}
