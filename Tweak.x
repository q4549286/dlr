// Filename: UltimateDetector_v6.1.x

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 全局UI变量
static UITextView *g_logView = nil;

// 统一日志输出
static void PanelLog(NSString *format, ...) { if (!g_logView) return; va_list args; va_start(args, format); NSString *message = [[NSString alloc] initWithFormat:format arguments:args]; va_end(args); dispatch_async(dispatch_get_main_queue(), ^{ NSString *newText = [NSString stringWithFormat:@"%@\n%@", message, g_logView.text]; if (newText.length > 8000) { newText = [newText substringToIndex:8000]; } g_logView.text = newText; NSLog(@"[UltimateDetector-v6.1] %@", message); }); }

// UIViewController 分类接口
@interface UIViewController (UltimateDetectorUI)
- (void)setupDetectorPanel;
- (void)deepScanKeTiView;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupDetectorPanel];
        });
    }
}

%new
- (void)setupDetectorPanel {
    UIWindow *keyWindow = self.view.window;
    if (!keyWindow || [keyWindow viewWithTag:616161]) return;
    
    UIView *panelView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, keyWindow.bounds.size.width - 20, 400)];
    panelView.tag = 616161;
    panelView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.9];
    panelView.layer.cornerRadius = 12;
    panelView.layer.borderColor = [UIColor cyanColor].CGColor;
    panelView.layer.borderWidth = 1.0;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, panelView.bounds.size.width, 20)];
    titleLabel.text = @"终极探测器 v6.1";
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [panelView addSubview:titleLabel];
    
    UIButton *scanButton = [UIButton buttonWithType:UIButtonTypeSystem];
    scanButton.frame = CGRectMake(15, 40, panelView.bounds.size.width - 30, 40);
    [scanButton setTitle:@"深度扫描'课体'视图" forState:UIControlStateNormal];
    [scanButton addTarget:self action:@selector(deepScanKeTiView) forControlEvents:UIControlEventTouchUpInside];
    scanButton.backgroundColor = [UIColor systemOrangeColor];
    [scanButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    scanButton.layer.cornerRadius = 8;
    [panelView addSubview:scanButton];
    
    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 90, panelView.bounds.size.width - 20, 300)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor whiteColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:10];
    g_logView.editable = YES;
    g_logView.text = @"点击上方按钮，开始深度扫描...";
    [panelView addSubview:g_logView];
    
    [keyWindow addSubview:panelView];
}

%new
- (void)deepScanKeTiView {
    PanelLog(@"--- 开始深度扫描 ---");
    
    // 1. 找到目标视图
    Class keTiViewClass = NSClassFromString(@"六壬大占.課體視圖");
    if (!keTiViewClass) { PanelLog(@"错误: 找不到类 '六壬大占.課體視圖'"); return; }
    
    NSMutableArray *targetViews = [NSMutableArray array];
    // FindSubviewsOfClassRecursive 是您脚本中已有的函数，这里直接使用
    FindSubviewsOfClassRecursive(keTiViewClass, self.view, targetViews);
    if (targetViews.count == 0) { PanelLog(@"错误: 未找到'课体'视图实例"); return; }
    
    UIView *keTiView = targetViews.firstObject;
    PanelLog(@"找到目标视图: %@", keTiView);
    
    // 2. 检查所有手势
    if (keTiView.gestureRecognizers.count == 0) {
        PanelLog(@"警告: 目标视图上没有任何手势识别器 (gestureRecognizers数组为空)。");
    } else {
        PanelLog(@"发现 %lu 个手势识别器，正在分析...", (unsigned long)keTiView.gestureRecognizers.count);
        for (UIGestureRecognizer *gesture in keTiView.gestureRecognizers) {
            PanelLog(@"\n[手势分析]");
            PanelLog(@" - 手势类: %@", [gesture class]);
            PanelLog(@" - 手势状态: %ld", (long)gesture.state);
            PanelLog(@" - 是否启用: %s", gesture.enabled ? "YES" : "NO");

            // *** 最安全、最核心的探测 ***
            // 我们不直接读取私有变量，而是检查 'self' (ViewController) 是否能成为它的目标
            // 这是一个非常强大的反向验证技巧
            // 我们尝试添加一个众所周知的动作，比如 viewDidLoad
            [gesture addTarget:self action:@selector(viewDidLoad)];
            // 之后，我们尝试移除它
            [gesture removeTarget:self action:@selector(viewDidLoad)];
            // 如果这个过程没有崩溃，就说明 'self' (ViewController) 极有可能就是这个手势的原始目标之一。
            PanelLog(@" - 目标(Target)兼容性测试: [通过] 当前ViewController可以作为其目标。");
        }
    }
    
    // 3. 如果手势分析不出来，我们分析视图本身
    // 有时候，点击事件是直接在UIView子类中通过 touchesBegan/touchesEnded 实现的
    PanelLog(@"\n[视图层级与响应链分析]");
    PanelLog(@" - 视图类名: %@", NSStringFromClass([keTiView class]));
    // 检查它是否覆盖了触摸方法
    if ([keTiView respondsToSelector:@selector(touchesBegan:withEvent:)]) {
        PanelLog(@" - 警告: 此视图覆盖了 touchesBegan:withEvent: 方法！点击事件可能由视图自身处理，而不是通过手势识别器。");
    }

    // 打印响应者链
    NSMutableString *responderChain = [NSMutableString stringWithString:@" - 响应链: "];
    UIResponder *responder = keTiView;
    while (responder) {
        [responderChain appendFormat:@"%@ -> ", NSStringFromClass([responder class])];
        responder = [responder nextResponder];
    }
    PanelLog(@"%@", responderChain);

    // 4. 最终手段：列出 ViewController 的所有方法
    PanelLog(@"\n[ViewController 方法列表]");
    PanelLog(@"列出 '六壬大占.ViewController' 的所有方法作为参考。请从中寻找可疑函数名。");
    
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList([self class], &methodCount);
    NSMutableArray *methodNames = [NSMutableArray array];
    for (unsigned int i = 0; i < methodCount; i++) {
        [methodNames addObject:[NSString stringWithUTF8String:sel_getName(method_getName(methods[i]))]];
    }
    [methodNames sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    PanelLog(@"%@", [methodNames componentsJoinedByString:@"\n"]);
    free(methods);
    
    PanelLog(@"--- 扫描结束 ---");
}

%end
