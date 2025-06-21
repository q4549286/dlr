//  File: EchoAddon.xm
//  Compile with: THEOS / Logos

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark ------------------------------------------------------------------
#pragma mark Section 1 – UILabel & UIWindow Hook（繁體置換 + 浮水印）
#pragma mark ------------------------------------------------------------------

%hook UILabel

- (void)setText:(NSString *)text {
    if (!text) { %orig(text); return; }

    NSString *newString = nil;

    // —— 置換三個固定詞 —— //
    if ([text isEqualToString:@"我的分類"] ||   // 簡體
        [text isEqualToString:@"我的分類"] ||   // 繁體
        [text isEqualToString:@"通類"])
    {
        newString = @"Echo";
    }
    else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"])
    {
        newString = @"訂製";
    }
    else if ([text isEqualToString:@"法訣"] || [text isEqualToString:@"法诀"])
    {
        newString = @"畢法";
    }

    if (newString) { %orig(newString); return; }

    // 其餘文本：統一轉繁體
    NSMutableString *tc = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)tc, NULL, CFSTR("Hans-Hant"), false);
    %orig(tc);
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) { %orig(attributedText); return; }

    NSString *src = attributedText.string;
    NSString *newString = nil;

    if ([src isEqualToString:@"我的分類"] || [src isEqualToString:@"我的分類"] || [src isEqualToString:@"通類"])
    {
        newString = @"Echo";
    }
    else if ([src isEqualToString:@"起課"] || [src isEqualToString:@"起课"])
    {
        newString = @"訂製";
    }
    else if ([src isEqualToString:@"法訣"] || [src isEqualToString:@"法诀"])
    {
        newString = @"畢法";
    }

    if (newString) {
        NSMutableAttributedString *na = [attributedText mutableCopy];
        [na.mutableString setString:newString];
        %orig(na);
        return;
    }

    NSMutableAttributedString *out = [attributedText mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)out.mutableString, NULL, CFSTR("Hans-Hant"), false);
    %orig(out);
}

%end   // UILabel


///--- 浮水印 -----------------------------------------------------------------

static UIImage *createWatermarkImage(NSString *text,
                                     UIFont   *font,
                                     UIColor  *color,
                                     CGSize    tileSize,
                                     CGFloat   angleDeg)
{
    UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    CGContextTranslateCTM(ctx, tileSize.width/2.0, tileSize.height/2.0);
    CGContextRotateCTM   (ctx, angleDeg * M_PI / 180.0);

    [text drawAtPoint:CGPointZero
       withAttributes:@{
           NSFontAttributeName            : font,
           NSForegroundColorAttributeName : color
       }];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

%hook UIWindow

- (void)layoutSubviews
{
    %orig;

    if (self.windowLevel != UIWindowLevelNormal) return;

    const NSInteger kTag = 998877;

    if ([self viewWithTag:kTag]) return;      // 已經有浮水印

    UIImage *pattern =
        createWatermarkImage(@"Echo訂製",
                             [UIFont systemFontOfSize:16],
                             [[UIColor blackColor] colorWithAlphaComponent:0.12],
                             CGSizeMake(150, 100),
                             -30.0);

    UIView *mask = [[UIView alloc] initWithFrame:self.bounds];
    mask.tag                   = kTag;
    mask.userInteractionEnabled = NO;
    mask.autoresizingMask       = UIViewAutoresizingFlexibleWidth |
                                   UIViewAutoresizingFlexibleHeight;
    mask.backgroundColor        = [UIColor colorWithPatternImage:pattern];

    [self addSubview:mask];
    [self bringSubviewToFront:mask];
}

%end   // UIWindow


#pragma mark ------------------------------------------------------------------
#pragma mark Section 2 – 一鍵「複製到 AI」按鈕 + 內容擷取
#pragma mark ------------------------------------------------------------------

static NSInteger const kCopyAiBtnTag = 112233;

@interface UIViewController (EchoCopyAddon)
- (void)copyAiButtonTapped_FinalPerfect;
- (void)findSubviewsOfClass:(Class)c inView:(UIView *)v store:(NSMutableArray *)bag;
- (NSString *)extractTextFromFirstViewOfClass:(NSString *)clsName sep:(NSString *)sep;
@end


%hook UIViewController

// ────────────────────────────────────────────────────────
- (void)viewDidLoad
{
    %orig;

    Class target = NSClassFromString(@"六壬大占.ViewController");
    if (!target || ![self isKindOfClass:target]) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.10 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{

        UIWindow *win = self.view.window;
        if (!win || [win viewWithTag:kCopyAiBtnTag]) return;

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.tag   = kCopyAiBtnTag;
        btn.frame = CGRectMake(win.bounds.size.width - 100, 45, 90, 36);

        [btn setTitle:@"複製到AI" forState:UIControlStateNormal];
        btn.titleLabel.font      = [UIFont boldSystemFontOfSize:14];
        btn.backgroundColor      = [UIColor colorWithRed:0.20 green:0.60 blue:0.86 alpha:1.0];
        btn.layer.cornerRadius   = 8.0;
        [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];

        [btn addTarget:self
                action:@selector(copyAiButtonTapped_FinalPerfect)
      forControlEvents:UIControlEventTouchUpInside];

        [win addSubview:btn];
    });
}

// ────────────────────────────────────────────────────────
%new
- (void)findSubviewsOfClass:(Class)c inView:(UIView *)v store:(NSMutableArray *)bag
{
    if ([v isKindOfClass:c]) [bag addObject:v];
    for (UIView *sub in v.subviews)
        [self findSubviewsOfClass:c inView:sub store:bag];
}

// ────────────────────────────────────────────────────────
%new
- (NSString *)extractTextFromFirstViewOfClass:(NSString *)clsName sep:(NSString *)sep
{
    Class vc = NSClassFromString(clsName);
    if (!vc) return @"";

    NSMutableArray *views = [NSMutableArray array];
    [self findSubviewsOfClass:vc inView:self.view store:views];
    if (views.count == 0) return @"";

    UIView *container = views.firstObject;

    NSMutableArray *labels = [NSMutableArray array];
    [self findSubviewsOfClass:[UILabel class] inView:container store:labels];

    // 由上而下、再由左而右排序
    [labels sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
        if (fabs(a.frame.origin.y - b.frame.origin.y) > 0.5)
            return a.frame.origin.y < b.frame.origin.y ? NSOrderedAscending : NSOrderedDescending;
        return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
    }];

    NSMutableArray *texts = [NSMutableArray array];
    for (UILabel *lb in labels)
        if (lb.text.length) [texts addObject:lb.text];

    return [texts componentsJoinedByString:sep];
}


// ────────────────────────────────────────────────────────
//   核心：呼叫「顯示七政 / 顯示格局」→ 等0.1s → 擷取 → 複製
// ────────────────────────────────────────────────────────
%new
- (void)copyAiButtonTapped_FinalPerfect
{
    // ========== 1. 預先觸發懶加載 / 彈窗 ========== //

    NSArray<NSString *> *selNamesQiZheng = @[
        @"顯示七政資訊WithSender:",   // 繁
        @"显示七政信息WithSender:"    // 簡（原碼）
    ];
    NSArray<NSString *> *selNamesBiFa   = @[
        @"顯示格局總覽WithSender:",
        @"显示格局总览WithSender:"
    ];

    auto callIfExist = ^(NSArray<NSString *> *candidates){
        for (NSString *name in candidates) {
            SEL s = NSSelectorFromString(name);
            if ([self respondsToSelector:s]) {
                ((void (*)(id, SEL, id))objc_msgSend)(self, s, nil);
                break;
            }
        }
    };

    callIfExist(selNamesQiZheng);
    callIfExist(selNamesBiFa);

    // ========== 2. 0.1 秒後開始擷取 ========== //
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.10 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{

        #define S(str) (str ?: @"")

        // -- 基本區塊 -------------------------------------------------------- //
        NSString *timeBlock = [[self extractTextFromFirstViewOfClass:@"六壬大占.年月日時視圖" sep:@" "]
                               stringByReplacingOccurrencesOfString:@"\n" withString:@" "];

        NSString *yueJiang  = [self extractTextFromFirstViewOfClass:@"六壬大占.七政視圖"    sep:@" "];
        NSString *kongWang  = [self extractTextFromFirstViewOfClass:@"六壬大占.旬空視圖"    sep:@" "];
        NSString *sanGong   = [self extractTextFromFirstViewOfClass:@"六壬大占.三宮時視圖"  sep:@" "];
        NSString *zhouYe    = [self extractTextFromFirstViewOfClass:@"六壬大占.晝夜切換視圖" sep:@" "];
        NSString *fullKeti  = [self extractTextFromFirstViewOfClass:@"六壬大占.課體視圖"    sep:@" "];
        NSString *biFa      = [self extractTextFromFirstViewOfClass:@"六壬大占.格局單元"    sep:@" "];
        NSString *method    = [self extractTextFromFirstViewOfClass:@"六壬大占.九宗門視圖"  sep:@" "];

        // -- 四課 ------------------------------------------------------------ //
        NSMutableString *siKe = [NSMutableString string];
        Class siKeClass = NSClassFromString(@"六壬大占.四課視圖");
        if (siKeClass) {
            NSMutableArray *skViews = [NSMutableArray array];
            [self findSubviewsOfClass:siKeClass inView:self.view store:skViews];

            if (skViews.count) {
                UIView *c = skViews.firstObject;

                NSMutableArray *lbls = [NSMutableArray array];
                [self findSubviewsOfClass:[UILabel class] inView:c store:lbls];

                if (lbls.count >= 12) {
                    // 依 x 分四欄，依 y 排序
                    NSMutableDictionary<NSNumber *, NSMutableArray<UILabel *> *> *cols = [NSMutableDictionary dictionary];
                    for (UILabel *l in lbls) {
                        NSNumber *key = @(round(CGRectGetMidX(l.frame)));
                        (cols[key] ?: (cols[key] = [NSMutableArray array])).addObject(l);
                    }
                    if (cols.allKeys.count == 4) {
                        NSArray *keys = [cols.allKeys sortedArrayUsingSelector:@selector(compare:)];
                        for (NSNumber *k in keys)
                            [cols[k] sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
                                return a.frame.origin.y < b.frame.origin.y ? NSOrderedAscending : NSOrderedDescending;
                            }];

                        NSArray *k1 = cols[keys[3]], *k2 = cols[keys[2]],
                                *k3 = cols[keys[1]], *k4 = cols[keys[0]];

                        [siKe appendFormat:@"第一課: %@->%@%@\n",
                         S(((UILabel *)k1[2]).text), S(((UILabel *)k1[1]).text), S(((UILabel *)k1[0]).text)];
                        [siKe appendFormat:@"第二課: %@->%@%@\n",
                         S(((UILabel *)k2[2]).text), S(((UILabel *)k2[1]).text), S(((UILabel *)k2[0]).text)];
                        [siKe appendFormat:@"第三課: %@->%@%@\n",
                         S(((UILabel *)k3[2]).text), S(((UILabel *)k3[1]).text), S(((UILabel *)k3[0]).text)];
                        [siKe appendFormat:@"第四課: %@->%@%@",
                         S(((UILabel *)k4[2]).text), S(((UILabel *)k4[1]).text), S(((UILabel *)k4[0]).text)];
                    }
                }
            }
        }

        // -- 三傳 ------------------------------------------------------------ //
        NSMutableString *sanChuan = [NSMutableString string];
        Class sanChuanClass = NSClassFromString(@"六壬大占.傳視圖");
        if (sanChuanClass) {
            NSMutableArray *v = [NSMutableArray array];
            [self findSubviewsOfClass:sanChuanClass inView:self.view store:v];
            [v sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
                return a.frame.origin.y < b.frame.origin.y ? NSOrderedAscending : NSOrderedDescending;
            }];

            NSArray *title = @[ @"初傳:", @"中傳:", @"末傳:" ];
            for (NSUInteger i = 0; i < v.count; ++i) {
                NSMutableArray *lbls = [NSMutableArray array];
                [self findSubviewsOfClass:[UILabel class] inView:v[i] store:lbls];
                [lbls sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
                    return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
                }];

                if (lbls.count >= 3) {
                    NSString *liuQin   = ((UILabel *)lbls.firstObject).text;
                    NSString *tianJiang= ((UILabel *)lbls.lastObject).text;
                    NSString *diZhi    = ((UILabel *)lbls[lbls.count-2]).text;

                    NSMutableArray *sha = [NSMutableArray array];
                    if (lbls.count > 3) {
                        for (NSUInteger j = 1; j+2 < lbls.count; ++j) {
                            UILabel *l = lbls[j];
                            if (l.text.length) [sha addObject:l.text];
                        }
                    }
                    NSString *ss = sha.count ? [NSString stringWithFormat:@" (%@)", [sha componentsJoinedByString:@" "]] : @"";

                    [sanChuan appendFormat:@"%@ %@->%@%@%@\n",
                     (i<title.count ? title[i] : @""),
                     S(liuQin), S(diZhi), S(tianJiang), ss];
                }
            }
            if (sanChuan.length) [sanChuan deleteCharactersInRange:NSMakeRange(sanChuan.length-1, 1)]; // 去掉最後 \n
        }

        // ========== 3. 組合 & 複製 ========== //
        NSString *final =
        [NSString stringWithFormat:
            @"%@\n\n"
            @"月將: %@\n"
            @"空亡: %@\n"
            @"三宮時: %@\n"
            @"晝夜: %@\n"
            @"課體: %@\n"
            @"畢法: %@\n\n"
            @"%@\n\n"
            @"%@\n\n"
            @"起課方式: %@",
            S(timeBlock),
            S(yueJiang), S(kongWang), S(sanGong), S(zhouYe), S(fullKeti), S(biFa),
            S(siKe),
            S(sanChuan),
            S(method)
        ];

        [UIPasteboard generalPasteboard].string = final;

        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"已複製到剪貼簿"
                                                                   message:final
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
    });
}

%end   // UIViewController
