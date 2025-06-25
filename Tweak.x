#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数 (无变化)
// =========================================================================
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray<NSDictionary *> *g_keChuanWorkQueue = nil;
static NSMutableArray<NSString *> *g_keChuanTitleQueue = nil;

static UITextView *g_logTextView = nil;
static UIView *g_controlPanelView = nil;

static void LogMessage(NSString *format, ...) { /* ... */ }
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { /* ... */ }


// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)startExtraction_Truth;
- (void)processKeChuanQueue_Truth;
- (void)createOrShowControlPanel_Truth;
- (void)copyAndClose_Truth;
- (void)debug_SimulateKeTiTap_V4;
@end

@interface UICollectionView (DelegateMethods)
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath;
@end

%hook UIViewController

// --- viewDidLoad, presentViewController, copyAndClose_Truth, startExtraction_Truth, processKeChuanQueue_Truth ---
// (以上方法实现完整且与之前无误，此处为清晰省略)


// =========================================================================
// 【【【【【 界面修复区域 】】】】】
// =========================================================================
%new
- (void)createOrShowControlPanel_Truth {
    UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
    NSInteger panelTag = 556692;
    if (g_controlPanelView && g_controlPanelView.superview) {
        [g_controlPanelView removeFromSuperview]; g_controlPanelView = nil; g_logTextView = nil; return;
    }
    // 【【【 修复点: 完整实现面板创建过程 】】】
    g_controlPanelView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, keyWindow.bounds.size.width - 20, keyWindow.bounds.size.height - 200)];
    g_controlPanelView.tag = panelTag;
    g_controlPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
    g_controlPanelView.layer.cornerRadius = 12; g_controlPanelView.clipsToBounds = YES;
    
    // 正常功能按钮
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    startButton.frame = CGRectMake(10, 10, 160, 40);
    [startButton setTitle:@"提取三传+四课" forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(startExtraction_Truth) forControlEvents:UIControlEventTouchUpInside];
    startButton.backgroundColor = [UIColor systemGreenColor]; [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; startButton.layer.cornerRadius = 8;
    
    // 终极侦测按钮
    UIButton *debugButton = [UIButton buttonWithType:UIButtonTypeSystem];
    debugButton.frame = CGRectMake(180, 10, 180, 40);
    [debugButton setTitle:@"模拟点击课体(V4)" forState:UIControlStateNormal];
    [debugButton addTarget:self action:@selector(debug_SimulateKeTiTap_V4) forControlEvents:UIControlEventTouchUpInside];
    debugButton.backgroundColor = [UIColor systemRedColor]; [debugButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; debugButton.layer.cornerRadius = 8;

    // 复制按钮
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(10, 60, 160, 40);
    [copyButton setTitle:@"复制结果并关闭" forState:UIControlStateNormal];
    [copyButton addTarget:self action:@selector(copyAndClose_Truth) forControlEvents:UIControlEventTouchUpInside];
    copyButton.backgroundColor = [UIColor systemOrangeColor]; [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; copyButton.layer.cornerRadius = 8;

    // 日志窗口
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 110, g_controlPanelView.bounds.size.width - 20, g_controlPanelView.bounds.size.height - 120)];
    g_logTextView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0]; g_logTextView.textColor = [UIColor systemGreenColor]; g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12]; g_logTextView.editable = NO; g_logTextView.layer.cornerRadius = 8;
    g_logTextView.text = @"日志控制台已准备就绪。\n";
    
    // 【【【 修复点: 完整添加所有子视图 】】】
    [g_controlPanelView addSubview:startButton];
    [g_controlPanelView addSubview:debugButton];
    [g_controlPanelView addSubview:copyButton];
    [g_controlPanelView addSubview:g_logTextView];
    [keyWindow addSubview:g_controlPanelView];
}

%new
- (void)debug_SimulateKeTiTap_V4 {
    LogMessage(@"--- 开始【课体】模拟点击侦测 (V4.1) ---");
    g_isExtractingKeChuanDetail = YES; // 打开弹窗捕获开关
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
    
    // 步骤 1: 找到课体容器 (UICollectionView)
    Class keTiViewClass = NSClassFromString(@"六壬大占.課體視圖");
    if (!keTiViewClass) { LogMessage(@"【侦测】错误: 找不到 課體視圖 类。"); g_isExtractingKeChuanDetail = NO; return; }
    
    NSMutableArray *keTiViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(keTiViewClass, self.view, keTiViews);
    
    if (keTiViews.count == 0) {
        LogMessage(@"【侦测】错误: 视图层级中找不到 課體視圖 实例。");
        g_isExtractingKeChuanDetail = NO; return;
    }
    
    UICollectionView *keTiCollectionView = (UICollectionView *)keTiViews.firstObject;
    LogMessage(@"【侦测】成功找到 課體視圖 (CollectionView): %@", keTiCollectionView);
    LogMessage(@"【侦测】它的代理(delegate)是: %@", keTiCollectionView.delegate);
    LogMessage(@"【侦测】它的数据源(dataSource)是: %@", keTiCollectionView.dataSource);

    // 步骤 2: 准备模拟点击第一个单元格 (section 0, item 0)
    NSIndexPath *firstItemPath = [NSIndexPath indexPathForItem:0 inSection:0];
    LogMessage(@"【侦测】准备模拟点击第一个单元格，路径为: %@", firstItemPath);

    // 步骤 3: 尝试通过调用代理方法来触发事件 (最标准、最可能成功的方式)
    id delegate = keTiCollectionView.delegate;
    SEL delegateSelector = @selector(collectionView:didSelectItemAtIndexPath:);
    
    if (delegate && [delegate respondsToSelector:delegateSelector]) {
        LogMessage(@"\n>>>>>> 尝试方案A: 调用代理方法 <<<<<<");
        LogMessage(@"【侦测】代理 %@ 响应方法 %@。", [delegate class], NSStringFromSelector(delegateSelector));
        LogMessage(@"【侦测】正在调用 [delegate collectionView:self didSelectItemAtIndexPath:firstItemPath]...");
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [delegate performSelector:delegateSelector withObject:keTiCollectionView withObject:firstItemPath];
        #pragma clang diagnostic pop
        LogMessage(@"【侦测】方案A调用完毕。请检查是否出现弹窗或新日志。");
        return; 
    } else {
        LogMessage(@"\n>>>>>> 方案A失败: 代理不存在或不响应点击方法。<<<<<<");
    }

    // 方案B（备用）
    LogMessage(@"\n>>>>>> 尝试方案B: 调用 ViewController 上的已知方法 <<<<<<");
    UIGestureRecognizer *gesture = keTiCollectionView.gestureRecognizers.firstObject;
    if (!gesture) {
        LogMessage(@"【侦测】方案B失败: 課體視圖 上没有手势。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }

    Ivar keChuanIvar = class_getInstanceVariable([self class], "課傳");
    if (keChuanIvar) {
        object_setIvar(self, keChuanIvar, keTiCollectionView);
        LogMessage(@"【侦测】已设置 '課傳' Ivar。");
    }
    
    SEL vcSelector = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    if ([self respondsToSelector:vcSelector]) {
        LogMessage(@"【侦测】正在调用 [self %@]", NSStringFromSelector(vcSelector));
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:vcSelector withObject:gesture];
        #pragma clang diagnostic pop
        LogMessage(@"【侦测】方案B调用完毕。");
    } else {
        LogMessage(@"【侦测】方案B失败: ViewController 不响应 %@。", NSStringFromSelector(vcSelector));
        g_isExtractingKeChuanDetail = NO;
    }
}

%end
