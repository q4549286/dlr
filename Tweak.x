#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 全局变量，用于在屏幕上显示日志
// =========================================================================
static UIView *g_loggerPanel = nil;
static UITextView *g_logTextView = nil;
static NSMutableString *g_logStorageString = nil; // 用于存储所有日志以便复制

// =========================================================================
// 辅助函数 - 将日志同时输出到 NSLog 和屏幕上的 UITextView
// =========================================================================
static void LogToScreen(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    // 原始NSLog，以防万一
    NSLog(@"[ObserverV11] %@", message);

    // 在主线程更新UI
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_logTextView) {
            NSString *newText = [g_logTextView.text stringByAppendingFormat:@"%@\n", message];
            g_logTextView.text = newText;
            // 自动滚动到底部
            [g_logTextView scrollRangeToVisible:NSMakeRange(g_logTextView.text.length, 0)];
        }
        if (g_logStorageString) {
            [g_logStorageString appendFormat:@"%@\n", message];
        }
    });
}

// =========================================================================
// 界面与观察核心
// =========================================================================
@interface UIViewController (OnDeviceLogger)
- (void)createOrShowLoggerPanel_V11;
- (void)copyLogsAndClose_V11;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger buttonTag = 110011;
            if ([keyWindow viewWithTag:buttonTag]) { return; }
            
            UIButton *loggerButton = [UIButton buttonWithType:UIButtonTypeSystem];
            loggerButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            loggerButton.tag = buttonTag;
            [loggerButton setTitle:@"日志面板" forState:UIControlStateNormal];
            loggerButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            loggerButton.backgroundColor = [UIColor systemBlueColor];
            [loggerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            loggerButton.layer.cornerRadius = 8;
            [loggerButton addTarget:self action:@selector(createOrShowLoggerPanel_V11) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:loggerButton];
        });
    }
}

%new
- (void)createOrShowLoggerPanel_V11 {
    if (g_loggerPanel && g_loggerPanel.superview) {
        [g_loggerPanel removeFromSuperview];
        g_loggerPanel = nil; g_logTextView = nil; g_logStorageString = nil;
        return;
    }

    UIWindow *keyWindow = self.view.window;
    g_loggerPanel = [[UIView alloc] initWithFrame:CGRectMake(10, 100, keyWindow.bounds.size.width - 20, keyWindow.bounds.size.height - 200)];
    g_loggerPanel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    g_loggerPanel.layer.cornerRadius = 12; g_loggerPanel.clipsToBounds = YES;

    UILabel *instructionLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, g_loggerPanel.bounds.size.width - 20, 40)];
    instructionLabel.text = @"请先点击此面板外的【课体】单元格，\n下方文本框将显示日志，然后点击复制。";
    instructionLabel.textColor = [UIColor whiteColor];
    instructionLabel.textAlignment = NSTextAlignmentCenter;
    instructionLabel.numberOfLines = 2;
    [g_loggerPanel addSubview:instructionLabel];

    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 60, g_loggerPanel.bounds.size.width - 20, g_loggerPanel.bounds.size.height - 120)];
    g_logTextView.backgroundColor = [UIColor blackColor];
    g_logTextView.textColor = [UIColor greenColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO;
    [g_loggerPanel addSubview:g_logTextView];
    
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(10, g_loggerPanel.bounds.size.height - 50, g_loggerPanel.bounds.size.width - 20, 40);
    [copyButton setTitle:@"复制日志并关闭" forState:UIControlStateNormal];
    [copyButton addTarget:self action:@selector(copyLogsAndClose_V11) forControlEvents:UIControlEventTouchUpInside];
    copyButton.backgroundColor = [UIColor systemOrangeColor];
    [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyButton.layer.cornerRadius = 8;
    [g_loggerPanel addSubview:copyButton];
    
    [keyWindow addSubview:g_loggerPanel];
    
    // 初始化日志存储
    g_logStorageString = [NSMutableString string];
    LogToScreen(@"日志面板已就绪。请点击一个课体单元...");
}

%new
- (void)copyLogsAndClose_V11 {
    if (g_logStorageString.length > 0) {
        [UIPasteboard generalPasteboard].string = g_logStorageString;
        LogToScreen(@"日志已复制到剪贴板！");
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (g_loggerPanel) {
            [g_loggerPanel removeFromSuperview];
            g_loggerPanel = nil; g_logTextView = nil; g_logStorageString = nil;
        }
    });
}

// =========================================================================
// 核心观察逻辑
// =========================================================================

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    Class targetVCClass = NSClassFromString(@"六壬大占.ViewController");
    Class targetCVClass = NSClassFromString(@"六壬大占.課體視圖");

    if ([self isKindOfClass:targetVCClass] && [collectionView isKindOfClass:targetCVClass]) {
        LogToScreen(@"\n\n==================================================");
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
                id value = object_getIvar(self, ivar);
                LogToScreen(@"IVAR: %s -- 值: %@", name, value);
            }
            free(ivars);
        }
        LogToScreen(@"--- Ivar 列表检查完毕 ---\n");
    }

    // 调用原始实现，让App正常工作
    %orig;
}

%end
