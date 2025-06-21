//======================================================================
//  Tweak.x  ——  MyTweak  (Logos / Theos)
//  2024-06  by ChatGPT & You
//======================================================================

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

%config(generator=internal)           // 让 Logo 生成内部分类，便于编译器看到方法

#pragma mark - ┃ 先来一段前向声明，解决 “no visible @interface…” ┃
@interface UIViewController (CopyAiAddonForwardDeclarations)
- (void)findSubviewsOfClass:(Class)cls inView:(UIView *)view andStoreIn:(NSMutableArray *)output;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)clsName separator:(NSString *)sep;
- (NSString *)extractTextFromCollectionViewDataSourceWithViewClassName:(NSString *)clsName;
- (NSString *)extractTextFromTableViewDataSourceWithViewClassName:(NSString *)clsName;
- (void)copyAiButtonTapped_FinalPerfect;
@end

//======================================================================
//  一、UILabel：文字替换 + 简繁转换
//======================================================================
%hook UILabel
- (void)setText:(NSString *)text {
    if (!text) { %orig(text); return; }

    // 固定替换
    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) {
        %orig(@"Echo"); return;
    }
    if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) {
        %orig(@"定制"); return;
    }
    if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) {
        %orig(@"毕法"); return;
    }

    // 其它文本：自动繁转简
    NSMutableString *simplified = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simplified, NULL, CFSTR("Hant-Hans"), false);
    %orig(simplified);
}

- (void)setAttributedText:(NSAttributedString *)attr {
    if (!attr) { %orig(attr); return; }

    NSString *ori = attr.string;
    NSMutableAttributedString *mutable = [attr mutableCopy];

    if ([ori isEqualToString:@"我的分类"] || [ori isEqualToString:@"我的分類"] || [ori isEqualToString:@"通類"]) {
        [mutable.mutableString setString:@"Echo"];   %orig(mutable); return;
    }
    if ([ori isEqualToString:@"起課"] || [ori isEqualToString:@"起课"]) {
        [mutable.mutableString setString:@"定制"];   %orig(mutable); return;
    }
    if ([ori isEqualToString:@"法诀"] || [ori isEqualToString:@"法訣"]) {
        [mutable.mutableString setString:@"毕法"];   %orig(mutable); return;
    }

    CFStringTransform((__bridge CFMutableStringRef)mutable.mutableString, NULL, CFSTR("Hant-Hans"), false);
    %orig(mutable);
}
%end

//======================================================================
//  二、UIWindow：背景水印
//======================================================================
static UIImage *WatermarkImage(NSString *txt, UIFont *fnt, UIColor *clr,
                               CGSize sz, CGFloat angle) {
    UIGraphicsBeginImageContextWithOptions(sz, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, sz.width/2.0, sz.height/2.0);
    CGContextRotateCTM   (ctx, angle * M_PI/180.0);

    CGRect r = CGRectMake(-sz.width/2.0, -sz.height/2.0, sz.width, sz.height);
    [txt drawInRect:r withAttributes:@{
        NSFontAttributeName: fnt,
        NSForegroundColorAttributeName: clr
    }];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

%hook UIWindow
- (void)layoutSubviews {
    %orig;
    if (self.windowLevel != UIWindowLevelNormal) return;

    static NSInteger kTag = 998877;
    if ([self viewWithTag:kTag]) return;

    UIView *v = [[UIView alloc] initWithFrame:self.bounds];
    v.tag = kTag;
    v.userInteractionEnabled = NO;
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    v.backgroundColor = [UIColor colorWithPatternImage:
        WatermarkImage(@"Echo定制",
                       [UIFont systemFontOfSize:16],
                       [[UIColor blackColor] colorWithAlphaComponent:0.12],
                       CGSizeMake(150,100), -30)];
    [self addSubview:v];
}
%end

//======================================================================
//  三、UIViewController：按钮 & 全部辅助方法
//======================================================================
static NSInteger const kCopyBtnTag = 112233;
#define SAFE_STR(x) ((x) ? (x) : @"")

%hook UIViewController

// --------------------------- 3.1 viewDidLoad：插按钮 ------------------
- (void)viewDidLoad {
    %orig;

    Class target = NSClassFromString(@"六壬大占.ViewController");   // ← 换成你的主 VC 类名
    if (!target || ![self isKindOfClass:target]) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindow *win = self.view.window;
        if (!win || [win viewWithTag:kCopyBtnTag]) return;

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.tag = kCopyBtnTag;
        btn.frame = CGRectMake(win.bounds.size.width-100, 45, 90, 36);
        btn.layer.cornerRadius = 8;
        btn.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0];
        [btn setTitle:@"复制到AI" forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [btn addTarget:self action:@selector(copyAiButtonTapped_FinalPerfect)
              forControlEvents:UIControlEventTouchUpInside];
        [win addSubview:btn];
    });
}

// --------------------------- 3.2 递归找视图 --------------------------
%new
- (void)findSubviewsOfClass:(Class)cls
                     inView:(UIView *)view
                andStoreIn:(NSMutableArray *)output {
    if ([view isKindOfClass:cls]) [output addObject:view];
    for (UIView *sub in view.subviews)
        [self findSubviewsOfClass:cls inView:sub andStoreIn:output];
}

// --------------------------- 3.3 直接扫 UILabel ---------------------
%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)clsName
                                        separator:(NSString *)sep {
    Class boxCls = NSClassFromString(clsName);
    if (!boxCls) return @"";

    NSMutableArray *boxes = [NSMutableArray array];
    [self findSubviewsOfClass:boxCls inView:self.view andStoreIn:boxes];
    UIView *box = boxes.firstObject;
    if (!box) return @"";

    NSMutableArray *labels = [NSMutableArray array];
    [self findSubviewsOfClass:[UILabel class] inView:box andStoreIn:labels];

    // 按 (y,x) 排序
    [labels sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
        if (fabs(a.frame.origin.y - b.frame.origin.y) > 0.1)
            return a.frame.origin.y < b.frame.origin.y ? NSOrderedAscending : NSOrderedDescending;
        return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
    }];

    NSMutableArray *parts = [NSMutableArray array];
    for (UILabel *l in labels) if (l.text.length) [parts addObject:l.text];
    return [parts componentsJoinedByString:sep];
}

// --------------------------- 3.4 抓 CollectionView ------------------
%new
- (NSString *)extractTextFromCollectionViewDataSourceWithViewClassName:(NSString *)clsName {
    Class cvCls = NSClassFromString(clsName);     if (!cvCls) return nil;
    NSMutableArray *boxes = [NSMutableArray array];
    [self findSubviewsOfClass:cvCls inView:self.view andStoreIn:boxes];
    UICollectionView *cv = (UICollectionView *)boxes.firstObject;
    if (!cv || ![cv isKindOfClass:[UICollectionView class]]) return nil;

    id<UICollectionViewDataSource> ds = cv.dataSource ?: (id)self;
    if (![ds conformsToProtocol:@protocol(UICollectionViewDataSource)]) return nil;

    NSInteger sections = 1;
    if ([ds respondsToSelector:@selector(numberOfSectionsInCollectionView:)])
        sections = [ds numberOfSectionsInCollectionView:cv];

    NSMutableArray *rows = [NSMutableArray array];
    for (NSInteger s=0; s<sections; s++) {
        NSInteger items = [ds collectionView:cv numberOfItemsInSection:s];
        for (NSInteger i=0; i<items; i++) {
            NSIndexPath *ip = [NSIndexPath indexPathForItem:i inSection:s];
            UICollectionViewCell *cell = [ds collectionView:cv cellForItemAtIndexPath:ip];

            NSMutableArray *labs = [NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:cell.contentView andStoreIn:labs];
            [labs sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
                return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
            }];

            NSMutableString *line = [NSMutableString string];
            for (UILabel *l in labs) if (l.text.length) [line appendFormat:@"%@ ", l.text];
            NSString *trim = [line stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceCharacterSet]];
            if (trim.length) [rows addObject:trim];
        }
    }
    return rows.count ? [rows componentsJoinedByString:@"\n"] : nil;
}

// --------------------------- 3.5 抓 TableView -----------------------
%new
- (NSString *)extractTextFromTableViewDataSourceWithViewClassName:(NSString *)clsName {
    Class tvCls = NSClassFromString(clsName);     if (!tvCls) return nil;
    NSMutableArray *boxes = [NSMutableArray array];
    [self findSubviewsOfClass:tvCls inView:self.view andStoreIn:boxes];
    UITableView *tv = (UITableView *)boxes.firstObject;
    if (!tv || ![tv isKindOfClass:[UITableView class]]) return nil;

    id<UITableViewDataSource> ds = tv.dataSource ?: (id)self;
    if (![ds conformsToProtocol:@protocol(UITableViewDataSource)]) return nil;

    NSInteger sections = 1;
    if ([ds respondsToSelector:@selector(numberOfSectionsInTableView:)])
        sections = [ds numberOfSectionsInTableView:tv];

    NSMutableArray *rows = [NSMutableArray array];
    for (NSInteger s=0; s<sections; s++) {
        NSInteger cnt = [ds tableView:tv numberOfRowsInSection:s];
        for (NSInteger r=0; r<cnt; r++) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:r inSection:s];
            UITableViewCell *cell = [ds tableView:tv cellForRowAtIndexPath:ip];

            NSMutableArray *labs = [NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:cell.contentView andStoreIn:labs];
            [labs sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
                return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
            }];

            NSMutableString *line = [NSMutableString string];
            for (UILabel *l in labs) if (l.text.length) [line appendFormat:@"%@ ", l.text];
            NSString *trim = [line stringByTrimmingCharactersInSet:
                              [NSCharacterSet whitespaceCharacterSet]];
            if (trim.length) [rows addObject:trim];
        }
    }
    return rows.count ? [rows componentsJoinedByString:@"\n"] : nil;
}

// --------------------------- 3.6 终极复制逻辑 -----------------------
%new
- (void)copyAiButtonTapped_FinalPerfect {

    /* ========  1) 固定信息块  ======== */
    NSString *timeBlk = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖"
                                                        separator:@" "]
                         stringByReplacingOccurrencesOfString:@"\n" withString:@" "];

    NSString *yueJiang = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖"  separator:@" "];
    NSString *kongWang = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖"  separator:@" "];
    NSString *sanGong  = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    NSString *zhouYe   = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    NSString *keTi     = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖"  separator:@" "];
    NSString *method   = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖"  separator:@" "];

    /* ========  2) 动态列表 (毕法 / 七政)  ======== */
    NSString *biFa = [self extractTextFromTableViewDataSourceWithViewClassName:@"六壬大占.格局總覽視圖"] ?:
                     [self extractTextFromCollectionViewDataSourceWithViewClassName:@"六壬大占.格局總覽視圖"] ?:
                     [self extractTextFromFirstViewOfClassName:@"六壬大占.格局總覽視圖" separator:@"\n"];

    NSString *qiZheng = [self extractTextFromTableViewDataSourceWithViewClassName:@"六壬大占.七政信息視圖"] ?:
                        [self extractTextFromCollectionViewDataSourceWithViewClassName:@"六壬大占.七政信息視圖"] ?:
                        [self extractTextFromFirstViewOfClassName:@"六壬大占.七政信息視圖" separator:@"\n"];

    /* ========  3) 四课 & 三传  ======== */
    NSMutableString *siKe     = [NSMutableString stringWithString:@"(四课占位)\n"];   // TODO: 替换成真实现
    NSMutableString *sanChuan = [NSMutableString stringWithString:@"(三传占位)\n"];   // TODO: 替换成真实现

    /* ========  4) 拼装 & 弹窗 + 复制  ======== */
    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"%@\n\n", SAFE_STR(timeBlk)];
    [out appendFormat:@"月将: %@\n", SAFE_STR(yueJiang)];
    [out appendFormat:@"空亡: %@\n", SAFE_STR(kongWang)];
    [out appendFormat:@"三宫时: %@\n", SAFE_STR(sanGong)];
    [out appendFormat:@"昼夜: %@\n", SAFE_STR(zhouYe)];
    [out appendFormat:@"课体: %@\n\n", SAFE_STR(keTi)];

    [out appendFormat:@"%@\n", SAFE_STR(siKe)];
    [out appendFormat:@"%@\n", SAFE_STR(sanChuan)];

    if (biFa.length)   [out appendFormat:@"毕法:\n%@\n\n", biFa];
    if (qiZheng.length)[out appendFormat:@"七政:\n%@\n\n", qiZheng];

    [out appendFormat:@"起课方式: %@", SAFE_STR(method)];

    NSString *final = [out stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [UIPasteboard generalPasteboard].string = final;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板"
                                                                   message:final
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
%end  // UIViewController hook 结束

//======================================================================
//  文件结束。祝编译顺利！
//======================================================================
