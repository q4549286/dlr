#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - UILabel 字符替换 / 简繁体
%hook UILabel
- (void)setText:(NSString *)text {
    if (!text) { %orig(text); return; }
    NSString *newString = nil;
    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) {
        newString = @"Echo";
    } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) {
        newString = @"定制";
    } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) {
        newString = @"毕法";
    }
    if (newString) { %orig(newString); return; }

    NSMutableString *simp = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simp, NULL, CFSTR("Hant-Hans"), false);
    %orig(simp);
}

- (void)setAttributedText:(NSAttributedString *)attr {
    if (!attr) { %orig(attr); return; }
    NSString *ori = attr.string;
    NSString *rep = nil;
    if ([ori isEqualToString:@"我的分类"] || [ori isEqualToString:@"我的分類"] || [ori isEqualToString:@"通類"]) {
        rep = @"Echo";
    } else if ([ori isEqualToString:@"起課"] || [ori isEqualToString:@"起课"]) {
        rep = @"定制";
    } else if ([ori isEqualToString:@"法诀"] || [ori isEqualToString:@"法訣"]) {
        rep = @"毕法";
    }
    if (rep) {
        NSMutableAttributedString *m = [attr mutableCopy];
        [m.mutableString setString:rep];
        %orig(m); return;
    }
    NSMutableAttributedString *m = [attr mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)m.mutableString, NULL, CFSTR("Hant-Hans"), false);
    %orig(m);
}
%end

#pragma mark - UIWindow 背景水印
static UIImage *WatermarkImage(NSString *txt, UIFont *fnt, UIColor *clr, CGSize sz, CGFloat ang) {
    UIGraphicsBeginImageContextWithOptions(sz, NO, 0);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(c, sz.width/2, sz.height/2);
    CGContextRotateCTM(c, ang * M_PI/180);
    [txt drawInRect:(CGRect){-sz.width/2, -sz.height/2, sz}
      withAttributes:@{ NSFontAttributeName:fnt, NSForegroundColorAttributeName:clr }];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

%hook UIWindow
- (void)layoutSubviews {
    %orig;
    if (self.windowLevel != UIWindowLevelNormal) return;
    NSInteger tag = 998877;
    if ([self viewWithTag:tag]) return;
    UIView *v = [[UIView alloc] initWithFrame:self.bounds];
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    v.userInteractionEnabled = NO;
    v.tag = tag;
    v.backgroundColor = [UIColor colorWithPatternImage:WatermarkImage(@"Echo定制",
        [UIFont systemFontOfSize:16], [[UIColor blackColor] colorWithAlphaComponent:0.12],
        CGSizeMake(150,100), -30)];
    [self addSubview:v];
}
%end

#pragma mark - UIViewController：按钮 + 所有辅助方法
static NSInteger const kCopyBtnTag = 112233;

%hook UIViewController

#pragma mark viewDidLoad：加 “复制到AI” 按钮
- (void)viewDidLoad {
    %orig;

    Class target = NSClassFromString(@"六壬大占.ViewController");
    if (!target || ![self isKindOfClass:target]) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindow *win = self.view.window;
        if (!win || [win viewWithTag:kCopyBtnTag]) return;

        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.tag = kCopyBtnTag;
        b.frame = CGRectMake(win.bounds.size.width-100, 45, 90, 36);
        b.layer.cornerRadius = 8;
        b.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0];
        [b setTitle:@"复制到AI" forState:UIControlStateNormal];
        [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [b addTarget:self action:@selector(copyAiButtonTapped_FinalPerfect)
             forControlEvents:UIControlEventTouchUpInside];
        [win addSubview:b];
    });
}

#pragma mark 通用递归搜索
%new
- (void)findSubviewsOfClass:(Class)cls inView:(UIView *)v andStoreIn:(NSMutableArray *)arr {
    if ([v isKindOfClass:cls]) [arr addObject:v];
    for (UIView *sub in v.subviews)
        [self findSubviewsOfClass:cls inView:sub andStoreIn:arr];
}

#pragma mark 扫描容器 UILabel
%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)clsName separator:(NSString *)sep {
    Class c = NSClassFromString(clsName); if (!c) return @"";
    NSMutableArray *views = [NSMutableArray array];
    [self findSubviewsOfClass:c inView:self.view andStoreIn:views];
    UIView *box = views.firstObject; if (!box) return @"";
    NSMutableArray *labels = [NSMutableArray array];
    [self findSubviewsOfClass:[UILabel class] inView:box andStoreIn:labels];

    [labels sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
        if (fabs(a.frame.origin.y - b.frame.origin.y) > 0.1)
            return a.frame.origin.y < b.frame.origin.y ? NSOrderedAscending : NSOrderedDescending;
        return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
    }];

    NSMutableArray *parts = [NSMutableArray array];
    for (UILabel *l in labels) if (l.text.length) [parts addObject:l.text];
    return [parts componentsJoinedByString:sep];
}

#pragma mark 抓 Collection-view
%new
- (NSString *)extractTextFromCollectionViewDataSourceWithViewClassName:(NSString *)clsName {
    Class c = NSClassFromString(clsName); if (!c) return nil;
    NSMutableArray *ary = [NSMutableArray array];
    [self findSubviewsOfClass:c inView:self.view andStoreIn:ary];
    UICollectionView *cv = (UICollectionView *)ary.firstObject;
    if (!cv || ![cv isKindOfClass:[UICollectionView class]]) return nil;

    id<UICollectionViewDataSource> ds = cv.dataSource ?: (id)self;
    if (![ds conformsToProtocol:@protocol(UICollectionViewDataSource)]) return nil;

    NSInteger sect = 1;
    if ([ds respondsToSelector:@selector(numberOfSectionsInCollectionView:)])
        sect = [ds numberOfSectionsInCollectionView:cv];

    NSMutableArray *rows = [NSMutableArray array];
    for (NSInteger s=0; s<sect; s++) {
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
            NSString *trim = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            if (trim.length) [rows addObject:trim];
        }
    }
    return rows.count ? [rows componentsJoinedByString:@"\n"] : nil;
}

#pragma mark 抓 Table-view
%new
- (NSString *)extractTextFromTableViewDataSourceWithViewClassName:(NSString *)clsName {
    Class c = NSClassFromString(clsName); if (!c) return nil;
    NSMutableArray *ary = [NSMutableArray array];
    [self findSubviewsOfClass:c inView:self.view andStoreIn:ary];
    UITableView *tv = (UITableView *)ary.firstObject;
    if (!tv || ![tv isKindOfClass:[UITableView class]]) return nil;

    id<UITableViewDataSource> ds = tv.dataSource ?: (id)self;
    if (![ds conformsToProtocol:@protocol(UITableViewDataSource)]) return nil;

    NSInteger sect = 1;
    if ([ds respondsToSelector:@selector(numberOfSectionsInTableView:)])
        sect = [ds numberOfSectionsInTableView:tv];

    NSMutableArray *rows = [NSMutableArray array];
    for (NSInteger s=0; s<sect; s++) {
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
            NSString *trim = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            if (trim.length) [rows addObject:trim];
        }
    }
    return rows.count ? [rows componentsJoinedByString:@"\n"] : nil;
}

#pragma mark 复制到 AI（主体）
%new
- (void)copyAiButtonTapped_FinalPerfect {

#define S(x) ((x) ?: @"")

    /* ---------- 基础块 ---------- */
    NSString *timeBlock = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *yueJiang  = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    NSString *kongWang  = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@" "];
    NSString *sanGong   = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    NSString *zhouYe    = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    NSString *keTi      = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    NSString *method    = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];

    /* ---------- 动态列表 ---------- */
    NSString *biFa = [self extractTextFromTableViewDataSourceWithViewClassName:@"六壬大占.格局總覽視圖"] ?:
                     [self extractTextFromCollectionViewDataSourceWithViewClassName:@"六壬大占.格局總覽視圖"] ?:
                     [self extractTextFromFirstViewOfClassName:@"六壬大占.格局總覽視圖" separator:@"\n"];

    NSString *qiZheng = [self extractTextFromTableViewDataSourceWithViewClassName:@"六壬大占.七政信息視圖"] ?:
                        [self extractTextFromCollectionViewDataSourceWithViewClassName:@"六壬大占.七政信息視圖"] ?:
                        [self extractTextFromFirstViewOfClassName:@"六壬大占.七政信息視圖" separator:@"\n"];

    /* ---------- 四课 / 三传 ---------- */
    NSMutableString *siKe = [NSMutableString string];
    NSMutableString *sanChuan = [NSMutableString string];
    // TODO: 把你原来的四课 & 三传提取代码粘到这里

    /* ---------- 拼装 ---------- */
    NSMutableString *msg = [NSMutableString string];
    [msg appendFormat:@"%@\n\n", S(timeBlock)];
    [msg appendFormat:@"月将: %@\n空亡: %@\n三宫时: %@\n昼夜: %@\n课体: %@\n\n",
        S(yueJiang), S(kongWang), S(sanGong), S(zhouYe), S(keTi)];
    [msg appendFormat:@"%@\n\n%@\n\n", S(siKe), S(sanChuan)];
    if (biFa.length)   [msg appendFormat:@"毕法:\n%@\n\n", biFa];
    if (qiZheng.length)[msg appendFormat:@"七政:\n%@\n\n", qiZheng];
    [msg appendFormat:@"起课方式: %@", S(method)];

    NSString *final = [msg stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [UIPasteboard generalPasteboard].string = final;

    UIAlertController *al = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板"
                                                                message:final
                                                         preferredStyle:UIAlertControllerStyleAlert];
    [al addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:al animated:YES completion:nil];
}
%end   // ← 这里把整个 UIViewController hook 关上
