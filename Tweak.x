#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - Section 1: UILabel 字体替换 & 简繁体自动转换
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

    NSMutableString *simplifiedText = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false);
    %orig(simplifiedText);
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) { %orig(attributedText); return; }
    NSString *originalString = attributedText.string;
    NSString *newString = nil;
    if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) {
        newString = @"Echo";
    } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) {
        newString = @"定制";
    } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) {
        newString = @"毕法";
    }
    if (newString) {
        NSMutableAttributedString *newAttr = [attributedText mutableCopy];
        [newAttr.mutableString setString:newString];
        %orig(newAttr); return;
    }
    NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false);
    %orig(finalAttributedText);
}
%end

#pragma mark - Section 2: UIWindow 透明水印
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) {
    UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, tileSize.width/2, tileSize.height/2);
    CGContextRotateCTM(context, angle * M_PI/180);
    [text drawInRect:(CGRect){-tileSize.width/2, -tileSize.height/2, tileSize} withAttributes:@{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: textColor
    }];
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
    UIView *wm = [[UIView alloc] initWithFrame:self.bounds];
    wm.tag = tag;
    wm.userInteractionEnabled = NO;
    wm.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    wm.backgroundColor = [UIColor colorWithPatternImage:createWatermarkImage(@"Echo定制",
                                                                             [UIFont systemFontOfSize:16],
                                                                             [[UIColor blackColor] colorWithAlphaComponent:0.12],
                                                                             CGSizeMake(150,100), -30)];
    [self addSubview:wm];
    [self bringSubviewToFront:wm];
}
%end

#pragma mark - Section 3: “复制到 AI” 按钮 + 文字抓取工具
static NSInteger const CopyAiButtonTag = 112233;

@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalPerfect;
- (void)findSubviewsOfClass:(Class)c inView:(UIView *)v andStoreIn:(NSMutableArray *)arr;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)clsName separator:(NSString *)sep;
- (NSString *)extractTextFromCollectionViewDataSourceWithViewClassName:(NSString *)clsName;
- (NSString *)extractTextFromTableViewDataSourceWithViewClassName:(NSString *)clsName;   // ★ 新增
@end

%hook UIViewController
- (void)viewDidLoad {
    %orig;
    Class target = NSClassFromString(@"六壬大占.ViewController");
    if (!target || ![self isKindOfClass:target]) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = self.view.window;
        if (!win || [win viewWithTag:CopyAiButtonTag]) return;
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.tag = CopyAiButtonTag;
        btn.frame = CGRectMake(win.bounds.size.width-100, 45, 90, 36);
        btn.layer.cornerRadius = 8;
        btn.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0];
        [btn setTitle:@"复制到AI" forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [btn addTarget:self action:@selector(copyAiButtonTapped_FinalPerfect) forControlEvents:UIControlEventTouchUpInside];
        [win addSubview:btn];
    });
}
%end

#pragma mark - 通用递归搜索
%new
- (void)findSubviewsOfClass:(Class)c inView:(UIView *)v andStoreIn:(NSMutableArray *)arr {
    if ([v isKindOfClass:c]) [arr addObject:v];
    for (UIView *sub in v.subviews) [self findSubviewsOfClass:c inView:sub andStoreIn:arr];
}

#pragma mark - 直接扫描某个容器内 UILabel
%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)clsName separator:(NSString *)sep {
    Class viewCls = NSClassFromString(clsName);
    if (!viewCls) return @"";
    NSMutableArray *containers = [NSMutableArray array];
    [self findSubviewsOfClass:viewCls inView:self.view andStoreIn:containers];
    UIView *container = containers.firstObject;
    if (!container) return @"";
    NSMutableArray *labels = [NSMutableArray array];
    [self findSubviewsOfClass:[UILabel class] inView:container andStoreIn:labels];

    // 先按 y 排序，再按 x
    [labels sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
        if (fabs(a.frame.origin.y - b.frame.origin.y) > 0.1)
            return a.frame.origin.y < b.frame.origin.y ? NSOrderedAscending : NSOrderedDescending;
        return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
    }];

    NSMutableArray *parts = [NSMutableArray array];
    for (UILabel *lab in labels) if (lab.text.length) [parts addObject:lab.text];
    return [parts componentsJoinedByString:sep];
}

#pragma mark - 抓取 Collection-View 数据源
%new
- (NSString *)extractTextFromCollectionViewDataSourceWithViewClassName:(NSString *)clsName {
    Class viewCls = NSClassFromString(clsName);
    if (!viewCls) return nil;
    NSMutableArray *views = [NSMutableArray array];
    [self findSubviewsOfClass:viewCls inView:self.view andStoreIn:views];
    UICollectionView *cv = (UICollectionView *)views.firstObject;
    if (!cv || ![cv isKindOfClass:[UICollectionView class]]) return nil;

    id<UICollectionViewDataSource> ds = cv.dataSource ?: (id)self;
    if (![ds conformsToProtocol:@protocol(UICollectionViewDataSource)]) return nil;

    NSInteger sections = 1;
    if ([ds respondsToSelector:@selector(numberOfSectionsInCollectionView:)])
        sections = [ds numberOfSectionsInCollectionView:cv];

    NSMutableArray *rows = [NSMutableArray array];
    for (NSInteger s = 0; s < sections; s++) {
        NSInteger items = [ds collectionView:cv numberOfItemsInSection:s];
        for (NSInteger i = 0; i < items; i++) {
            NSIndexPath *ip = [NSIndexPath indexPathForItem:i inSection:s];
            UICollectionViewCell *cell = [ds collectionView:cv cellForItemAtIndexPath:ip];

            NSMutableArray *labels = [NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:cell.contentView andStoreIn:labels];
            [labels sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
                return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
            }];
            NSMutableString *line = [NSMutableString string];
            for (UILabel *lab in labels) if (lab.text.length) [line appendFormat:@"%@ ", lab.text];
            NSString *trim = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (trim.length) [rows addObject:trim];
        }
    }
    return rows.count ? [rows componentsJoinedByString:@"\n"] : nil;
}

#pragma mark - ★ 新增：抓取 Table-View 数据源
%new
- (NSString *)extractTextFromTableViewDataSourceWithViewClassName:(NSString *)clsName {
    Class viewCls = NSClassFromString(clsName);
    if (!viewCls) return nil;
    NSMutableArray *views = [NSMutableArray array];
    [self findSubviewsOfClass:viewCls inView:self.view andStoreIn:views];
    UITableView *tv = (UITableView *)views.firstObject;
    if (!tv || ![tv isKindOfClass:[UITableView class]]) return nil;

    id<UITableViewDataSource> ds = tv.dataSource ?: (id)self;
    if (![ds conformsToProtocol:@protocol(UITableViewDataSource)]) return nil;

    NSInteger sections = 1;
    if ([ds respondsToSelector:@selector(numberOfSectionsInTableView:)])
        sections = [ds numberOfSectionsInTableView:tv];

    NSMutableArray *rows = [NSMutableArray array];
    for (NSInteger s = 0; s < sections; s++) {
        NSInteger cnt = [ds tableView:tv numberOfRowsInSection:s];
        for (NSInteger r = 0; r < cnt; r++) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:r inSection:s];
            UITableViewCell *cell = [ds tableView:tv cellForRowAtIndexPath:ip];

            NSMutableArray *labels = [NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:cell.contentView andStoreIn:labels];
            [labels sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
                return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
            }];

            NSMutableString *line = [NSMutableString string];
            for (UILabel *lab in labels) if (lab.text.length) [line appendFormat:@"%@ ", lab.text];
            NSString *trim = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (trim.length) [rows addObject:trim];
        }
    }
    return rows.count ? [rows componentsJoinedByString:@"\n"] : nil;
}

#pragma mark - Section 4: 主逻辑 – 复制到剪贴板
%new
- (void)copyAiButtonTapped_FinalPerfect {

#define Safe(str) (str ?: @"")

    /* ================== 1. 固定信息块 ================== */
    NSString *timeBlock = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *yueJiang  = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖"    separator:@" "];
    NSString *kongWang  = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖"    separator:@" "];
    NSString *sanGongShi= [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖"  separator:@" "];
    NSString *zhouYe    = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    NSString *fullKeti  = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖"    separator:@" "];
    NSString *methodName= [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖"  separator:@" "];

    /* ================== 2. 动态列表：毕法 & 七政 ================== */
    // ★ 先尝试 Table-View 抓取
    NSString *biFaList =
        [self extractTextFromTableViewDataSourceWithViewClassName:@"六壬大占.格局總覽視圖"] ?:
        [self extractTextFromCollectionViewDataSourceWithViewClassName:@"六壬大占.格局總覽視圖"] ?:
        [self extractTextFromFirstViewOfClassName:@"六壬大占.格局總覽視圖" separator:@"\n"];

    NSString *qiZhengList =
        [self extractTextFromTableViewDataSourceWithViewClassName:@"六壬大占.七政信息視圖"] ?:
        [self extractTextFromCollectionViewDataSourceWithViewClassName:@"六壬大占.七政信息視圖"] ?:
        [self extractTextFromFirstViewOfClassName:@"六壬大占.七政信息視圖" separator:@"\n"];

    /* ================== 3. 四课提取 (沿用旧逻辑) ================== */
    NSMutableString *siKe = [NSMutableString string];
    // —— 此处省略，保持你原来完整的四课计算代码 —— //
    // （为节省篇幅，如果之前段落无改动，可直接粘贴原实现）

    /* ================== 4. 三传提取 (沿用旧逻辑) ================== */
    NSMutableString *sanChuan = [NSMutableString string];
    // —— 同样粘贴你原来的三传计算代码 —— //

    /* ================== 5. 拼装最终文本 ================== */
    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"%@\n\n", Safe(timeBlock)];
    [out appendFormat:@"月将: %@\n", Safe(yueJiang)];
    [out appendFormat:@"空亡: %@\n", Safe(kongWang)];
    [out appendFormat:@"三宫时: %@\n", Safe(sanGongShi)];
    [out appendFormat:@"昼夜: %@\n", Safe(zhouYe)];
    [out appendFormat:@"课体: %@\n\n", Safe(fullKeti)];

    [out appendFormat:@"%@\n\n", Safe(siKe)];
    [out appendFormat:@"%@\n\n", Safe(sanChuan)];

    if (biFaList.length)   [out appendFormat:@"毕法:\n%@\n\n", biFaList];
    if (qiZhengList.length)[out appendFormat:@"七政:\n%@\n\n", qiZhengList];

    [out appendFormat:@"起课方式: %@", Safe(methodName)];

    NSString *final = [out stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [UIPasteboard generalPasteboard].string = final;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板"
                                                                   message:final
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
%end
