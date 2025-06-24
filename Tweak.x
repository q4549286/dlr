#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 0. 统一日志宏
// =========================================================================
#define EchoLog(fmt, ...) NSLog((@"[EchoAI] " fmt), ##__VA_ARGS__)

// =========================================================================
// 1. 全局变量 & 辅助函数
// =========================================================================
static NSInteger const kCombinedButtonTag = 112244;
static NSInteger const kProgressViewTag   = 556677;

static BOOL g_isExtractingKeChuanDetail      = NO;
static NSMutableArray<NSDictionary *> *g_keChuanTaskQueue        = nil;
static NSMutableArray<NSString *>     *g_keChuanTitleQueue       = nil;
static NSMutableArray<NSString *>     *g_capturedKeChuanDetail   = nil;

static NSMutableDictionary            *g_extractedData           = nil;
static BOOL                            g_isExtractingNianming    = NO;
static NSString                       *g_currentItemToExtract    = nil;
static NSMutableArray                 *g_capturedZhaiYaoArray    = nil;
static NSMutableArray                 *g_capturedGeJuArray       = nil;

static inline NSSet *BranchesSet(void) {
    static NSSet *set; static dispatch_once_t once; dispatch_once(&once, ^{
        set = [NSSet setWithArray:@[@"子",@"丑",@"寅",@"卯",@"辰",@"巳",@"午",@"未",@"申",@"酉",@"戌",@"亥"]];
    }); return set;
}
static inline NSSet *GeneralsSet(void) {
    static NSSet *set; static dispatch_once_t once; dispatch_once(&once, ^{
        set = [NSSet setWithArray:@[@"青龍",@"朱雀",@"勾陳",@"螣蛇",@"白虎",@"玄武",@"六合",@"天后",@"天空",@"太常",@"太陰"]];
    }); return set;
}

static void FindSubviewsOfClassRecursive(Class cls, UIView *view, NSMutableArray *store) {
    if ([view isKindOfClass:cls]) { [store addObject:view]; }
    for (UIView *sub in view.subviews) { FindSubviewsOfClassRecursive(cls, sub, store); }
}

static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *color, CGSize tile, CGFloat angle) {
    UIGraphicsBeginImageContextWithOptions(tile, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, tile.width/2, tile.height/2);
    CGContextRotateCTM(ctx, angle * M_PI/180.0);
    [text drawInRect:CGRectMake(-tile.width, -tile.height, tile.width*2, tile.height*2)
       withAttributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:color}];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

static UIGestureRecognizer *FindGesture(UIView *v, NSString *suffix) {
    for (UIGestureRecognizer *gr in v.gestureRecognizers) {
        if ([NSStringFromClass([gr class]) hasSuffix:suffix]) return gr;
    }
    return nil;
}

// =========================================================================
// 2. UI 细节 Hooks  (UILabel / UIWindow)
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text {
    if (!text) { %orig(text); return; }
    NSString *new = nil;
    if ([text isEqualToString:@"我的分类"]||[text isEqualToString:@"我的分類"]||[text isEqualToString:@"通類"]) new=@"Echo";
    else if ([text isEqualToString:@"起課"]||[text isEqualToString:@"起课"]) new=@"定制";
    else if ([text isEqualToString:@"法诀"]||[text isEqualToString:@"法訣"]) new=@"毕法";
    if (new) { %orig(new); return; }
    NSMutableString *simp=[text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simp,NULL,CFSTR("Hant-Hans"),false);
    %orig(simp);
}
%end

%hook UIWindow
- (void)layoutSubviews {
    %orig;
    if (self.windowLevel!=UIWindowLevelNormal) return;
    NSInteger tag=998877;
    if ([self viewWithTag:tag]) return;
    UIImage *pattern=createWatermarkImage(@"Echo定制",[UIFont systemFontOfSize:16],[[UIColor blackColor] colorWithAlphaComponent:0.12],CGSizeMake(150,100),-30);
    UIView *wm=[[UIView alloc] initWithFrame:self.bounds];
    wm.tag=tag; wm.userInteractionEnabled=NO; wm.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    wm.backgroundColor=[UIColor colorWithPatternImage:pattern];
    [self addSubview:wm];
}
%end

// =========================================================================
// 3. UIViewController 主功能（仅展示课传相关完整实现）
// =========================================================================
@interface UIViewController (EchoKeChuan)
- (void)performKeChuanDetailExtractionTest_Truth;
- (void)processKeChuanQueue_Truth;
@end

%hook UIViewController

// --- 注入入口按钮
- (void)viewDidLoad {
    %orig;
    Class rootCls = NSClassFromString(@"六壬大占.ViewController");
    if (rootCls && [self isKindOfClass:rootCls]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            UIWindow *win=self.view.window; if (!win) return;
            if ([win viewWithTag:kCombinedButtonTag]) [[win viewWithTag:kCombinedButtonTag] removeFromSuperview];
            UIButton *btn=[UIButton buttonWithType:UIButtonTypeSystem];
            btn.tag=kCombinedButtonTag;
            btn.frame=CGRectMake(win.bounds.size.width-150,45+80,140,36);
            btn.layer.cornerRadius=8;
            btn.backgroundColor=[UIColor systemGreenColor];
            [btn setTitle:@"课传提取" forState:UIControlStateNormal];
            [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
            btn.titleLabel.font=[UIFont boldSystemFontOfSize:16];
            [btn addTarget:self action:@selector(performKeChuanDetailExtractionTest_Truth) forControlEvents:UIControlEventTouchUpInside];
            [win addSubview:btn];
        });
    }
}

// --- 队列驱动: sender=手势对象
%new
- (void)performKeChuanDetailExtractionTest_Truth {
    g_isExtractingKeChuanDetail=YES;
    g_capturedKeChuanDetail=[NSMutableArray array];
    g_keChuanTitleQueue=[NSMutableArray array];
    g_keChuanTaskQueue=[NSMutableArray array];

    Class BoxCls=NSClassFromString(@"六壬大占.三傳視圖");
    if (!BoxCls){ g_isExtractingKeChuanDetail=NO; return; }

    NSMutableArray *boxes=[NSMutableArray array];
    FindSubviewsOfClassRecursive(BoxCls, self.view, boxes);
    if (boxes.count==0){ g_isExtractingKeChuanDetail=NO; return; }
    UIView *box=boxes.firstObject;

    const char *ivars[]={"初傳","中傳","末傳",NULL};
    NSString *rows[]   ={@"初传",@"中传",@"末传"};

    for (int i=0; ivars[i]; ++i) {
        Ivar var=class_getInstanceVariable(BoxCls, ivars[i]);
        if (!var) continue;
        UIView *view=object_getIvar(box,var);
        if (!view) continue;
        // 搜 label
        UILabel *dzLabel=nil,*tjLabel=nil;
        NSMutableArray *labels=[NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], view, labels);
        for (UILabel *lb in labels){
            NSString *t=lb.text?:@"";
            if (!dzLabel && t.length==1 && [BranchesSet() containsObject:t]) dzLabel=lb;
            else if (!tjLabel && [GeneralsSet() containsObject:t]) tjLabel=lb;
        }
        // 找手势
        UIGestureRecognizer *dzGR=FindGesture(view,@"課傳觸摸手勢");
        UIGestureRecognizer *tjGR=FindGesture(view,@"天將觸摸手勢");
        if (dzGR){
            [g_keChuanTaskQueue addObject:@{ @"sender":dzGR,
                                             @"sel":@"顯示課傳摘要WithSender:",
                                             @"title":[NSString stringWithFormat:@"%@ - 地支(%@)",rows[i],dzLabel.text?:@"?"]}];
        }
        if (tjGR){
            [g_keChuanTaskQueue addObject:@{ @"sender":tjGR,
                                             @"sel":@"顯示課傳天將摘要WithSender:",
                                             @"title":[NSString stringWithFormat:@"%@ - 天将(%@)",rows[i],tjLabel.text?:@"?"]}];
        }
    }
    if (g_keChuanTaskQueue.count==0){ g_isExtractingKeChuanDetail=NO; return; }
    [self processKeChuanQueue_Truth];
}

%new
- (void)processKeChuanQueue_Truth {
    if (g_keChuanTaskQueue.count==0){
        // 收尾
        NSMutableString *res=[NSMutableString string];
        for (NSUInteger i=0;i<g_keChuanTitleQueue.count;i++){
            [res appendFormat:@"--- %@ ---\n%@\n\n",g_keChuanTitleQueue[i], (i<g_capturedKeChuanDetail.count)?g_capturedKeChuanDetail[i]:@"[提取失败]"];
        }
        [UIPasteboard generalPasteboard].string=res;
        UIAlertController *ok=[UIAlertController alertControllerWithTitle:@"提取完成" message:@"已复制到剪贴板" preferredStyle:UIAlertControllerStyleAlert];
        [ok addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:ok animated:YES completion:nil];
        g_isExtractingKeChuanDetail=NO; g_keChuanTaskQueue=nil; g_keChuanTitleQueue=nil; g_capturedKeChuanDetail=nil; return;
    }
    NSDictionary *task=g_keChuanTaskQueue.firstObject;
    [g_keChuanTaskQueue removeObjectAtIndex:0];
    [g_keChuanTitleQueue addObject:task[@"title"]];
    SEL sel=NSSelectorFromString(task[@"sel"]);
    if ([self respondsToSelector:sel]){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:sel withObject:task[@"sender"]];
#pragma clang diagnostic pop
    } else {
        [self processKeChuanQueue_Truth];
    }
}
%end

// =========================================================================
// 其余：高级技法解析、年命提取等原先模块可保持不变。
// 为了篇幅，此处只保留课传修复完整实现。
// =========================================================================
