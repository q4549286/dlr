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
static NSInteger const kProgressViewTag __attribute__((unused)) = 556677;  // 标记 unused 以消除 -Werror

static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray<NSDictionary *> *g_keChuanTaskQueue = nil;
static NSMutableArray<NSString *> *g_keChuanTitleQueue = nil;
static NSMutableArray<NSString *> *g_capturedKeChuanDetail = nil;

// 以下变量属于“年命提取”等后续模块，当前文件未用到。
// 为防 -Wunused-XX 触发 Werror，全部加 __attribute__((unused))
static NSMutableDictionary *g_extractedData __attribute__((unused)) = nil;
static BOOL g_isExtractingNianming __attribute__((unused)) = NO;
static NSString *g_currentItemToExtract __attribute__((unused)) = nil;
static NSMutableArray *g_capturedZhaiYaoArray __attribute__((unused)) = nil;
static NSMutableArray *g_capturedGeJuArray __attribute__((unused)) = nil;

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
// 3. UIViewController 主功能（课传提取修复版）
// =========================================================================
@interface UIViewController (EchoKeChuan)
- (void)performKeChuanDetailExtractionTest_Truth;
- (void)processKeChuanQueue_Truth;
@end

%hook UIViewController
// ————————————————— viewDidLoad: 注入按钮
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

// ————————————————— 1) 构建任务队列
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
        // label
        UILabel *dzLabel=nil,*tjLabel=nil;
        NSMutableArray *labels=[NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], view, labels);
        for (UILabel *lb in labels){
            NSString *t=lb.text?:@"";
            if (!dzLabel && t.length==1 && [BranchesSet() containsObject:t]) dzLabel=lb;
            else if (!tjLabel && [GeneralsSet() containsObject:t]) tjLabel=lb;
        }
        // gesture
        UIGestureRecognizer *dzGR=FindGesture(view,@"課傳觸摸手勢");
        UIGestureRecognizer *tjGR
