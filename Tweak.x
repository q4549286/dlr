#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 全局变量
// =========================================================================
static UIView *g_loggerPanel = nil;
static UITextView *g_logTextView = nil;
static NSMutableString *g_logStorageString = nil;
static BOOL g_isLoggerArmed = NO;

// =========================================================================
// 辅助函数
// =========================================================================
static void LogToScreen(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[DetectorV13.1] %@", message);
    if (g_logStorageString) {
        [g_logStorageString appendFormat:@"%@\n", message];
    }
}

static void FindGestureRecognizersRecursive(UIView *view, NSMutableArray *storage) {
    if (!view) return;
    if (view.gestureRecognizers.count > 0) {
        for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
            [storage addObject:@{@"view": view, @"gesture": gesture}];
        }
    }
    for (UIView *subview in view.subviews) {
        FindGestureRecognizersRecursive(subview, storage);
    }
}

// =========================================================================
// 界面与观察核心
// =========================================================================
@interface UIViewController (OnDeviceLogger)
- (void)toggleLoggerPanel_V13_1;
- (void)armAndHideLogger_V13_1;
- (void)copyLogsAndClose_V13_1;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger buttonTag = 131131;
            if ([keyWindow viewWithTag:buttonTag]) { [[keyWindow viewWithTag:buttonTag] removeFromSuperview]; }
            
            UIButton *loggerButton = [UIButton buttonWithType:UIButtonTypeSystem];
            loggerButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            loggerButton.tag = buttonTag;
            [loggerButton setTitle:@"侦测面板" forState:UIControlStateNormal];
            loggerButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            loggerButton.backgroundColor = [UIColor systemIndigoColor];
            [loggerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            loggerButton.layer.cornerRadius = 8;
            [loggerButton addTarget:self action:@selector(toggleLoggerPanel_V13_1) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:loggerButton];
        });
    }
}

%new
- (void)toggleLoggerPanel_V13_1 {
    if (g_loggerPanel && g_loggerPanel.superview) {
        [g_loggerPanel removeFromSuperview];
        g_loggerPanel = nil; g_logTextView = nil; g_logStorageString = nil; g_isLoggerArmed = NO;
        return;
    }
    UIWindow *keyWindow = self.view.window;
    
    // 【【【【 UI修改：窗口变小 】】】】
    CGFloat panelWidth = keyWindow.bounds.size.width - 20;
    CGFloat panelHeight = 350; // 大大减小高度
    g_loggerPanel = [[UIView alloc] initWithFrame:CGRectMake(10, 100, panelWidth, panelHeight)];
    g_loggerPanel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    g_loggerPanel.layer.cornerRadius = 12; g_loggerPanel.clipsToBounds = YES;
    
    // 【【【【 UI修改：调整内部布局 】】】】
    UIButton *armButton = [UIButton buttonWithType:UIButtonTypeSystem];
    armButton.frame = CGRectMake(10, 10, panelWidth - 20, 40);
    [armButton setTitle:@"准备侦测 (点击后隐藏)" forState:UIControlStateNormal];
    [armButton addTarget:self action:@selector(armAndHideLogger_V13_1) forControlEvents:UIControlEventTouchUpInside];
    armButton.backgroundColor = [UIColor systemGreenColor];
    [armButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    armButton.layer.cornerRadius = 8;
    [g_loggerPanel addSubview:armButton];
    
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 60, panelWidth - 20, panelHeight - 120)];
    g_logTextView.backgroundColor = [UIColor blackColor];
    g_logTextView.textColor = [UIColor greenColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO;
    g_logTextView.text = @"请点击上方绿色按钮，面板将隐藏。\n然后点击一个【课体】单元格来侦测其内部手势。";
    [g_loggerPanel addSubview:g_logTextView];
    
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(10, panelHeight - 50, panelWidth - 20, 40);
    [copyButton setTitle:@"复制日志并关闭" forState:UIControlStateNormal];
    [copyButton addTarget:self action:@selector(copyLogsAndClose_V13_1) forControlEvents:UIControlEventTouchUpInside];
    copyButton.backgroundColor = [UIColor systemOrangeColor];
    [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyButton.layer.cornerRadius = 8;
    [g_loggerPanel addSubview:copyButton];
    
    [keyWindow addSubview:g_loggerPanel];
}

%new
- (void)armAndHideLogger_V13_1 {
    g_isLoggerArmed = YES;
    g_logStorageString = [NSMutableString string];
    if (g_loggerPanel) {
        g_loggerPanel.hidden = YES;
    }
}

%new
- (void)copyLogsAndClose_V13_1 {
    if (g_logTextView.text.length > 0) {
        [UIPasteboard generalPasteboard].string = g_logTextView.text;
    }
    [self toggleLoggerPanel_V13_1];
}

// =========================================================================
// 核心侦测逻辑 (与V13完全相同)
// =========================================================================

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (g_isLoggerArmed) {
        Class targetVCClass = NSClassFromString(@"六壬大占.ViewController");
        Class targetCVClass = NSClassFromString(@"六壬大占.課體視圖");
        
        if ([self isKindOfClass:targetVCClass] && [collectionView isKindOfClass:targetCVClass]) {
            g_isLoggerArmed = NO;

            LogToScreen(@"==================================================");
            LogToScreen(@"=========== 极简侦测(V13.1)已触发！ ===========");
            
            UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
            if (cell) {
                LogToScreen(@"成功定位到被点击的单元格 (Cell): %@", cell);
                LogToScreen(@"\n--- 正在递归搜索此单元格内部的所有手势 ---");
                
                NSMutableArray *foundGestures = [NSMutableArray array];
                FindGestureRecognizersRecursive(cell, foundGestures);
                
                if (foundGestures.count == 0) {
                    LogToScreen(@"【重大发现】: 单元格内部没有任何直接的手势！");
                } else {
                    LogToScreen(@"【重大发现】: 在单元格内部找到了 %lu 个手势！", (unsigned long)foundGestures.count);
                    for (NSDictionary *info in foundGestures) {
                        UIView *targetView = info[@"view"];
                        UIGestureRecognizer *gesture = info[@"gesture"];
                        LogToScreen(@"\n--- 手势详情 ---");
                        LogToScreen(@"手势类型: %@", [gesture class]);
                        LogToScreen(@"附加到的视图: %@", targetView);
                        
                        @try {
                            Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
                            if (targetsIvar) {
                                NSArray *targets = object_getIvar(gesture, targetsIvar);
                                if (targets && targets.count > 0) {
                                    id targetWrapper = targets.firstObject;
                                    id finalTarget = [targetWrapper valueForKey:@"target"];
                                    SEL finalAction = [[targetWrapper valueForKey:@"action"] pointerValue];
                                    LogToScreen(@"【【【关键信息】】】");
                                    LogToScreen(@"手势目标(Target): %@", finalTarget);
                                    LogToScreen(@"响应方法(Action): %@", NSStringFromSelector(finalAction));
                                } else {
                                    LogToScreen(@"手势没有目标(Target)信息。");
                                }
                            }
                        } @catch (NSException *e) {
                            LogToScreen(@"获取手势Target/Action时发生错误: %@", e);
                        }
                    }
                }
            } else {
                LogToScreen(@"错误：无法定位到被点击的单元格。");
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if (g_loggerPanel) {
                    g_logTextView.text = g_logStorageString;
                    g_loggerPanel.hidden = NO;
                }
            });
        }
    }
    %orig;
}

%end
