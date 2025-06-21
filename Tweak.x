/*****************************************************************
 *  Tweak.x  —  MyTweak
 *  Tested: Theos  15.x  •  iOS 15  arm64  •  -Werror 默认为开
 *****************************************************************/

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

%config(generator=internal)   // 让 Logos 用“内部分类”生成方式

#pragma mark - ————— 前向声明，解决 selector 未知报错 —————
@interface UIViewController (CopyAiForward)
- (void)findSubviewsOfClass:(Class)cls inView:(UIView *)view andStoreIn:(NSMutableArray *)out;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)clsName separator:(NSString *)sep;
- (NSString *)extractTextFromCollectionViewDataSourceWithViewClassName:(NSString *)clsName;
- (NSString *)extractTextFromTableViewDataSourceWithViewClassName:(NSString *)clsName;
- (void)copyAiButtonTapped_FinalPerfect;
@end                     // ←←← 千万别漏掉这个 @end

//================================================================
//  ① UILabel：文字替换 & 简繁转换
//================================================================
%hook UILabel
- (void)setText:(NSString *)t {
    if (!t) { %orig(t); return; }
    if ([t isEqual:@"我的分类"]||[t isEqual:@"我的分類"]||[t isEqual:@"通類"]) { %orig(@"Echo"); return; }
    if ([t isEqual:@"起課"]   ||[t isEqual:@"起课"])   { %orig(@"定制"); return; }
    if ([t isEqual:@"法诀"]   ||[t isEqual:@"法訣"])   { %orig(@"毕法"); return; }
    NSMutableString *s = [t mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)s, NULL, CFSTR("Hant-Hans"), false);
    %orig(s);
}

- (void)setAttributedText:(NSAttributedString *)a {
    if (!a) { %orig(a); return; }
    NSMutableAttributedString *m = [a mutableCopy];
    NSString *ori = m.string;
    if ([ori isEqual:@"我的分类"]||[ori isEqual:@"我的分類"]||[ori isEqual:@"通類"]) { [m.mutableString setString:@"Echo"]; }
    else if ([ori isEqual:@"起課"]||[ori isEqual:@"起课"]) { [m.mutableString setString:@"定制"]; }
    else if ([ori isEqual:@"法诀"]||[ori isEqual:@"法訣"]) { [m.mutableString setString:@"毕法"]; }
    else { CFStringTransform((__bridge CFMutableStringRef)m.mutableString, NULL, CFSTR("Hant-Hans"), false); }
    %orig(m);
}
%end

//================================================================
//  ② UIWindow：透明水印
//================================================================
static UIImage *WmImg(NSString *txt, UIFont *f, UIColor *c, CGSize sz, CGFloat ang) {
    UIGraphicsBeginImageContextWithOptions(sz, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, sz.width/2, sz.height/2);
    CGContextRotateCTM(ctx, ang*M_PI/180);
    CGRect r = CGRectMake(-sz.width/2, -sz.height/2, sz.width, sz.height);
    [txt drawInRect:r withAttributes:@{NSFontAttributeName:f, NSForegroundColorAttributeName:c}];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext(); return img;
}

%hook UIWindow
- (void)layoutSubviews {
    %orig;
    if (self.windowLevel!=UIWindowLevelNormal) return;
    if ([self viewWithTag:998877]) return;
    UIView *v=[[UIView alloc]initWithFrame:self.bounds];
    v.tag=998877; v.userInteractionEnabled=NO;
    v.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    v.backgroundColor=[UIColor colorWithPatternImage:
        WmImg(@"Echo定制",[UIFont systemFontOfSize:16],
              [[UIColor blackColor]colorWithAlphaComponent:0.12],
              CGSizeMake(150,100),-30)];
    [self addSubview:v];
}
%end

//================================================================
//  ③ UIViewController：按钮 + 抓取工具 + 复制主逻辑
//================================================================
static NSInteger const kBtnTag = 112233;
#define SAFE(x) ((x)?(x):@"")

%hook UIViewController
//------------------------------------------------------ viewDidLoad
- (void)viewDidLoad {
    %orig;
    if (![self isKindOfClass:NSClassFromString(@"六壬大占.ViewController")]) return;   //❶主 VC 类名
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1*NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIWindow *w=self.view.window; if(!w||[w viewWithTag:kBtnTag])return;
        UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
        b.tag=kBtnTag; b.frame=CGRectMake(w.bounds.size.width-100,45,90,36);
        b.layer.cornerRadius=8; b.backgroundColor=[UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1];
        [b setTitle:@"复制到AI" forState:UIControlStateNormal];
        [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        b.titleLabel.font=[UIFont boldSystemFontOfSize:14];
        [b addTarget:self action:@selector(copyAiButtonTapped_FinalPerfect)
           forControlEvents:UIControlEventTouchUpInside];
        [w addSubview:b];
    });
}

//------------------------------------------------  递归找子视图
%new
- (void)findSubviewsOfClass:(Class)cls inView:(UIView *)v andStoreIn:(NSMutableArray *)out {
    if ([v isKindOfClass:cls]) [out addObject:v];
    for (UIView *s in v.subviews) [self findSubviewsOfClass:cls inView:s andStoreIn:out];
}

//------------------------------------------------  扫 UILabel
%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)clsName separator:(NSString *)sep {
    Class c=NSClassFromString(clsName); if(!c) return @"";
    NSMutableArray *vs=[NSMutableArray array]; [self findSubviewsOfClass:c inView:self.view andStoreIn:vs];
    UIView *box=vs.firstObject; if(!box) return @"";
    NSMutableArray *lbls=[NSMutableArray array]; [self findSubviewsOfClass:[UILabel class] inView:box andStoreIn:lbls];
    [lbls sortUsingComparator:^NSComparisonResult(UILabel*a,UILabel*b){
        if (fabs(a.frame.origin.y-b.frame.origin.y)>0.1)
            return a.frame.origin.y<b.frame.origin.y?NSOrderedAscending:NSOrderedDescending;
        return a.frame.origin.x<b.frame.origin.x?NSOrderedAscending:NSOrderedDescending;
    }];
    NSMutableArray *arr=[NSMutableArray array]; for(UILabel*l in lbls) if(l.text.length)[arr addObject:l.text];
    return [arr componentsJoinedByString:sep];
}

//-------------------------------------------  抓 CollectionView
%new
- (NSString *)extractTextFromCollectionViewDataSourceWithViewClassName:(NSString *)clsName {
    Class vc=NSClassFromString(clsName); if(!vc) return nil;
    NSMutableArray *vs=[NSMutableArray array]; [self findSubviewsOfClass:vc inView:self.view andStoreIn:vs];
    UICollectionView *cv=(UICollectionView*)vs.firstObject;
    if(![cv isKindOfClass:[UICollectionView class]]) return nil;
    id<UICollectionViewDataSource> ds=cv.dataSource ?: (id)self;
    if(![ds conformsToProtocol:@protocol(UICollectionViewDataSource)]) return nil;
    NSInteger sec=[ds respondsToSelector:@selector(numberOfSectionsInCollectionView:)]?[ds numberOfSectionsInCollectionView:cv]:1;
    NSMutableArray *rows=[NSMutableArray array];
    for(NSInteger s=0;s<sec;s++){
        NSInteger it=[ds collectionView:cv numberOfItemsInSection:s];
        for(NSInteger i=0;i<it;i++){
            NSIndexPath *ip=[NSIndexPath indexPathForItem:i inSection:s];
            UICollectionViewCell *cell=[ds collectionView:cv cellForItemAtIndexPath:ip];
            NSMutableArray *labs=[NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:cell.contentView andStoreIn:labs];
            [labs sortUsingComparator:^NSComparisonResult(UILabel*a,UILabel*b){return a.frame.origin.x<b.frame.origin.x?NSOrderedAscending:NSOrderedDescending;}];
            NSMutableString *line=[NSMutableString string];
            for(UILabel*l in labs) if(l.text.length)[line appendFormat:@"%@ ",l.text];
            NSString *trim=[line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            if(trim.length)[rows addObject:trim];
        }}
    return rows.count?[rows componentsJoinedByString:@"\n"]:nil;
}

//-------------------------------------------  抓 TableView
%new
- (NSString *)extractTextFromTableViewDataSourceWithViewClassName:(NSString *)clsName {
    Class tvc=NSClassFromString(clsName); if(!tvc) return nil;
    NSMutableArray *vs=[NSMutableArray array]; [self findSubviewsOfClass:tvc inView:self.view andStoreIn:vs];
    UITableView *tv=(UITableView*)vs.firstObject;
    if(![tv isKindOfClass:[UITableView class]]) return nil;
    id<UITableViewDataSource> ds=tv.dataSource ?: (id)self;
    if(![ds conformsToProtocol:@protocol(UITableViewDataSource)]) return nil;
    NSInteger sec=[ds respondsToSelector:@selector(numberOfSectionsInTableView:)]?[ds numberOfSectionsInTableView:tv]:1;
    NSMutableArray *rows=[NSMutableArray array];
    for(NSInteger s=0;s<sec;s++){
        NSInteger cnt=[ds tableView:tv numberOfRowsInSection:s];
        for(NSInteger r=0;r<cnt;r++){
            NSIndexPath *ip=[NSIndexPath indexPathForRow:r inSection:s];
            UITableViewCell *cell=[ds tableView:tv cellForRowAtIndexPath:ip];
            NSMutableArray *labs=[NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:cell.contentView andStoreIn:labs];
            [labs sortUsingComparator:^NSComparisonResult(UILabel*a,UILabel*b){return a.frame.origin.x<b.frame.origin.x?NSOrderedAscending:NSOrderedDescending;}];
            NSMutableString *line=[NSMutableString string];
            for(UILabel*l in labs) if(l.text.length)[line appendFormat:@"%@ ",l.text];
            NSString *trim=[line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            if(trim.length)[rows addObject:trim];
        }}
    return rows.count?[rows componentsJoinedByString:@"\n"]:nil;
}

//-------------------------------------------  复制到剪贴板主逻辑
%new
- (void)copyAiButtonTapped_FinalPerfect {

    /*↓———— ❷–❺: 下面 3 行类名先换成你真实的容器类名 ————↓*/
    NSString *biFa = [self extractTextFromTableViewDataSourceWithViewClassName:@"六壬大占.格局總覽視圖"] ?:
                     [self extractTextFromCollectionViewDataSourceWithViewClassName:@"六壬大占.格局總覽視圖"] ?:
                     [self extractTextFromFirstViewOfClassName:@"六壬大占.格局總覽視圖" separator:@"\n"];

    NSString *qiZheng = [self extractTextFromTableViewDataSourceWithViewClassName:@"六壬大占.七政信息視圖"] ?:
                        [self extractTextFromCollectionViewDataSourceWithViewClassName:@"六壬大占.七政信息視圖"] ?:
                        [self extractTextFromFirstViewOfClassName:@"六壬大占.七政信息視圖" separator:@"\n"];
    /*↑———————————————————————————————————————————————↑*/

    // 固定信息
    NSString *timeBlk=[[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *yueJiang=[self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    NSString *kongWang=[self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@" "];
    NSString *sanGong=[self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    NSString *zhouYe=[self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    NSString *keTi=[self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    NSString *method=[self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];

    /* ❻ TODO: 这里把你的“四课 / 三传”算法粘过来 */
    NSString *siKe     = @"(四课占位)";
    NSString *sanChuan = @"(三传占位)";

    // 拼装输出
    NSMutableString *out=[NSMutableString string];
    [out appendFormat:@"%@\n\n",SAFE(timeBlk)];
    [out appendFormat:@"月将: %@\n空亡: %@\n三宫时: %@\n昼夜: %@\n课体: %@\n\n",
        SAFE(yueJiang),SAFE(kongWang),SAFE(sanGong),SAFE(zhouYe),SAFE(keTi)];
    [out appendFormat:@"%@\n%@\n\n",SAFE(siKe),SAFE(sanChuan)];
    if(biFa.length)[out appendFormat:@"毕法:\n%@\n\n",biFa];
    if(qiZheng.length)[out appendFormat:@"七政:\n%@\n\n",qiZheng];
    [out appendFormat:@"起课方式: %@",SAFE(method)];

    NSString *final=[out stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [UIPasteboard generalPasteboard].string=final;

    UIAlertController *al=[UIAlertController alertControllerWithTitle:@"已复制到剪贴板"
                                                              message:final
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [al addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:al animated:YES completion:nil];
}
%end   // UIViewController

/*———————————— 文件结束 ————————————*/
