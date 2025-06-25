#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// 全局变量和辅助函数
static UITextView *g_logTextView = nil;
static UIView *g_controlPanelView = nil;
static void LogMessage(NSString *format, ...) { /* ... */ }
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { /* ... */ }

@interface UIViewController (EchoAITestAddons_Truth)
- (void)createOrShowControlPanel_Truth;
- (void)ultimateDetectiveWork_V7;
@end

%hook UIViewController

// viewDidLoad
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger controlButtonTag = 556691;
            if ([keyWindow viewWithTag:controlButtonTag]) { [[keyWindow viewWithTag:controlButtonTag] removeFromSuperview]; }
            UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
            controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            controlButton.tag = controlButtonTag;
            [controlButton setTitle:@"侦测面板" forState:UIControlStateNormal];
            controlButton.backgroundColor = [UIColor redColor]; [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            controlButton.layer.cornerRadius = 8;
            [controlButton addTarget:self action:@selector(createOrShowControlPanel_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:controlButton];
        });
    }
}

%new
- (void)createOrShowControlPanel_Truth {
    UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
    if (g_controlPanelView && g_controlPanelView.superview) {
        [g_controlPanelView removeFromSuperview]; g_controlPanelView = nil; g_logTextView = nil; return;
    }
    g_controlPanelView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, keyWindow.bounds.size.width - 20, 300)];
    g_controlPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85]; g_controlPanelView.layer.cornerRadius = 12;
    
    UIButton *debugButton = [UIButton buttonWithType:UIButtonTypeSystem];
    debugButton.frame = CGRectMake(10, 10, g_controlPanelView.bounds.size.width - 20, 40);
    [debugButton setTitle:@"终极侦测(V7)" forState:UIControlStateNormal];
    [debugButton addTarget:self action:@selector(ultimateDetectiveWork_V7) forControlEvents:UIControlEventTouchUpInside];
    debugButton.backgroundColor = [UIColor systemRedColor]; [debugButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; debugButton.layer.cornerRadius = 8;

    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 60, g_controlPanelView.bounds.size.width - 20, g_controlPanelView.bounds.size.height - 70)];
    g_logTextView.backgroundColor = [UIColor blackColor]; g_logTextView.textColor = [UIColor greenColor]; g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12]; g_logTextView.editable = NO;
    g_logTextView.text = @"V7 侦探脚本已准备就绪。\n";
    
    [g_controlPanelView addSubview:debugButton];
    [g_controlPanelView addSubview:g_logTextView];
    [keyWindow addSubview:g_controlPanelView];
}

%new
- (void)ultimateDetectiveWork_V7 {
    LogMessage(@"--- V7 终极侦探开始工作 ---");
    Class keTiViewClass = NSClassFromString(@"六壬大占.課體視圖");
    if (!keTiViewClass) { LogMessage(@"【侦探】错误: 找不到 課體視圖 类。"); return; }
    
    NSMutableArray *keTiViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(keTiViewClass, self.view, keTiViews);
    if (keTiViews.count == 0) { LogMessage(@"【侦探】错误: 找不到 課體視圖 实例。"); return; }
    
    UICollectionView *keTiCollectionView = (UICollectionView *)keTiViews.firstObject;
    LogMessage(@"【侦探】已定位 課體視圖: %@", keTiCollectionView);

    if (keTiCollectionView.gestureRecognizers.count == 0) {
        LogMessage(@"【侦探】致命错误: 課體視圖 上没有任何手势！");
        return;
    }

    UIGestureRecognizer *gesture = keTiCollectionView.gestureRecognizers.firstObject;
    LogMessage(@"【侦探】已定位手势: %@", gesture);

    Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
    if (!targetsIvar) { LogMessage(@"【侦探】无法访问手势的 '_targets'。"); return; }
    
    NSArray *targets = object_getIvar(gesture, targetsIvar);
    if (!targets || targets.count == 0) { LogMessage(@"【侦探】手势没有目标。"); return; }

    id targetWrapper = targets.firstObject;
    id target = nil;
    SEL action = NULL;

    @try {
        target = [targetWrapper valueForKey:@"target"];
        NSValue *actionValue = [targetWrapper valueForKey:@"action"];
        if (actionValue) action = [actionValue pointerValue];
    } @catch (NSException *exception) {
        LogMessage(@"【侦探】获取target/action失败: %@", exception);
        return;
    }

    LogMessage(@"\n\n============== 【【【 最终线索 】】】 ==============");
    LogMessage(@"【手势目标 Target】: %@", target);
    LogMessage(@"【目标类名】: %@", [target class]);
    LogMessage(@"【执行方法 Action】: %@", NSStringFromSelector(action));
    LogMessage(@"==============================================\n\n");
    LogMessage(@"--- 侦探工作完成 ---");
}
%end
