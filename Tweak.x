#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - 数据结构
typedef NS_ENUM(NSUInteger, EKWorkType) { EKWorkTypeDiZhi, EKWorkTypeTianJiang };

@interface EKWorkItem : NSObject
@property (nonatomic, weak)   UIView   *sender;   ///< 傳視圖
@property (nonatomic, assign) EKWorkType type;    ///< 地支 or 天将
@property (nonatomic, copy)   NSString *title;    ///< 标题
@end
@implementation EKWorkItem @end

static BOOL                            g_executing     = NO;
static NSMutableArray<EKWorkItem *>   *g_queue         = nil;
static NSMutableArray<NSString *>     *g_results       = nil;

#pragma mark - Debug Overlay
static UIWindow *dbgWin; static UILabel *dbgLbl;
static void dbg_show(void){
    if (dbgWin) return;
    CGRect f = CGRectMake(0, 60, UIScreen.mainScreen.bounds.size.width, 24);
    dbgWin = [[UIWindow alloc] initWithFrame:f];
    dbgWin.windowLevel = UIWindowLevelAlert + 2;
    dbgWin.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
    dbgLbl = [[UILabel alloc] initWithFrame:dbgWin.bounds];
    dbgLbl.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    dbgLbl.textColor   = [UIColor yellowColor];
    dbgLbl.font        = [UIFont boldSystemFontOfSize:12];
    dbgLbl.textAlignment = NSTextAlignmentCenter;
    [dbgWin addSubview:dbgLbl];
    dbgWin.hidden = NO;

    // 允许拖动
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
       initWithTarget:[NSBlockOperation blockOperationWithBlock:^{
           CGPoint p = [pan locationInView:UIApplication.sharedApplication.keyWindow];
           dbgWin.center = CGPointMake(UIScreen.mainScreen.bounds.size.width/2, p.y);
       }] action:@selector(main)];
    [dbgWin addGestureRecognizer:pan];
}
static void dbg_hide(void){ dbgWin.hidden = YES; dbgWin=nil; dbgLbl=nil; }
static void dbg_update(NSUInteger done, NSUInteger total, NSString *title){
    dbg_show(); dbgLbl.text=[NSString stringWithFormat:@"[%lu/%lu] %@",(unsigned long)done,(unsigned long)total,title];
}

#pragma mark - 工具
static void findSubviews(Class cls, UIView *v, NSMutableArray *out){
    if([v isKindOfClass:cls]) [out addObject:v];
    for(UIView *sub in v.subviews) findSubviews(cls, sub, out);
}

#pragma mark - 主逻辑
@interface UIViewController (EKAddons)
- (void)ek_buildQueue;
- (void)ek_next;
@end

%hook UIViewController
- (void)viewDidLoad{
    %orig;
    if(![self isKindOfClass:NSClassFromString(@"六壬大占.ViewController")]) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        UIButton *b=[UIButton buttonWithType:0];
        b.frame=CGRectMake(self.view.window.bounds.size.width-150,120,140,32);
        b.layer.cornerRadius=6; b.backgroundColor=UIColor.systemGreenColor;
        [b setTitle:@"课传提取(谢罪版)" forState:0]; b.titleLabel.font=[UIFont boldSystemFontOfSize:15];
        [b addTarget:self action:@selector(ek_buildQueue) forControlEvents:UIControlEventTouchUpInside];
        [self.view.window addSubview:b];
    });
}

- (void)presentViewController:(UIViewController*)vc animated:(BOOL)f completion:(void(^)(void))c{
    if(!g_executing){ %orig(vc,f,c); return; }

    NSString *cls=NSStringFromClass([vc class]);
    BOOL ok=[cls containsString:@"課傳摘要視圖"];
    if(!ok){ %orig(vc,f,c); return; }

    vc.view.alpha=0; f=NO;
    __weak __typeof(self)ws=self;
    void(^wrap)(void)=^{
        if(c) c();
        NSMutableArray *lbs=[NSMutableArray array];
        findSubviews([UILabel class], vc.view, lbs);
        [lbs sortUsingComparator:^NSComparisonResult(UILabel* a, UILabel* b){
            if(fabs(a.frame.origin.y-b.frame.origin.y)>0.1)
                return a.frame.origin.y<b.frame.origin.y?NSOrderedAscending:NSOrderedDescending;
            return a.frame.origin.x<b.frame.origin.x?NSOrderedAscending:NSOrderedDescending;
        }];
        NSMutableArray *parts=[NSMutableArray array];
        for(UILabel *lb in lbs) if(lb.text.length) [parts addObject:[lb.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
        [g_results addObject:[parts componentsJoinedByString:@"\n"]];

        [vc dismissViewControllerAnimated:NO completion:^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.05*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ [ws ek_next];});
        }];
    };
    %orig(vc,f,wrap);
}
%end

@implementation UIViewController (EKAddons)

static void setCourseIvar(id selfObj, UIView *row){
    Ivar iv=class_getInstanceVariable([selfObj class], "課傳");
    if(iv) object_setIvar(selfObj, iv, row);
}

- (void)ek_buildQueue{
    if(g_executing) return;
    g_executing=YES; g_queue=[NSMutableArray array]; g_results=[NSMutableArray array];

    Class cont=NSClassFromString(@"六壬大占.三傳視圖");
    NSMutableArray *conts=[NSMutableArray array];
    findSubviews(cont, self.view, conts);
    if(!conts.count){ g_executing=NO; return; }
    UIView *box=conts.firstObject;

    const char *ivn[]={"初傳","中傳","末傳",NULL};
    NSString *tit[] = {@"初传",@"中传",@"末传"};
    for(int i=0;ivn[i];++i){
        Ivar iv=class_getInstanceVariable(cont, ivn[i]); if(!iv)continue;
        UIView *row=object_getIvar(box, iv);
        if(!row)continue;

        NSMutableArray *lbs=[NSMutableArray array]; findSubviews([UILabel class],row,lbs);
        [lbs sortUsingComparator:^NSComparisonResult(UILabel* a, UILabel* b){ return a.frame.origin.x<b.frame.origin.x?NSOrderedAscending:NSOrderedDescending;}];
        NSString *dz= lbs.count>=2 ? ((UILabel*)lbs[lbs.count-2]).text:@"?";
        NSString *tj= lbs.count>=1 ? ((UILabel*)lbs.lastObject).text:@"?";

        // 先存地支，天将插到紧后
        EKWorkItem *di=[EKWorkItem new]; di.sender=row; di.type=EKWorkTypeDiZhi; di.title=[NSString stringWithFormat:@"%@-地支(%@)",tit[i],dz]; [g_queue addObject:di];
        EKWorkItem *tjw=[EKWorkItem new]; tjw.sender=row; tjw.type=EKWorkTypeTianJiang; tjw.title=[NSString stringWithFormat:@"%@-天将(%@)",tit[i],tj]; [g_queue addObject:tjw];
    }
    dbg_show();
    [self ek_next];
}

- (void)ek_next{
    if(!g_queue.count){
        dbg_hide();
        NSMutableString *out=[NSMutableString string];
        [g_results enumerateObjectsUsingBlock:^(NSString* obj,NSUInteger idx,BOOL*stp){
            [out appendFormat:@"--- %@ ---\n%@\n\n",g_results.count>idx?g_queue[idx].title:@"",obj];
        }];
        [UIPasteboard generalPasteboard].string=out;
        UIAlertController *a=[UIAlertController alertControllerWithTitle:@"提取完成"
                                                                 message:@"已复制到剪贴板"
                                                          preferredStyle:0];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:0 handler:nil]];
        [self presentViewController:a animated:YES completion:nil];
        g_executing=NO; g_queue=nil; g_results=nil; return;
    }

    EKWorkItem *it=g_queue.firstObject; [g_queue removeObjectAtIndex:0];
    dbg_update(g_results.count+1, g_results.count+1+g_queue.count, it.title);
    setCourseIvar(self, it.sender);

    SEL sel= it.type==EKWorkTypeDiZhi ?
             NSSelectorFromString(@"顯示課傳摘要WithSender:") :
             NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    if([self respondsToSelector:sel]){
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:sel withObject:it.sender];
#pragma clang diagnostic pop
    } else { [self ek_next]; }
}

@end
