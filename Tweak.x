//
//  EchoAddon.xm
//  直接放進 yourTweak/ 目錄，確定檔名「.xm」再 make
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark ------------------------------------------------------------------
#pragma mark UILabel & UIWindow：繁體轉換 + 浮水印
#pragma mark ------------------------------------------------------------------

%hook UILabel

- (void)setText:(NSString *)text {
    if (!text) { %orig(text); return; }

    NSString *new = nil;
    if ([text isEqualToString:@"我的分類"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"])
        new = @"Echo";
    else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"])
        new = @"訂製";
    else if ([text isEqualToString:@"法訣"] || [text isEqualToString:@"法诀"])
        new = @"畢法";

    if (new) { %orig(new); return; }

    NSMutableString *tc = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)tc, NULL, CFSTR("Hans-Hant"), false);
    %orig(tc);
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) { %orig(attributedText); return; }

    NSString *src = attributedText.string;
    NSString *new = nil;
    if ([src isEqualToString:@"我的分類"] || [src isEqualToString:@"我的分類"] || [src isEqualToString:@"通類"])
        new = @"Echo";
    else if ([src isEqualToString:@"起課"] || [src isEqualToString:@"起课"])
        new = @"訂製";
    else if ([src isEqualToString:@"法訣"] || [src isEqualToString:@"法诀"])
        new = @"畢法";

    if (new) {
        NSMutableAttributedString *na = [attributedText mutableCopy];
        [na.mutableString setString:new];
        %orig(na);
        return;
    }

    NSMutableAttributedString *tc = [attributedText mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)tc.mutableString, NULL, CFSTR("Hans-Hant"), false);
    %orig(tc);
}

%end   // UILabel


///--- 浮水印 -----------------------------------------------------------------

static UIImage *MakeWatermark(NSString *txt, UIFont *font, UIColor *color,
                              CGSize tile, CGFloat deg)
{
    UIGraphicsBeginImageContextWithOptions(tile, NO, 0);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(c, tile.width/2.0, tile.height/2.0);
    CGContextRotateCTM   (c, deg * M_PI/180.0);

    [txt drawAtPoint:CGPointZero
      withAttributes:@{ NSFontAttributeName : font,
                        NSForegroundColorAttributeName : color }];

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

%hook UIWindow

- (void)layoutSubviews {
    %orig;

    if (self.windowLevel != UIWindowLevelNormal) return;

    const NSInteger kTag = 998877;
    if ([self viewWithTag:kTag]) return;

    UIImage *pattern = MakeWatermark(@"Echo訂製",
                                     [UIFont systemFontOfSize:16],
                                     [[UIColor blackColor] colorWithAlphaComponent:0.12],
                                     CGSizeMake(150,100),
                                     -30);

    UIView *v = [[UIView alloc] initWithFrame:self.bounds];
    v.tag = kTag;
    v.userInteractionEnabled = NO;
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    v.backgroundColor = [UIColor colorWithPatternImage:pattern];

    [self addSubview:v];
    [self bringSubviewToFront:v];
}

%end   // UIWindow



#pragma mark ------------------------------------------------------------------
#pragma mark 「複製到 AI」按鈕 + 內容擷取
#pragma mark ------------------------------------------------------------------

static NSInteger const kCopyBtnTag = 112233;

@interface UIViewController (EchoCopy)
- (void)copyAiBtnTap;
- (void)findSubviews:(Class)c in:(UIView *)v store:(NSMutableArray *)bag;
- (NSString *)grabTextInFirstView:(NSString *)cls sep:(NSString *)sep;
@end


%hook UIViewController

// ── 加按鈕 ───────────────────────────────────────────────
- (void)viewDidLoad {
    %orig;

    Class target = NSClassFromString(@"六壬大占.ViewController");
    if (!target || ![self isKindOfClass:target]) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.10*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindow *w = self.view.window;
        if (!w || [w viewWithTag:kCopyBtnTag]) return;

        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        b.tag   = kCopyBtnTag;
        b.frame = CGRectMake(w.bounds.size.width-100, 45, 90, 36);
        [b setTitle:@"複製到AI" forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        b.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1];
        b.layer.cornerRadius = 8;
        [b addTarget:self action:@selector(copyAiBtnTap) forControlEvents:UIControlEventTouchUpInside];
        [w addSubview:b];
    });
}

// ── 小工具 ───────────────────────────────────────────────
%new
- (void)findSubviews:(Class)c in:(UIView *)v store:(NSMutableArray *)bag {
    if ([v isKindOfClass:c]) [bag addObject:v];
    for (UIView *s in v.subviews) [self findSubviews:c in:s store:bag];
}

%new
- (NSString *)grabTextInFirstView:(NSString *)cls sep:(NSString *)sep {
    Class k = NSClassFromString(cls);
    if (!k) return @"";
    NSMutableArray *ary = [NSMutableArray array];
    [self findSubviews:k in:self.view store:ary];
    if (!ary.count) return @"";

    UIView *container = ary.firstObject;
    NSMutableArray *lbls = [NSMutableArray array];
    [self findSubviews:[UILabel class] in:container store:lbls];

    [lbls sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
        if (fabs(a.frame.origin.y - b.frame.origin.y) > 0.5)
            return a.frame.origin.y < b.frame.origin.y ? NSOrderedAscending : NSOrderedDescending;
        return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
    }];

    NSMutableArray *txts = [NSMutableArray array];
    for (UILabel *l in lbls) if (l.text.length) [txts addObject:l.text];
    return [txts componentsJoinedByString:sep];
}

// ── 主流程 ───────────────────────────────────────────────
%new
- (void)copyAiBtnTap {

    // 1️⃣ 先暗中觸發「顯示七政 / 顯示格局」selector
    NSArray *selQiZheng = @[ @"顯示七政資訊WithSender:", @"显示七政信息WithSender:" ];
    NSArray *selBiFa    = @[ @"顯示格局總覽WithSender:", @"显示格局总览WithSender:" ];

    void (^callIf)(NSArray<NSString *> *) = ^(NSArray<NSString *> *cands){
        for (NSString *n in cands) {
            SEL s = NSSelectorFromString(n);
            if ([self respondsToSelector:s]) {
                ((void (*)(id,SEL,id))objc_msgSend)(self, s, nil);
                break;
            }
        }
    };
    callIf(selQiZheng);
    callIf(selBiFa);

    // 2️⃣ 0.1 s 後擷取
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.10*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{

        #define S(x) ((x) ?: @"")

        NSString *timeBlk = [[self grabTextInFirstView:@"六壬大占.年月日時視圖" sep:@" "]
                             stringByReplacingOccurrencesOfString:@"\n" withString:@" "];

        NSString *yueJiang = [self grabTextInFirstView:@"六壬大占.七政視圖"     sep:@" "];
        NSString *kongWang = [self grabTextInFirstView:@"六壬大占.旬空視圖"     sep:@" "];
        NSString *sanGong  = [self grabTextInFirstView:@"六壬大占.三宮時視圖"   sep:@" "];
        NSString *zhouYe   = [self grabTextInFirstView:@"六壬大占.晝夜切換視圖" sep:@" "];
        NSString *keTi     = [self grabTextInFirstView:@"六壬大占.課體視圖"     sep:@" "];
        NSString *biFa     = [self grabTextInFirstView:@"六壬大占.格局單元"     sep:@" "];
        NSString *method   = [self grabTextInFirstView:@"六壬大占.九宗門視圖"   sep:@" "];

        // ── 四課 ───────────────────────────────────────
        NSMutableString *siKe = [NSMutableString string];
        Class siKeCls = NSClassFromString(@"六壬大占.四課視圖");
        if (siKeCls) {
            NSMutableArray *sk = [NSMutableArray array];
            [self findSubviews:siKeCls in:self.view store:sk];
            if (sk.count) {
                UIView *c = sk.firstObject;
                NSMutableArray *lbls = [NSMutableArray array];
                [self findSubviews:[UILabel class] in:c store:lbls];

                if (lbls.count >= 12) {
                    // column 分組
                    NSMutableDictionary<NSNumber *, NSMutableArray<UILabel *> *> *cols = [NSMutableDictionary dictionary];
                    for (UILabel *l in lbls) {
                        NSNumber *key = @(round(CGRectGetMidX(l.frame)));
                        NSMutableArray *arr = cols[key];
                        if (!arr) { arr = [NSMutableArray array]; cols[key] = arr; }
                        [arr addObject:l];
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

        // ── 三傳 ───────────────────────────────────────
        NSMutableString *sanChuan = [NSMutableString string];
        Class scCls = NSClassFromString(@"六壬大占.傳視圖");
        if (scCls) {
            NSMutableArray *v = [NSMutableArray array];
            [self findSubviews:scCls in:self.view store:v];
            [v sortUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
                return a.frame.origin.y < b.frame.origin.y ? NSOrderedAscending : NSOrderedDescending;
            }];
            NSArray *title = @[ @"初傳:", @"中傳:", @"末傳:" ];
            for (NSUInteger i = 0; i < v.count; ++i) {
                NSMutableArray *lbls = [NSMutableArray array];
                [self findSubviews:[UILabel class] in:v[i] store:lbls];
                [lbls sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) {
                    return a.frame.origin.x < b.frame.origin.x ? NSOrderedAscending : NSOrderedDescending;
                }];

                if (lbls.count >= 3) {
                    NSString *liuQin = ((UILabel *)lbls.firstObject).text;
                    NSString *tianJ  = ((UILabel *)lbls.lastObject).text;
                    NSString *diZhi  = ((UILabel *)lbls[lbls.count-2]).text;

                    NSMutableArray *sha = [NSMutableArray array];
                    if (lbls.count > 3)
                        for (NSUInteger j=1; j+2<lbls.count; ++j) {
                            UILabel *l = lbls[j];
                            if (l.text.length) [sha addObject:l.text];
                        }

                    NSString *ss = sha.count ? [NSString stringWithFormat:@" (%@)", [sha componentsJoinedByString:@" "]] : @"";
                    [sanChuan appendFormat:@"%@ %@->%@%@%@\n",
                     (i<title.count ? title[i] : @""), S(liuQin), S(diZhi), S(tianJ), ss];
                }
            }
            if (sanChuan.length) [sanChuan deleteCharactersInRange:NSMakeRange(sanChuan.length-1,1)];
        }

        // 3️⃣ 複製 + Alert
        NSString *out =
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
         S(timeBlk),
         S(yueJiang), S(kongWang), S(sanGong), S(zhouYe), S(keTi), S(biFa),
         S(siKe),
         S(sanChuan),
         S(method)];

        [UIPasteboard generalPasteboard].string = out;

        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"已複製到剪貼簿"
                                                                   message:out
                                                            preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
    });
}

%end   // UIViewController
