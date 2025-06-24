#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 0. 日志宏
// =========================================================================
#define EchoLog(fmt, ...) NSLog((@"[EchoAI] " fmt), ##__VA_ARGS__)

// =========================================================================
// 1. 全局变量 & 辅助函数
// =========================================================================
static NSInteger const kCombinedButtonTag = 112244;
static NSInteger const kProgressViewTag __attribute__((unused)) = 556677;

static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray<NSDictionary *> *g_keChuanTaskQueue = nil;
static NSMutableArray<NSString *>     *g_keChuanTitleQueue = nil;
static NSMutableArray<NSString *>     *g_capturedKeChuanDetail = nil;

// 供后续年命等模块使用，先占位，防止 Werror
static NSMutableDictionary *g_extractedData        __attribute__((unused)) = nil;
static BOOL                g_isExtractingNianming __attribute__((unused)) = NO;
static NSString           *g_currentItemToExtract __attribute__((unused)) = nil;
static NSMutableArray     *g_capturedZhaiYaoArray __attribute__((unused)) = nil;
static NSMutableArray     *g_capturedGeJuArray    __attribute__((unused)) = nil;

static inline NSSet *BranchesSet(void) {
    static NSSet *s; static dispatch_once_t once; dispatch_once(&once, ^{
        s = [NSSet setWithArray:@[@"子",@"丑",@"寅",@"卯",@"辰",@"巳",@"午",@"未",@"申",@"酉",@"戌",@"亥"]];
    }); return s;
}
static inline NSSet *GeneralsSet(void) {
    static NSSet *s; static dispatch_once_t once; dispatch_once(&once, ^{
        s = [NSSet setWithArray:@[@"青龍",@"朱雀",@"勾陳",@"螣蛇",@"白虎",@"玄武",@"六合",@"天后",@"天空",@"太常",@"太陰"]];
    }); return s;
}
static void FindSubviewsOfClassRecursive(Class cls, UIView *v, NSMutableArray *store) {
    if ([v isKindOfClass:cls]) [store addObject:v];
    for (UIView *sub in v.subviews) FindSubviewsOfClassRecursive(cls, sub, store);
}
static UIGestureRecognizer *FindGesture(UIView *v, NSString *suffix) {
    for (UIGestureRecognizer *gr in v.gestureRecognizers)
        if ([NSStringFromClass([gr class]) hasSuffix:suffix]) return gr;
    return nil;
}
static UIImage *createWatermarkImage(NSString *txt, UIFont *font, UIColor *clr, CGSize tile, CGFloat deg) {
    UIGraphicsBeginImageContextWithOptions(tile, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, tile.width/2, tile.height/2);
    CGContextRotateCTM(ctx, deg*M_PI/180);
    [txt drawInRect:CGRectMake(-tile.width, -tile.height, tile.width*2, tile.height*2)
       withAttributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:clr}];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

// =========================================================================
// 2. UI Hooks
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text {
    if (!text) { %orig(text); return; }
    NSDictionary *map = @{@"我的分类":@"Echo", @"我的分類":@"Echo", @"通類":@"Echo",
                          @"起課":@"定制", @"起课":@"定制",
                          @"法诀":@"毕法", @"法訣":@"毕法"};
    NSString *replace = map[text];
    if (replace) { %orig(replace); return; }
    NSMutableString *simp = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simp, NULL, CFSTR("Hant-Hans"), false);
    %orig(simp);
}
%end

%hook UIWindow
- (void)layoutSubviews {
    %orig;
    if (self.windowLevel!=UIWindowLevelNormal) return;
    if ([self viewWithTag:998877]) return;
    UIImage *p = createWatermarkImage(@"Echo定制", [UIFont systemFontOfSize:16], [[UIColor blackColor] colorWithAlphaComponent:0.12], CGSizeMake(150,100), -30);
    UIView *wm=[[UIView alloc] initWithFrame:self.bounds]; wm.tag=998877; wm.userInteractionEnabled=NO;
    wm.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    wm.backgroundColor=[UIColor colorWithPatternImage:p];
    [self addSubview:wm];
}
%end

// =========================================================================
// 3. UIViewController – 课传提取
// =========================================================================
@interface UIViewController (EchoKeChuan)
- (void)performKeChuanDetailExtractionTest_Truth;
- (void)processKeChuanQueue_Truth;
@end

%hook UIViewController
// 按钮注入
- (void)viewDidLoad {
    %orig;
    Class root = NSClassFromString(@"六壬大占.ViewController");
    if (root && [self isKindOfClass:root]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            UIWindow *win = self.view.window; if (!win) return;
            if ([win viewWithTag:kCombinedButtonTag]) [[win viewWithTag:kCombinedButtonTag] removeFromSuperview];
            UIButton *btn=[UIButton buttonWithType:UIButtonTypeSystem];
            btn.tag=kCombinedButtonTag;
            btn.frame=CGRectMake(win.bounds.size.width-150, 125, 140, 36);
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

// 3.1 构建队列
%new
- (void)performKeChuanDetailExtractionTest_Truth {
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetail     = [NSMutableArray array];
    g_keChuanTitleQueue         = [NSMutableArray array];
    g_keChuanTaskQueue          = [NSMutableArray array];

    Class BoxCls = NSClassFromString(@"六壬大占.三傳視圖");
    if (!BoxCls) { g_isExtractingKeChuanDetail = NO; return; }

    NSMutableArray *boxes=[NSMutableArray array];
    FindSubviewsOfClassRecursive(BoxCls, self.view, boxes);
    if (boxes.count==0) { g_isExtractingKeChuanDetail = NO; return; }
    UIView *box = boxes.firstObject;

    const char *ivars[] = {"初傳","中傳","末傳",NULL};
    NSString   *rows[]  = {@"初传",@"中传",@"末传"};

    for (int i=0; ivars[i]; ++i) {
        Ivar ivar = class_getInstanceVariable(BoxCls, ivars[i]); if (!ivar) continue;
        UIView *view = object_getIvar(box, ivar);              if (!view) continue;

        // 找标题用的 label
        UILabel *dz=nil,*tj=nil; NSMutableArray *lbs=[NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], view, lbs);
        for (UILabel *lb in lbs) {
            NSString *t = lb.text ?: @"";
            if (!dz && t.length==1 && [BranchesSet() containsObject:t]) dz=lb;
            else if (!tj && [GeneralsSet() containsObject:t])          tj=lb;
        }
        // 手势对象
        UIGestureRecognizer *dzGR = FindGesture(view, @"課傳觸摸手勢");
        UIGestureRecognizer *tjGR = FindGesture(view, @"天將觸摸手勢");

        if (dzGR)
            [g_keChuanTaskQueue addObject:@{ @"sender":dzGR,
                                             @"sel":@"顯示課傳摘要WithSender:",
                                             @"title":[NSString stringWithFormat:@"%@ - 地支(%@)", rows[i], dz.text?:@"?"] }];
        if (tjGR)
            [g_keChuanTaskQueue addObject:@{ @"sender":tjGR,
                                             @"sel":@"顯示課傳天將摘要WithSender:",
                                             @"title":[NSString stringWithFormat:@"%@ - 天将(%@)", rows[i], tj.text?:@"?"] }];
    }

    if (g_keChuanTaskQueue.count==0) { g_isExtractingKeChuanDetail = NO; return; }
    [self processKeChuanQueue_Truth];
}

// 3.2 队列驱动
%new
- (void)processKeChuanQueue_Truth {
    if (g_keChuanTaskQueue.count == 0) {
        NSMutableString *out=[NSMutableString string];
        for (NSUInteger i=0;i<g_keChuanTitleQueue.count;i++) {
            [out appendFormat:@"--- %@ ---\n%@\n\n",
             g_keChuanTitleQueue[i],
             (i<g_capturedKeChuanDetail.count)?g_capturedKeChuanDetail[i]:@"[提取失败]"];
        }
        [UIPasteboard generalPasteboard].string = out;
        UIAlertController *dlg=[UIAlertController alertControllerWithTitle:@"提取完成" message:@"已复制到剪贴板" preferredStyle:UIAlertControllerStyleAlert];
        [dlg addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:dlg animated:YES completion:nil];
        g_isExtractingKeChuanDetail = NO;
        g_keChuanTaskQueue = nil; g_keChuanTitleQueue=nil; g_capturedKeChuanDetail=nil;
        return;
    }

    NSDictionary *task = g_keChuanTaskQueue.firstObject; [g_keChuanTaskQueue removeObjectAtIndex:0];
    [g_keChuanTitleQueue addObject:task[@"title"]];
    SEL sel = NSSelectorFromString(task[@"sel"]);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if ([self respondsToSelector:sel]) [self performSelector:sel withObject:task[@"sender"]];
#pragma clang diagnostic pop
}
%end
