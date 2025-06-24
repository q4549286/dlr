// Tweak.x  (三传自动点击 + HUD + 超时保险)  2025-06-25
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - 🔧 取前台窗口，避免废弃 API
__attribute__((always_inline))
static UIWindow *EKFrontWindow(void){
    for(UIScene *sc in UIApplication.sharedApplication.connectedScenes){
        if(sc.activationState==UISceneActivationStateForegroundActive &&
           [sc isKindOfClass:[UIWindowScene class]]){
            UIWindowScene *ws=(UIWindowScene*)sc;
            for(UIWindow *w in ws.windows) if(w.isKeyWindow) return w;
            return ws.windows.firstObject ?: nil;
        }
    }
    return nil;
}

#pragma mark - 📈 HUD
static UIWindow *ekHUD; static UILabel *ekHUDLabel;
static void EKHUD_show(void){
    if(ekHUD) return;
    ekHUD=[[UIWindow alloc] initWithFrame:CGRectMake(0,44, UIScreen.mainScreen.bounds.size.width,20)];
    ekHUD.windowLevel=UIWindowLevelAlert+3;
    ekHUD.backgroundColor=[UIColor colorWithWhite:0 alpha:0.7];
    ekHUDLabel=[[UILabel alloc] initWithFrame:ekHUD.bounds];
    ekHUDLabel.autoresizingMask=UIViewAutoresizingFlexibleWidth;
    ekHUDLabel.font=[UIFont boldSystemFontOfSize:11];
    ekHUDLabel.textColor=UIColor.greenColor;
    ekHUDLabel.textAlignment=NSTextAlignmentCenter;
    [ekHUD addSubview:ekHUDLabel];
    ekHUD.hidden=NO;
}
static void EKHUD_update(NSString *txt){ EKHUD_show(); ekHUDLabel.text=txt; }
static void EKHUD_hide(void){ ekHUD.hidden=YES; ekHUD=nil; ekHUDLabel=nil; }

#pragma mark - 🗂️ 队列数据
typedef NS_ENUM(NSUInteger, EKType){EKTypeDIZHI,EKTypeTIANJIANG};
@interface EKItem:NSObject
@property(nonatomic,weak)UIView*sender; @property(nonatomic)EKType type; @property(nonatomic,copy)NSString*title;
@end @implementation EKItem @end

static BOOL g_running=NO;
static NSMutableArray<EKItem*> *g_queue=nil;
static int g_idx=1;     // HUD 序号

#pragma mark - 🛠️ 递归找子视图
static void FindSubviews(Class cls, UIView *v, NSMutableArray *out){
    if([v isKindOfClass:cls]) [out addObject:v];
    for(UIView *sub in v.subviews) FindSubviews(cls, sub, out);
}

#pragma mark - 🔑 主控制器扩展
@interface UIViewController (EKRun)
- (void)ek_start;
- (void)ek_next;
- (void)ek_forceNextIfNeeded;
@end

%hook UIViewController

// 给 “六壬大占.ViewController” 注入测试按钮
- (void)viewDidLoad{
    %orig;
    if(![self isKindOfClass:NSClassFromString(@"六壬大占.ViewController")]) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.3*NSEC_PER_SEC)),
                   dispatch_get_main_queue(),^{
        UIWindow *w = EKFrontWindow(); if(!w) return;
        UIButton *btn=[UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame=CGRectMake(w.bounds.size.width-110,100,100,30);
        [btn setTitle:@"三传测试" forState:UIControlStateNormal];
        btn.backgroundColor=UIColor.systemGreenColor;
        btn.layer.cornerRadius=6;
        [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(ek_start) forControlEvents:UIControlEventTouchUpInside];
        [w addSubview:btn];
    });
}

// 拦截弹窗抓文本（这里只演示 HUD 与继续流程）
- (void)presentViewController:(UIViewController*)vc animated:(BOOL)flag completion:(void(^)(void))comp{
    if(!g_running){ %orig(vc,flag,comp); return; }

    NSString *cls=NSStringFromClass([vc class]);
    BOOL isTarget=([cls containsString:@"課傳摘要視圖"]||
                   [cls containsString:@"課傳天將摘要視圖"]);
    if(!isTarget){ %orig(vc,flag,comp); return; }

    vc.view.alpha=0; flag=NO;
    __weak typeof(self)ws=self;
    void(^wrap)(void)=^{
        if(comp) comp();
        // 收完后关闭弹窗
        [vc dismissViewControllerAnimated:NO completion:^{
            // 取消超时回调
            [NSObject cancelPreviousPerformRequestsWithTarget:ws selector:@selector(ek_forceNextIfNeeded) object:nil];
            [ws ek_next];
        }];
    };
    %orig(vc,flag,wrap);
}
%end

@implementation UIViewController (EKRun)

// ① 点击按钮→构建队列
- (void)ek_start{
    if(g_running) return;
    g_running=YES; g_queue=[NSMutableArray array]; g_idx=1;

    Class rowCls=NSClassFromString(@"六壬大占.傳視圖");
    NSMutableArray *rows=[NSMutableArray array];
    FindSubviews(rowCls, self.view, rows);
    [rows sortUsingComparator:^NSComparisonResult(UIView* a, UIView* b){
        return [@(a.frame.origin.y) compare:@(b.frame.origin.y)];
    }];

    NSArray *rTitle=@[@"初传",@"中传",@"末传"];
    for(int i=0;i<rows.count;i++){
        EKItem *di=[EKItem new]; di.sender=rows[i]; di.type=EKTypeDIZHI;    di.title=[NSString stringWithFormat:@"%@-地支",rTitle[i]];  [g_queue addObject:di];
        EKItem *tj=[EKItem new]; tj.sender=rows[i]; tj.type=EKTypeTIANJIANG; tj.title=[NSString stringWithFormat:@"%@-天将",rTitle[i]]; [g_queue addObject:tj];
    }
    EKHUD_update(@"准备开始…");
    [self ek_next];
}

// ② 依次处理
- (void)ek_next{
    if(!g_queue.count){
        EKHUD_update(@"✅ 完成 6/6");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(1.0*NSEC_PER_SEC)),
                       dispatch_get_main_queue(),^{ EKHUD_hide(); });
        g_running=NO; g_queue=nil; return;
    }

    EKItem *it=g_queue.firstObject; [g_queue removeObjectAtIndex:0];
    EKHUD_update([NSString stringWithFormat:@"%d️⃣ %@", g_idx++, it.title]);

    // 修正課傳 ivar
    Ivar iv=class_getInstanceVariable([self class],"課傳");
    if(iv) object_setIvar(self, iv, it.sender);

    SEL sel = (it.type==EKTypeDIZHI)
              ? NSSelectorFromString(@"顯示課傳摘要WithSender:")
              : NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if([self respondsToSelector:sel])
        [self performSelector:sel withObject:it.sender];
#pragma clang diagnostic pop

    // ③ 设置 2 s 超时保险
    [self performSelector:@selector(ek_forceNextIfNeeded) withObject:nil afterDelay:2.0];
}

// ④ 超时保险：若 2 s 还没进入下一步自动继续
- (void)ek_forceNextIfNeeded{
    if(g_running) [self ek_next];
}

@end

// ── ⑤ HUD 拖动实现 ──
%hook UIWindow
- (void)handlePan:(UIPanGestureRecognizer*)pan{
    CGPoint p=[pan locationInView:self.superview ?: EKFrontWindow()];
    self.center=CGPointMake(self.center.x, p.y);
}
%end
