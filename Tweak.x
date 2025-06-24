#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局数据结构 & Debug Overlay
// =========================================================================
typedef NS_ENUM(NSUInteger, EKWorkType) {
    EKWorkTypeDiZhi,
    EKWorkTypeTianJiang,
};

@interface EKWorkItem : NSObject
@property (nonatomic, weak)   UIView   *sender;   ///< 傳視圖 (初/中/末)
@property (nonatomic, assign) EKWorkType type;    ///< 地支 or 天将
@property (nonatomic, copy)   NSString *title;    ///< 结果标题
@end
@implementation EKWorkItem @end

static BOOL g_isExtracting       = NO;
static NSMutableArray<NSString *>     *g_results     = nil;
static NSMutableArray<EKWorkItem *>   *g_workQueue   = nil;

// ---- Debug Overlay ----
static UIWindow   *g_debugWin    = nil;
static UILabel    *g_debugLabel  = nil;

static void EKShowDebugOverlay(void) {
    if (g_debugWin) return;

    CGFloat width  = UIScreen.mainScreen.bounds.size.width;
    g_debugWin = [[UIWindow alloc] initWithFrame:CGRectMake(0, 20, width, 30)];
    g_debugWin.windowLevel = UIWindowLevelAlert + 1;
    g_debugWin.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];

    g_debugLabel = [[UILabel alloc] initWithFrame:g_debugWin.bounds];
    g_debugLabel.font = [UIFont systemFontOfSize:13];
    g_debugLabel.textColor = UIColor.greenColor;
    g_debugLabel.textAlignment = NSTextAlignmentCenter;
    g_debugLabel.numberOfLines = 1;

    [g_debugWin addSubview:g_debugLabel];
    g_debugWin.hidden = NO;
}

static void EKUpdateDebugText(NSString *text) {
    if (!g_debugWin) EKShowDebugOverlay();
    g_debugLabel.text = text;
}

static void EKHideDebugOverlay(void) {
    g_debugWin.hidden = YES;
    g_debugWin = nil;
    g_debugLabel = nil;
}

// 递归收集子视图
static void FindSubviewsRecursive(Class cls, UIView *view, NSMutableArray *out) {
    if ([view isKindOfClass:cls]) [out addObject:view];
    for (UIView *sub in view.subviews) FindSubviewsRecursive(cls, sub, out);
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)performKeChuanExtraction_Truth;
- (void)ek_processQueue;
@end

%hook UIViewController

// -------------------------------------------------------------------------
// viewDidLoad：添加“课传提取(谢罪版)”按钮
// -------------------------------------------------------------------------
- (void)viewDidLoad {
    %orig;

    Class targetCls = NSClassFromString(@"六壬大占.ViewController");
    if (![self isKindOfClass:targetCls]) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindow *keyWin = self.view.window;
        if (!keyWin) return;

        const NSInteger kBtnTag = 556690;
        [[keyWin viewWithTag:kBtnTag] removeFromSuperview];

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(keyWin.bounds.size.width - 150, 125, 140, 36);
        btn.tag   = kBtnTag;
        btn.layer.cornerRadius = 8;
        btn.backgroundColor    = UIColor.systemGreenColor;
        btn.titleLabel.font    = [UIFont boldSystemFontOfSize:16];
        [btn setTitle:@"课传提取(谢罪版)" forState:UIControlStateNormal];
        [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [btn addTarget:self
                action:@selector(performKeChuanExtraction_Truth)
      forControlEvents:UIControlEventTouchUpInside];
        [keyWin addSubview:btn];
    });
}

// -------------------------------------------------------------------------
// presentViewController：拦截“課傳摘要視圖 / 天將摘要視圖”弹窗并抓取文字
// -------------------------------------------------------------------------
- (void)presentViewController:(UIViewController *)vc
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion {

    if (g_isExtracting) {
        NSString *clsName = NSStringFromClass([vc class]);
        BOOL isKeChuan =
        ([clsName containsString:@"課傳摘要視圖"] ||
         [clsName containsString:@"課傳天將摘要視圖"]);

        if (isKeChuan) {
            vc.view.alpha = 0;       // 隐藏原弹窗
            flag = NO;

            __weak typeof(self) weakSelf = self;
            void (^wrap)(void) = ^{
                if (completion) completion();

                // 抓取所有 UILabel 文本
                NSMutableArray *labels = [NSMutableArray array];
                FindSubviewsRecursive([UILabel class], vc.view, labels);
                [labels sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
                    if (fabs(a.frame.origin.y - b.frame.origin.y) > 0.5)
                        return a.frame.origin.y < b.frame.origin.y ? NSOrderedAscending : NSOrderedDescending;
                    return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
                }];
                NSMutableArray *parts = [NSMutableArray array];
                for (UILabel *lb in labels) {
                    if (lb.text.length)
                        [parts addObject:[lb.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                }
                [g_results addObject:[parts componentsJoinedByString:@"\n"]];

                [vc dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                                   dispatch_get_main_queue(), ^{
                        [weakSelf ek_processQueue];
                    });
                }];
            };
            return %orig(vc, flag, wrap);
        }
    }
    %orig(vc, flag, completion);
}
%end

// =========================================================================
// 3. 新增实现
// =========================================================================
@implementation UIViewController (EchoAITestAddons_Truth)

// -------------------------------------------------------------------------
// 点击按钮 → 构建工作队列
// -------------------------------------------------------------------------
- (void)performKeChuanExtraction_Truth {
    if (g_isExtracting) return;

    g_isExtracting = YES;
    g_results      = [NSMutableArray array];
    g_workQueue    = [NSMutableArray array];

    // ======== Part A: 三传 ========
    Class containerCls = NSClassFromString(@"六壬大占.三傳視圖");
    if (containerCls) {
        NSMutableArray *containers = [NSMutableArray array];
        FindSubviewsRecursive(containerCls, self.view, containers);
        if (containers.count) {
            UIView *container = containers.firstObject;

            const char *ivarNames[] = {"初傳", "中傳", "末傳", NULL};
            NSString   *rowTitles[] = {@"初传", @"中传", @"末传"};

            for (int i = 0; ivarNames[i]; ++i) {
                Ivar ivar = class_getInstanceVariable(containerCls, ivarNames[i]);
                if (!ivar) continue;

                UIView *rowView = object_getIvar(container, ivar);
                if (!rowView) continue;

                // 提取地支 / 天将标签文本，仅用于标题
                NSMutableArray *lbls = [NSMutableArray array];
                FindSubviewsRecursive([UILabel class], rowView, lbls);
                [lbls sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
                    return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
                }];
                NSString *dizhiTxt = lbls.count >= 2 ? ((UILabel *)lbls[lbls.count-2]).text : @"?";
                NSString *tianjTxt = lbls.count >= 1 ? ((UILabel *)lbls.lastObject).text   : @"?";

                // 1️⃣ 地支
                EKWorkItem *di = [EKWorkItem new];
                di.sender = rowView;
                di.type   = EKWorkTypeDiZhi;
                di.title  = [NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiTxt];
                [g_workQueue addObject:di];

                // 2️⃣ 天将
                EKWorkItem *tj = [EKWorkItem new];
                tj.sender = rowView;
                tj.type   = EKWorkTypeTianJiang;
                tj.title  = [NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjTxt];
                [g_workQueue addObject:tj];
            }
        }
    }

    if (!g_workQueue.count) { g_isExtracting = NO; return; }

    EKShowDebugOverlay();
    [self ek_processQueue];
}

// -------------------------------------------------------------------------
// 处理队列
// -------------------------------------------------------------------------
- (void)ek_processQueue {

    // ---- 全部完成 ----
    if (!g_workQueue.count) {
        NSMutableString *out = [NSMutableString string];
        [g_results enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
            NSString *title = (idx < g_results.count) ? g_results[idx] : @"";
            [out appendFormat:@"--- %@ ---\n%@\n\n", title, obj];
        }];

        [UIPasteboard generalPasteboard].string = out;
        EKHideDebugOverlay();

        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"提取完成"
                                            message:@"所有详情已复制到剪贴板。"
                                     preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

        g_isExtracting = NO;
        g_results      = nil;
        g_workQueue    = nil;
        return;
    }

    // ---- 取出下一项 ----
    EKWorkItem *item = g_workQueue.firstObject;
    [g_workQueue removeObjectAtIndex:0];

    // ★★★ 核心修正：让控制器知道“当前传视图” ★★★
    Ivar ivCoursan = class_getInstanceVariable([self class], "課傳");
    if (ivCoursan) object_setIvar(self, ivCoursan, item.sender);

    // 更新 Debug Overlay
    EKUpdateDebugText([NSString stringWithFormat:@"[%lu/%lu] %@", (unsigned long)(g_results.count+1),
                       (unsigned long)(g_results.count + 1 + g_workQueue.count), item.title]);

    // 调用正确的 selector
    SEL sel = (item.type == EKWorkTypeDiZhi)
              ? NSSelectorFromString(@"顯示課傳摘要WithSender:")
              : NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    if ([self respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:sel withObject:item.sender];
#pragma clang diagnostic pop
    } else {
        // 万一方法名变化，跳过
        [self ek_processQueue];
    }
}

@end
