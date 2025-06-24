#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - 数据结构 & 全局

typedef NS_ENUM(NSUInteger, EKWorkType) { EKWorkTypeDiZhi, EKWorkTypeTianJiang };

@interface EKWorkItem : NSObject
@property (nonatomic, weak)   UIView   *sender;   ///< 传视图 (初/中/末)
@property (nonatomic, assign) EKWorkType type;    ///< 地支 / 天将
@property (nonatomic, copy)   NSString *title;    ///< 标题
@end
@implementation EKWorkItem @end

static BOOL                          g_running   = NO;
static NSMutableArray<EKWorkItem *> *g_queue     = nil;
static NSMutableArray<NSString *>   *g_results   = nil;

#pragma mark - Debug Overlay（可拖动）

static UIWindow *dbgWin = nil;
static UILabel  *dbgLbl = nil;

static void dbg_show(void) {
    if (dbgWin) return;

    UIWindow *hostWin = UIApplication.sharedApplication.connectedScenes.allObjects.firstObject ?
                        ((UIWindowScene *)UIApplication.sharedApplication.connectedScenes.allObjects.firstObject).windows.firstObject :
                        UIApplication.sharedApplication.windows.firstObject;

    CGFloat width = hostWin ? hostWin.bounds.size.width : UIScreen.mainScreen.bounds.size.width;
    dbgWin = [[UIWindow alloc] initWithFrame:CGRectMake(0, 60, width, 24)];
    dbgWin.windowLevel     = UIWindowLevelAlert + 2;
    dbgWin.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];

    dbgLbl                 = [[UILabel alloc] initWithFrame:dbgWin.bounds];
    dbgLbl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    dbgLbl.font            = [UIFont boldSystemFontOfSize:12];
    dbgLbl.textColor       = UIColor.yellowColor;
    dbgLbl.textAlignment   = NSTextAlignmentCenter;
    [dbgWin addSubview:dbgLbl];

    // 允许上下拖动
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] init];
    [pan addTarget:dbgWin action:@selector(handlePan:)];
    [dbgWin addGestureRecognizer:pan];

    dbgWin.hidden = NO;
}

static void dbg_update(NSUInteger done, NSUInteger total, NSString *title) {
    dbg_show();
    dbgLbl.text = [NSString stringWithFormat:@"[%lu/%lu] %@", (unsigned long)done, (unsigned long)total, title];
}

static void dbg_hide(void) { dbgWin.hidden = YES; dbgWin = nil; dbgLbl = nil; }

#pragma mark - 工具函数

static void findSubviews(Class cls, UIView *v, NSMutableArray *out) {
    if ([v isKindOfClass:cls]) [out addObject:v];
    for (UIView *sub in v.subviews) findSubviews(cls, sub, out);
}

#pragma mark - 主逻辑

@interface UIViewController (EKAddons)
- (void)ek_startExtraction;
- (void)ek_next;
- (void)handlePan:(UIPanGestureRecognizer *)pan;   ///< Debug Overlay 拖动
@end

%hook UIViewController

// 给“六壬大占.ViewController”加按钮
- (void)viewDidLoad {
    %orig;

    if (![self isKindOfClass:NSClassFromString(@"六壬大占.ViewController")]) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindow *w = self.view.window ?: UIApplication.sharedApplication.windows.firstObject;
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(w.bounds.size.width - 150, 120, 140, 32);
        btn.layer.cornerRadius = 6;
        btn.backgroundColor = UIColor.systemGreenColor;
        [btn setTitle:@"课传提取(谢罪版)" forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(ek_startExtraction) forControlEvents:UIControlEventTouchUpInside];
        [w addSubview:btn];
    });
}

// 拦截课传弹窗抓取内容
- (void)presentViewController:(UIViewController *)vc
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion {

    if (!g_running) { %orig(vc, flag, completion); return; }

    NSString *cls = NSStringFromClass([vc class]);
    if (![cls containsString:@"課傳摘要視圖"] &&
        ![cls containsString:@"課傳天將摘要視圖"]) {
        %orig(vc, flag, completion);
        return;
    }

    vc.view.alpha = 0;   // 隐藏
    flag = NO;

    __weak typeof(self) ws = self;
    void (^wrap)(void) = ^{
        if (completion) completion();

        // 抓取所有 UILabel
        NSMutableArray *lbs = [NSMutableArray array];
        findSubviews([UILabel class], vc.view, lbs);
        [lbs sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
            if (fabs(a.frame.origin.y - b.frame.origin.y) > 0.5)
                return a.frame.origin.y < b.frame.origin.y ? NSOrderedAscending : NSOrderedDescending;
            return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
        }];
        NSMutableArray *parts = [NSMutableArray array];
        for (UILabel *lb in lbs)
            if (lb.text.length)
                [parts addObject:[lb.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];

        [g_results addObject:[parts componentsJoinedByString:@"\n"]];

        [vc dismissViewControllerAnimated:NO completion:^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [ws ek_next];
            });
        }];
    };

    %orig(vc, flag, wrap);
}
%end

@implementation UIViewController (EKAddons)

#pragma mark Debug Overlay 拖动
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint p = [pan locationInView:dbgWin.superview ?: UIApplication.sharedApplication.windows.firstObject];
    dbgWin.center = CGPointMake(dbgWin.center.x, p.y);
}

#pragma mark 构建队列并开始
- (void)ek_startExtraction {
    if (g_running) return;
    g_running = YES;
    g_queue   = [NSMutableArray array];
    g_results = [NSMutableArray array];

    // ======== 三传 ========
    Class boxCls = NSClassFromString(@"六壬大占.三傳視圖");
    NSMutableArray *boxes = [NSMutableArray array];
    findSubviews(boxCls, self.view, boxes);
    if (!boxes.count) { g_running = NO; return; }

    UIView *box = boxes.firstObject;
    const char *ivn[] = {"初傳", "中傳", "末傳", NULL};
    NSString   *rt[]  = {@"初传", @"中传", @"末传"};

    for (int i = 0; ivn[i]; ++i) {
        Ivar iv = class_getInstanceVariable(boxCls, ivn[i]);
        if (!iv) continue;
        UIView *row = object_getIvar(box, iv);
        if (!row) continue;

        NSMutableArray *lbls = [NSMutableArray array];
        findSubviews([UILabel class], row, lbls);
        [lbls sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
            return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
        }];
        NSString *dz = lbls.count >= 2 ? ((UILabel *)lbls[lbls.count - 2]).text : @"?";
        NSString *tj = lbls.count >= 1 ? ((UILabel *)lbls.lastObject).text      : @"?";

        EKWorkItem *di = [EKWorkItem new];
        di.sender = row; di.type = EKWorkTypeDiZhi;
        di.title  = [NSString stringWithFormat:@"%@-地支(%@)", rt[i], dz];
        [g_queue addObject:di];

        EKWorkItem *tjw = [EKWorkItem new];
        tjw.sender = row; tjw.type = EKWorkTypeTianJiang;
        tjw.title  = [NSString stringWithFormat:@"%@-天将(%@)", rt[i], tj];
        [g_queue addObject:tjw];
    }

    dbg_show();
    [self ek_next];
}

#pragma mark 处理队列
- (void)ek_next {
    if (!g_queue.count) {
        dbg_hide();

        NSMutableString *out = [NSMutableString string];
        for (NSUInteger i = 0; i < g_results.count; i++) {
            NSString *title = i < g_results.count ? g_queue[i].title : @"";
            [out appendFormat:@"--- %@ ---\n%@\n\n", title, g_results[i]];
        }
        [UIPasteboard generalPasteboard].string = out;

        UIAlertController *a =
        [UIAlertController alertControllerWithTitle:@"提取完成"
                                            message:@"所有详情已复制到剪贴板。"
                                     preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:a animated:YES completion:nil];

        g_running = NO; g_queue = nil; g_results = nil;
        return;
    }

    EKWorkItem *it = g_queue.firstObject;
    [g_queue removeObjectAtIndex:0];
    dbg_update(g_results.count + 1, g_results.count + 1 + g_queue.count, it.title);

    // 设置 self->課傳
    Ivar courseIvar = class_getInstanceVariable([self class], "課傳");
    if (courseIvar) object_setIvar(self, courseIvar, it.sender);

    SEL sel = (it.type == EKWorkTypeDiZhi)
              ? NSSelectorFromString(@"顯示課傳摘要WithSender:")
              : NSSelectorFromString(@"顯示課傳天將摘要WithSender:");

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if ([self respondsToSelector:sel])
        [self performSelector:sel withObject:it.sender];
    else
        [self ek_next];   // 不存在就跳过
#pragma clang diagnostic pop
}

@end
