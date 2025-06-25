#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray<NSDictionary *> *g_keChuanWorkQueue = nil;
static NSMutableArray<NSString *> *g_keChuanTitleQueue = nil;

static UITextView *g_logTextView = nil;
static UIView *g_controlPanelView = nil;

static void LogMessage(NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss.SSS"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSString *fullMessage = [logPrefix stringByAppendingString:message];
        g_logTextView.text = [NSString stringWithFormat:@"%@\n%@", fullMessage, g_logTextView.text];
        NSLog(@"[KeChuanExtractor] %@", message);
    });
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)startExtraction_Truth;
- (void)processKeChuanQueue_Truth;
- (void)createOrShowControlPanel_Truth;
- (void)copyAndClose_Truth;
// 【新】终极侦测方法
- (void)debug_SimulateKeTiTap_V4;
@end

@interface UICollectionView (DelegateMethods)
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath;
@end

%hook UIViewController

// --- viewDidLoad, presentViewController, copyAndClose_Truth 等与之前版本相同 ---
// 此处省略实现以保持清晰

%new
- (void)createOrShowControlPanel_Truth {
    UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
    NSInteger panelTag = 556692;
    if (g_controlPanelView && g_controlPanelView.superview) {
        [g_controlPanelView removeFromSuperview]; g_controlPanelView = nil; g_logTextView = nil; return;
    }
    g_controlPanelView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, keyWindow.bounds.size.width - 20, keyWindow.bounds.size.height - 200)];
    g_controlPanelView.tag = panelTag;
    g_controlPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
    g_controlPanelView.layer.cornerRadius = 12; g_controlPanelView.clipsToBounds = YES;
    
    UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    startButton.frame = CGRectMake(10, 10, 160, 40);
    [startButton setTitle:@"提取三传+四课" forState:UIControlStateNormal];
    [startButton addTarget:self action:@selector(startExtraction_Truth) forControlEvents:UIControlEventTouchUpInside];
    startButton.backgroundColor = [UIColor systemGreenColor]; [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; startButton.layer.cornerRadius = 8;
    
    // 【新】终极侦测按钮
    UIButton *debugButton = [UIButton buttonWithType:UIButtonTypeSystem];
    debugButton.frame = CGRectMake(180, 10, 180, 40);
    [debugButton setTitle:@"模拟点击课体(V4)" forState:UIControlStateNormal];
    [debugButton addTarget:self action:@selector(debug_SimulateKeTiTap_V4) forControlEvents:UIControlEventTouchUpInside];
    debugButton.backgroundColor = [UIColor systemRedColor]; [debugButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; debugButton.layer.cornerRadius = 8;

    /* 其他UI元素... */
    
    [g_controlPanelView addSubview:startButton];
    [g_controlPanelView addSubview:debugButton];
    // ...
}

%new
- (void)debug_SimulateKeTiTap_V4 {
    LogMessage(@"--- 开始【课体】模拟点击侦测 (V4) ---");
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
        // 调用后我们等待 presentViewController 钩子捕获弹窗
        // 为避免干扰，我们先只尝试这一种方法
        return; 
    } else {
        LogMessage(@"\n>>>>>> 方案A失败: 代理不存在或不响应点击方法。<<<<<<");
    }

    // 如果方案A失败，我们回到老路，尝试调用 ViewController 上的方法
    LogMessage(@"\n>>>>>> 尝试方案B: 调用 ViewController 上的已知方法 <<<<<<");
    UIGestureRecognizer *gesture = keTiCollectionView.gestureRecognizers.firstObject;
    if (!gesture) {
        LogMessage(@"【侦测】方案B失败: 課體視圖 上没有手势。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }

    // 设置我们已知的上下文变量
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
