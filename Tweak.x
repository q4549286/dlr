#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// ---------------------------------------------------------------------
// 1. 全局状态变量 & 辅助
// ---------------------------------------------------------------------
static BOOL g_isExtractingKeChuan = NO;
static NSMutableArray *g_workQueue   = nil;   // 存待点的 sender
static NSMutableArray *g_titleQueue  = nil;   // ⬆︎ 对应标题
static NSMutableArray *g_resultQueue = nil;   // 最终文本

static NSMutableSet   *g_seenTitles  = nil;   // 用于彻底去重
static NSInteger       g_emptyCount  = 0;     // 连续空读计数

static void EchoFindSubviews(Class clazz, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:clazz]) { [storage addObject:view]; }
    for (UIView *sub in view.subviews) { EchoFindSubviews(clazz, sub, storage); }
}

// ---------------------------------------------------------------------
// 2. UIViewController 分类声明
// ---------------------------------------------------------------------
@interface UIViewController (KeChuanExtractor)
- (void)kc_startExtraction;
- (void)kc_processNext;
@end

// ---------------------------------------------------------------------
// 3. Hook UIViewController
// ---------------------------------------------------------------------
%hook UIViewController

// ── 3-1. 在六壬主界面插一颗按钮 ───────────────────────────────
- (void)viewDidLoad {
    %orig;
    Class mainVC = NSClassFromString(@"六壬大占.ViewController");
    if (![self isKindOfClass:mainVC]) return;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindow *w = self.view.window;  if (!w) return;
        NSInteger tag = 556690;
        [[w viewWithTag:tag] removeFromSuperview];
        
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(w.bounds.size.width - 150, 125, 140, 36);
        btn.tag   = tag;
        btn.layer.cornerRadius = 8;
        btn.backgroundColor = [UIColor systemGreenColor];
        [btn setTitle:@"课传提取" forState:UIControlStateNormal];
        [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(kc_startExtraction)
          forControlEvents:UIControlEventTouchUpInside];
        [w addSubview:btn];
    });
}

// ── 3-2. 拦截呈现课传弹窗，延迟 0.25 s 后抓取文本 ────────────
- (void)presentViewController:(UIViewController *)vc
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion {
    
    if (g_isExtractingKeChuan) {
        NSString *cls = NSStringFromClass([vc class]);
        if ([cls containsString:@"課傳摘要視圖"] || [cls containsString:@"天將摘要視圖"]) {
            
            // 让弹窗完全透明 & 非动画呈现
            vc.view.alpha = 0.0;
            flag = NO;
            
            void (^newCompletion)(void) = ^{
                if (completion) completion();
                
                // 延迟 0.25 s，等内部 layout 完毕
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    NSMutableArray *labels = [NSMutableArray array];
                    EchoFindSubviews([UILabel class], vc.view, labels);
                    [labels sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
                        if (a.frame.origin.y != b.frame.origin.y)
                            return a.frame.origin.y < b.frame.origin.y ? NSOrderedAscending : NSOrderedDescending;
                        return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
                    }];
                    
                    // 拼文本
                    NSMutableArray *parts = [NSMutableArray array];
                    for (UILabel *l in labels) {
                        if (l.text.length) [parts addObject:[l.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                    NSString *detail = [parts componentsJoinedByString:@"\n"];
                    
                    // 保存
                    [g_resultQueue addObject:detail.length ? detail : @"[读取失败]"];
                    if (!detail.length) g_emptyCount++; else g_emptyCount = 0;
                    
                    // 关弹窗 & 继续
                    [vc dismissViewControllerAnimated:NO completion:^{
                        [self kc_processNext];
                    }];
                });
            };
            
            %orig(vc, flag, newCompletion);
            return;
        }
    }
    
    %orig(vc, flag, completion);
}

%end  // UIViewController

// ---------------------------------------------------------------------
// 4. 分类实现
// ---------------------------------------------------------------------
@implementation UIViewController (KeChuanExtractor)

// ── 4-1. 点击按钮的入口 ──────────────────────────────────────
- (void)kc_startExtraction {
    if (g_isExtractingKeChuan) return;
    g_isExtractingKeChuan = YES;
    
    g_workQueue   = [NSMutableArray array];
    g_titleQueue  = [NSMutableArray array];
    g_resultQueue = [NSMutableArray array];
    g_seenTitles  = [NSMutableSet set];
    g_emptyCount  = 0;
    
    // (A) 把三传视图里的地支 / 天将 label 探出来按顺序塞进队列
    Class containerCls = NSClassFromString(@"六壬大占.三傳視圖");
    if (containerCls) {
        NSMutableArray *containers = [NSMutableArray array];
        EchoFindSubviews(containerCls, self.view, containers);
        if (containers.count) {
            UIView *box = containers.firstObject;
            
            const char *ivars[]   = {"初傳", "中傳", "末傳", NULL};
            NSString   *titles[]  = {@"初传", @"中传", @"末传"};
            
            for (int i = 0; ivars[i]; i++) {
                Ivar ivar = class_getInstanceVariable(containerCls, ivars[i]);
                if (!ivar) continue;
                
                UIView *rowView = object_getIvar(box, ivar);
                if (!rowView) continue;
                
                NSMutableArray *lbls = [NSMutableArray array];
                EchoFindSubviews([UILabel class], rowView, lbls);
                [lbls sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
                    return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
                }];
                if (lbls.count < 2) continue;
                
                UILabel *dz = lbls[lbls.count - 2];
                UILabel *tj = lbls.lastObject;
                
                // 先 push 地支
                [g_workQueue  addObject:dz];
                [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", titles[i], dz.text]];
                
                // 再 push 天将
                [g_workQueue  addObject:tj];
                [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", titles[i], tj.text]];
            }
        }
    }
    
    if (!g_workQueue.count) { g_isExtractingKeChuan = NO; return; }
    [self kc_processNext];
}

// ── 4-2. 依次点击 label → 抓数据 ────────────────────────────
- (void)kc_processNext {
    
    // 出现连续 3 个空文本或队列空，就结束
    if (!g_workQueue.count || g_emptyCount >= 3) {
        NSMutableString *final = [NSMutableString string];
        for (NSUInteger i = 0; i < g_titleQueue.count; i++) {
            NSString *t = g_titleQueue[i];
            NSString *d = i < g_resultQueue.count ? g_resultQueue[i] : @"[未取得]";
            [final appendFormat:@"--- %@ ---\n%@\n\n", t, d];
        }
        [UIPasteboard generalPasteboard].string = final;
        
        UIAlertController *ok = [UIAlertController alertControllerWithTitle:@"提取完成"
                                                                   message:@"内容已复制到剪贴板"
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [ok addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:ok animated:YES completion:nil];
        
        // 复位
        g_isExtractingKeChuan = NO;
        g_workQueue = g_titleQueue = g_resultQueue = nil;
        g_seenTitles = nil;
        return;
    }
    
    UILabel *lbl = g_workQueue.firstObject;
    [g_workQueue removeObjectAtIndex:0];
    
    NSString *title = g_titleQueue[g_resultQueue.count];
    if ([g_seenTitles containsObject:title]) {   // 安全保险，理论不会走到
        [self kc_processNext];
        return;
    }
    [g_seenTitles addObject:title];
    
    SEL sel = [title containsString:@"地支"]
            ? NSSelectorFromString(@"顯示課傳摘要WithSender:")
            : NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    
    if ([self respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:sel withObject:lbl];
#pragma clang diagnostic pop
    } else {
        [self kc_processNext];
    }
}

@end
