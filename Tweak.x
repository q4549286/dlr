#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助结构
// =========================================================================
typedef NS_ENUM(NSUInteger, EKWorkType) {
    EKWorkTypeDiZhi,
    EKWorkTypeTianJiang,
};

@interface EKWorkItem : NSObject
@property (nonatomic, weak)   UIView   *sender;   ///< 直接传 *初傳/中傳/末傳* 的 UIView
@property (nonatomic, assign) EKWorkType type;    ///< 地支 / 天将
@property (nonatomic, copy)   NSString *title;    ///< 结果段落标题
@end

@implementation EKWorkItem @end

static BOOL g_isExtracting   = NO;
static NSMutableArray<NSString *> *g_results     = nil;
static NSMutableArray<EKWorkItem *> *g_workQueue = nil;

// 递归收集指定 class 的子视图
static void FindSubviewsRecursive(Class cls, UIView *view, NSMutableArray *out) {
    if ([view isKindOfClass:cls]) { [out addObject:view]; }
    for (UIView *sub in view.subviews) { FindSubviewsRecursive(cls, sub, out); }
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)performKeChuanDetailExtraction_Truth;
- (void)ek_processQueue;
@end

%hook UIViewController

// -------------------------------------------------------------------------
// viewDidLoad：给“六壬大占.ViewController”加一个测试按钮
// -------------------------------------------------------------------------
- (void)viewDidLoad {
    %orig;

    Class targetCls = NSClassFromString(@"六壬大占.ViewController");
    if (!targetCls || ![self isKindOfClass:targetCls]) { return; }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = self.view.window;
        if (!keyWindow) { return; }

        const NSInteger kBtnTag = 556690;
        [[keyWindow viewWithTag:kBtnTag] removeFromSuperview];

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame               = CGRectMake(keyWindow.bounds.size.width - 150, 125, 140, 36);
        btn.tag                 = kBtnTag;
        btn.layer.cornerRadius  = 8;
        btn.backgroundColor     = [UIColor systemGreenColor];
        btn.titleLabel.font     = [UIFont boldSystemFontOfSize:16];
        [btn setTitle:@"课传提取(谢罪版)" forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [btn addTarget:self
                action:@selector(performKeChuanDetailExtraction_Truth)
      forControlEvents:UIControlEventTouchUpInside];
        [keyWindow addSubview:btn];
    });
}

// -------------------------------------------------------------------------
// presentViewController：拦截“課傳摘要視圖 / 天將摘要視圖”，抓取文本
// -------------------------------------------------------------------------
- (void)presentViewController:(UIViewController *)vc
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion {

    if (g_isExtracting) {
        NSString *clsName = NSStringFromClass([vc class]);
        BOOL isKeChuan   = ([clsName containsString:@"課傳摘要視圖"] ||
                            [clsName containsString:@"天將摘要視圖"]);

        if (isKeChuan) {
            vc.view.alpha = 0;   // 隐藏原弹窗
            flag          = NO;

            __weak typeof(self) weakSelf = self;
            void (^wrap)(void) = ^{
                if (completion) completion();

                // 把弹窗里所有 UILabel 的文字拼起来
                NSMutableArray *labels = [NSMutableArray array];
                FindSubviewsRecursive([UILabel class], vc.view, labels);
                [labels sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
                    if (fabs(a.frame.origin.y - b.frame.origin.y) > 0.5)
                        return a.frame.origin.y < b.frame.origin.y ? NSOrderedAscending : NSOrderedDescending;
                    return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
                }];

                NSMutableArray *parts = [NSMutableArray array];
                for (UILabel *lb in labels) {
                    if (lb.text.length) {
                        [parts addObject:[lb.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                [g_results addObject:[parts componentsJoinedByString:@"\n"]];

                // 关掉弹窗，再处理下一项（稍稍延时，保证动画完全结束）
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
// 点击按钮 → 构建队列
// -------------------------------------------------------------------------
- (void)performKeChuanDetailExtraction_Truth {

    if (g_isExtracting) return;              // 防止重复点击
    g_isExtracting   = YES;
    g_results        = [NSMutableArray array];
    g_workQueue      = [NSMutableArray array];

    // ======== Part A: 三传 ========
    Class containerCls = NSClassFromString(@"六壬大占.三傳視圖");
    if (containerCls) {
        NSMutableArray *containers = [NSMutableArray array];
        FindSubviewsRecursive(containerCls, self.view, containers);
        if (containers.count) {
            UIView *container = containers.firstObject;

            // 用正确的繁体 ivar 名
            const char *ivarNames[] = {"初傳", "中傳", "末傳", NULL};
            NSString   *rowTitles[] = {@"初传", @"中传", @"末传"};

            for (int i = 0; ivarNames[i]; ++i) {
                Ivar ivar = class_getInstanceVariable(containerCls, ivarNames[i]);
                if (!ivar) continue;

                UIView *rowView = object_getIvar(container, ivar);
                if (!rowView) continue;

                // 取一下 rowView 里右侧两个 UILabel，只是为了做标题展示
                NSMutableArray *lbls = [NSMutableArray array];
                FindSubviewsRecursive([UILabel class], rowView, lbls);
                [lbls sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
                    return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
                }];
                NSString *dizhiTxt   = lbls.count >= 2 ? ((UILabel *)lbls[lbls.count-2]).text : @"?";
                NSString *tianJTxt   = lbls.count >= 1 ? ((UILabel *)lbls.lastObject).text     : @"?";

                // 1) 地支
                EKWorkItem *di = [EKWorkItem new];
                di.sender = rowView;
                di.type   = EKWorkTypeDiZhi;
                di.title  = [NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiTxt ?: @"?"];
                [g_workQueue addObject:di];

                // 2) 天将
                EKWorkItem *tj = [EKWorkItem new];
                tj.sender = rowView;
                tj.type   = EKWorkTypeTianJiang;
                tj.title  = [NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianJTxt ?: @"?"];
                [g_workQueue addObject:tj];
            }
        }
    }

    // ======== Part B: 四课（如需，后续可补） ========

    if (!g_workQueue.count) {
        g_isExtracting = NO;
        return;
    }
    [self ek_processQueue];
}


// -------------------------------------------------------------------------
// 处理队列
// -------------------------------------------------------------------------
- (void)ek_processQueue {

    if (!g_workQueue.count) {
        // -------- 全部完成：拼字符串 + 复制剪贴板 --------
        NSMutableString *out = [NSMutableString string];
        [g_results enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
            NSString *title = idx < g_workQueue.count ? @"" : g_workQueue[idx].title; // 理论上匹配
            [out appendFormat:@"--- %@ ---\n%@\n\n", title, obj];
        }];

        [UIPasteboard generalPasteboard].string = out;
        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"提取完成"
                                            message:@"所有详情已复制到剪贴板。"
                                     preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

        // 清理
        g_isExtracting = NO;
        g_results      = nil;
        g_workQueue    = nil;
        return;
    }

    // -------- 取出下一项并触发 --------
    EKWorkItem *item = g_workQueue.firstObject;
    [g_workQueue removeObjectAtIndex:0];

    SEL sel = (item.type == EKWorkTypeDiZhi)
              ? NSSelectorFromString(@"顯示課傳摘要WithSender:")
              : NSSelectorFromString(@"顯示課傳天將摘要WithSender:");

    if ([self respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:sel withObject:item.sender];
#pragma clang diagnostic pop
    } else {
        // 万一方法名变化，直接跳过
        [self ek_processQueue];
    }
}

@end
