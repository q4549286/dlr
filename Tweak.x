#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 全局变量
// =========================================================================
static UIView *g_loggerPanel = nil;
static UITextView *g_logTextView = nil;
static NSMutableString *g_logStorageString = nil;
static BOOL g_isLoggerArmed = NO; // 记录仪是否已准备就绪

// =========================================================================
// 辅助函数 - 将日志输出到屏幕
// =========================================================================
static void LogToScreen(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[ObserverV12.1] %@", message); // 保留NSLog以防万一
    if (g_logStorageString) {
        [g_logStorageString appendFormat:@"%@\n", message];
    }
}

// =========================================================================
// 界面与观察核心
// =========================================================================
@interface UIViewController (OnDeviceLogger)
- (void)toggleLoggerPanel_V12;
- (void)armAndHideLogger_V12;
- (void)copyLogsAndClose_V12;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger buttonTag = 120012;
            // 移除旧按钮，以防万一
            if ([keyWindow viewWithTag:buttonTag]) {
                [[keyWindow viewWithTag:buttonTag] removeFromSuperview];
            }
            
            UIButton *loggerButton = [UIButton buttonWithType:UIButtonTypeSystem];
            loggerButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            loggerButton.tag = buttonTag;
            [loggerButton setTitle:@"日志面板" forState:UIControlStateNormal];
            loggerButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            loggerButton.backgroundColor = [UIColor systemBlueColor];
            [loggerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            loggerButton.layer.cornerRadius = 8;
            [loggerButton addTarget:self action:@selector(toggleLoggerPanel_V12) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:loggerButton];
        });
    }
}

%new
- (void)toggleLoggerPanel_V12 {
    if (g_loggerPanel && g_loggerPanel.superview) {
        [g_loggerPanel removeFromSuperview];
        g_loggerPanel = nil; g_logTextView = nil; g_logStorageString = nil; g_isLoggerArmed = NO;
        return;
    }

    UIWindow *keyWindow = self.view.window;
    g_loggerPanel = [[UIView alloc] initWithFrame:CGRectMake(10, 100, keyWindow.bounds.size.width - 20, keyWindow.bounds.size.height - 200)];
    g_loggerPanel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    g_loggerPanel.layer.cornerRadius = 12; g_loggerPanel.clipsToBounds = YES;
    g_loggerPanel.tag = 120013; // 给面板也加个tag

    // 1. "准备/隐藏" 按钮
    UIButton *armButton = [UIButton buttonWithType:UIButtonTypeSystem];
    armButton.frame = CGRectMake(10, 10, g_loggerPanel.bounds.size.width - 20, 40);
    [armButton setTitle:@"准备记录 (点击后隐藏)" forState:UIControlStateNormal];
    [armButton addTarget:self action:@selector(armAndHideLogger_V12) forControlEvents:UIControlEventTouchUpInside];
    armButton.backgroundColor = [UIColor systemGreenColor];
    [armButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    armButton.layer.cornerRadius = 8;
    [g_loggerPanel addSubview:armButton];
    
    // 2. 日志文本框
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 60, g_loggerPanel.bounds.size.width - 20, g_loggerPanel.bounds.size.height - 120)];
    g_logTextView.backgroundColor = [UIColor blackColor];
    g_logTextView.textColor = [UIColor greenColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO;
    g_logTextView.text = @"请点击上方绿色按钮，面板将隐藏。\n然后点击一个【课体】单元格来捕获日志。";
    [g_loggerPanel addSubview:g_logTextView];
    
    // 3. "复制" 按钮
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(10, g_loggerPanel.bounds.size.height - 50, g_loggerPanel.bounds.size.width - 20, 40);
    [copyButton setTitle:@"复制日志并关闭" forState:UIControlStateNormal];
    [copyButton addTarget:self action:@selector(copyLogsAndClose_V12) forControlEvents:UIControlEventTouchUpInside];
    copyButton.backgroundColor = [UIColor systemOrangeColor];
    [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyButton.layer.cornerRadius = 8;
    [g_loggerPanel addSubview:copyButton];
    
    [keyWindow addSubview:g_loggerPanel];
}

%new
- (void)armAndHideLogger_V12 {
    g_isLoggerArmed = YES;
    g_logStorageString = [NSMutableString string]; // 初始化日志存储
    if (g_loggerPanel) {
        g_loggerPanel.hidden = YES; // 隐藏面板而不是移除
    }
    NSLog(@"[ObserverV12.1] Logger armed and panel hidden. Waiting for a click...");
}

%new
- (void)copyLogsAndClose_V12 {
    if (g_logTextView.text.length > 0) {
        [UIPasteboard generalPasteboard].string = g_logTextView.text;
    }
    // 调用主切换函数来彻底关闭和清理
    [self toggleLoggerPanel_V12];
}

// =========================================================================
// 核心观察逻辑
// =========================================================================

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    // 检查记录仪是否已准备就绪
    if (g_isLoggerArmed) {
        // 判断是否是我们要观察的目标
        Class targetVCClass = NSClassFromString(@"六壬大占.ViewController");
        Class targetCVClass = NSClassFromString(@"六壬大占.課體視圖");
        
        if ([self isKindOfClass:targetVCClass] && [collectionView isKindOfClass:targetCVClass]) {
            g_isLoggerArmed = NO; // 用过一次后就解除准备状态，防止重复记录

            LogToScreen(@"==================================================");
            LogToScreen(@"=========== 观察到【课体】点击事件！ ===========");
            LogToScreen(@"ViewController: %@", self);
            LogToScreen(@"被点击的路径: %@", indexPath);
            
            LogToScreen(@"\n--- 正在检查 ViewController 的所有实例变量 ---");
            unsigned int ivarCount = 0;
            Ivar *ivars = class_copyIvarList([self class], &ivarCount);
            if (ivars) {
                for(unsigned int i = 0; i < ivarCount; i++) {
                    Ivar ivar = ivars[i];
                    const char *name = ivar_getName(ivar);
                    @try {
                        id value = object_getIvar(self, ivar);
                        LogToScreen(@"IVAR: %s -> 值: %@", name, value);
                    } @catch (NSException *e) {
                        LogToScreen(@"IVAR: %s -> <读取时发生错误>", name);
                    }
                }
                free(ivars);
            }
            LogToScreen(@"--- Ivar 列表检查完毕 ---\n");

            // 关键一步：重新显示面板并更新内容
            dispatch_async(dispatch_get_main_queue(), ^{
                if (g_loggerPanel) {
                    g_logTextView.text = g_logStorageString;
                    g_loggerPanel.hidden = NO;
                }
            });
        }
    }

    // 无论如何都调用原始实现，让App正常工作
    %orig;
}

%end
