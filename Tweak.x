#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =====================================
// 0. 公共宏 / 日志
// =====================================
#define EchoLog(fmt, ...) NSLog(@"[EchoAI-KeChuanFix] " fmt, ##__VA_ARGS__)
#define WEAKSELF typeof(self) __weak weakSelf = self
#define STR_NOT_NULL(s) ((s) ? (s) : @"")

// =====================================
// 1. 全局状态
// =====================================
static BOOL g_isExtracting = NO;                              ///< 是否处于提取流程中
static NSMutableArray<NSDictionary *> *g_taskQueue = nil;    ///< [{label,title,selector}]
static NSMutableDictionary<NSString *, NSString *> *g_taskResults = nil;   ///< title->detail
static UILabel *g_currentLabel = nil;                        ///< 正在处理的 label
static NSString *g_currentTitle = nil;                       ///< 正在处理的标题

// 为 UILabel 打一个“已处理”标记的关联 key
static char kProcessedFlagKey;

// =====================================
// 2. 辅助函数
// =====================================
static void FindSubviewsRecursive(Class cls, UIView *view, NSMutableArray *dst)
{
    if ([view isKindOfClass:cls]) [dst addObject:view];
    for (UIView *sub in view.subviews) FindSubviewsRecursive(cls, sub, dst);
}

// 把 UILabel.text 按 y->x 排，输出 @"\n" 分隔
static NSString *ExtractTextFromView(UIView *container)
{
    NSMutableArray<UILabel *> *labels = [NSMutableArray array];
    FindSubviewsRecursive([UILabel class], container, labels);
    [labels sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
        if (roundf(a.frame.origin.y) != roundf(b.frame.origin.y))
            return a.frame.origin.y < b.frame.origin.y ? NSOrderedAscending : NSOrderedDescending;
        return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
    }];
    
    NSMutableArray *parts = [NSMutableArray array];
    for (UILabel *l in labels)
        if (l.text.length) [parts addObject:[l.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
    return [parts componentsJoinedByString:@"\n"];
}

// =====================================
// 3. UIViewController Category（核心功能）
// =====================================
@interface UIViewController (Echo_KC)
- (void)kc_buildTaskQueue;
- (void)kc_processNextTask;
@end

%hook UIViewController

// --------------------------------------------------
// 3-1 创建“课传提取(谢罪版)”按钮
// --------------------------------------------------
- (void)viewDidLoad
{
    %orig;
    Class targetCls = NSClassFromString(@"六壬大占.ViewController");
    if (!targetCls || ![self isKindOfClass:targetCls]) return;
    
    WEAKSELF;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *w = weakSelf.view.window;
        if (!w) return;
        const NSInteger tag = 556690;
        [[w viewWithTag:tag] removeFromSuperview];
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(w.bounds.size.width-150, 45+80, 140, 36);
        btn.tag = tag;
        btn.layer.cornerRadius = 8;
        btn.backgroundColor = [UIColor systemGreenColor];
        [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [btn setTitle:@"课传提取(谢罪版)" forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        [btn addTarget:weakSelf action:@selector(kc_buildTaskQueue) forControlEvents:UIControlEventTouchUpInside];
        [w addSubview:btn];
    });
}

// --------------------------------------------------
// 3-2 presentViewController:  — 捕捉弹出的摘要视图
// --------------------------------------------------
- (void)presentViewController:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))completion
{
    // 仅在提取流程中，且是我们“下一条任务”触发的弹窗时才拦截
    if (g_isExtracting
        && g_currentLabel
        && ( [NSStringFromClass(vc.class) containsString:@"課傳摘要"]
           || [NSStringFromClass(vc.class) containsString:@"天將摘要"] ) )
    {
        // 拦截
        vc.view.alpha = 0; flag = NO;
        
        void (^afterCapture)(void) = ^{
            // 提取文本
            NSString *detail = ExtractTextFromView(vc.view);
            if (detail.length) g_taskResults[g_currentTitle] = detail;
            
            // 关闭弹窗并继续
            [vc dismissViewControllerAnimated:NO completion:^{
                g_currentLabel = nil; g_currentTitle = nil;
                [self kc_processNextTask];
            }];
        };
        
        %orig(vc, flag, afterCapture);
        return;
    }
    
    // 其它情况照常
    %orig(vc, flag, completion);
}

// --------------------------------------------------
// 3-3 构建任务队列（点击按钮触发）
// --------------------------------------------------
%new
- (void)kc_buildTaskQueue
{
    if (g_isExtracting) { EchoLog(@"提取进行中，忽略重复点击"); return; }
    
    g_isExtracting   = YES;
    g_taskQueue      = [NSMutableArray array];
    g_taskResults    = [NSMutableDictionary dictionary];
    
    // ---------- 找到“三传视图” ----------
    Class containerCls = NSClassFromString(@"六壬大占.三傳視圖");
    if (!containerCls) { EchoLog(@"找不到『三傳視圖』类"); g_isExtracting = NO; return; }
    
    NSMutableArray *containers = [NSMutableArray array];
    FindSubviewsRecursive(containerCls, self.view, containers);
    if (!containers.count) { EchoLog(@"未找到三傳容器"); g_isExtracting = NO; return; }
    
    UIView *scContainer = containers.firstObject;
    
    // 正确的 ivar 名
    const char *ivars[] = {"初傳","中傳","末傳", NULL};
    NSString  *rowNames[] = {@"初传", @"中传", @"末传"};
    
    for (int i = 0; ivars[i]; ++i) {
        Ivar iv = class_getInstanceVariable(containerCls, ivars[i]);
        if (!iv) continue;
        UIView *chuanView = object_getIvar(scContainer, iv);
        if (!chuanView) continue;
        
        // 取 view 里所有 label，x 顺序排
        NSMutableArray<UILabel *> *lbls = [NSMutableArray array];
        FindSubviewsRecursive([UILabel class], chuanView, lbls);
        [lbls sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
            return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
        }];
        if (lbls.count < 2) continue;
        
        // 倒数第二=地支，最后=天将
        UILabel *dz = lbls[lbls.count-2];
        UILabel *tj = lbls.lastObject;
        
        // 入队（地支）
        [g_taskQueue addObject:@{
            @"label": dz,
            @"title": [NSString stringWithFormat:@"%@ - 地支(%@)", rowNames[i], STR_NOT_NULL(dz.text)],
            @"selector": NSStringFromSelector(NSSelectorFromString(@"顯示課傳摘要WithSender:"))
        }];
        // 入队（天将）
        [g_taskQueue addObject:@{
            @"label": tj,
            @"title": [NSString stringWithFormat:@"%@ - 天将(%@)", rowNames[i], STR_NOT_NULL(tj.text)],
            @"selector": NSStringFromSelector(NSSelectorFromString(@"顯示課傳天將摘要WithSender:"))
        }];
    }
    
    if (!g_taskQueue.count) { EchoLog(@"任务队列为空"); g_isExtracting = NO; return; }
    
    [self kc_processNextTask];
}

// --------------------------------------------------
// 3-4 逐条执行任务
// --------------------------------------------------
%new
- (void)kc_processNextTask
{
    if (!g_taskQueue.count) {
        // 完成：整理结果 -> 复制剪贴板 -> 弹框
        NSMutableString *final = [NSMutableString string];
        for (NSDictionary *task in g_taskResults) { /* 保留原顺序 */
            NSString *title = task.key;
            NSString *detail = g_taskResults[title] ?: @"[信息提取失败]";
            [final appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = final;
        
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"提取完成"
                                                                   message:@"已复制到剪贴板"
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
        
        // 清理
        g_isExtracting = NO;
        g_taskQueue = nil;
        g_taskResults = nil;
        return;
    }
    
    // 取下一条
    NSDictionary *task = g_taskQueue.firstObject;
    [g_taskQueue removeObjectAtIndex:0];
    
    UILabel *label      = task[@"label"];
    NSString *selString = task[@"selector"];
    g_currentLabel  = label;
    g_currentTitle  = task[@"title"];
    
    // 已经点过的 label 直接跳过
    if (objc_getAssociatedObject(label, &kProcessedFlagKey)) {
        EchoLog(@"%@ 已处理过，自动跳过", g_currentTitle);
        g_currentLabel = nil; g_currentTitle = nil;
        [self kc_processNextTask];
        return;
    }
    objc_setAssociatedObject(label, &kProcessedFlagKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    // 调用 selector
    SEL sel = NSSelectorFromString(selString);
    if (![self respondsToSelector:sel]) {
        EchoLog(@"%@ 不响应 %@", self, selString);
        g_currentLabel = nil; g_currentTitle = nil;
        [self kc_processNextTask];
        return;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:sel withObject:label];
#pragma clang diagnostic pop
    
    // 若 3 秒内仍未捕获弹窗，则自动继续下一条，避免卡死
    WEAKSELF;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (g_currentLabel) {   // 仍未清空 => 弹窗没出现
            EchoLog(@"%@ 超时，自动跳过", g_currentTitle);
            g_currentLabel = nil; g_currentTitle = nil;
            [weakSelf kc_processNextTask];
        }
    });
}

%end   // UIViewController
