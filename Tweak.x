#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局UI变量与日志函数
// =========================================================================

static UIView *g_probePanelView = nil;
static UITextView *g_probeLogTextView = nil;

// 一个线程安全的日志函数，用于向我们的UI面板输出信息
static void ProbeLog(NSString *format, ...) {
    if (!g_probeLogTextView) return;
    
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss.SSS"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];

    // 确保UI更新在主线程进行
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *newLogLine = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
        g_probeLogTextView.text = [g_probeLogTextView.text stringByAppendingString:newLogLine];
        
        // 自动滚动到底部
        NSRange range = NSMakeRange(g_probeLogTextView.text.length - 1, 1);
        [g_probeLogTextView scrollRangeToVisible:range];
    });
}

// =========================================================================
// 2. UIViewController 扩展，用于实现侦查面板功能
// =========================================================================

@interface UIViewController (EchoProbe)
- (void)showProbePanel;
- (void)closeProbePanel;
- (void)runTheProbe:(id)sender;
- (void)clearProbeLog:(id)sender;
@end

%new
@implementation UIViewController (EchoProbe)

- (void)runTheProbe:(id)sender {
    ProbeLog(@"\n\n[PROBE] ====== 开始新一轮侦查 ====== ");

    // 步骤 1: 向上找到 '六壬大占.ViewController' 的实例
    UIResponder *responder = (UIResponder *)sender;
    Class targetVCClass = NSClassFromString(@"六壬大占.ViewController");
    if (!targetVCClass) {
        ProbeLog(@"[PROBE] 致命错误: 找不到 '六壬大占.ViewController' 类。");
        return;
    }
    
    while (responder && ![responder isKindOfClass:targetVCClass]) {
        responder = [responder nextResponder];
    }

    if (!responder) {
        ProbeLog(@"[PROBE] 错误: 无法从按钮向上找到 '六壬大占.ViewController' 实例。");
        return;
    }
    
    UIViewController *vc = (UIViewController *)responder;
    ProbeLog(@"[PROBE] 成功定位到 ViewController 实例: %@", vc);

    // ================== 目标1：确认 '課傳' 的存在性和类型 ==================
    Ivar keChuanIvar = class_getInstanceVariable([vc class], "課傳");
    if (!keChuanIvar) {
        ProbeLog(@"[PROBE] 未找到 '課傳'，尝试带下划线的 '_課傳'...");
        keChuanIvar = class_getInstanceVariable([vc class], "_課傳");
    }

    if (keChuanIvar) {
        const char* ivarName = ivar_getName(keChuanIvar);
        const char* typeEncoding = ivar_getTypeEncoding(keChuanIvar);
        NSString *typeName = [NSString stringWithUTF8String:typeEncoding];
        
        ProbeLog(@"[PROBE] ✅ 成功! 找到实例变量 '%s'。", ivarName);
        ProbeLog(@"[PROBE]    类型编码: %@", typeName);
        
        id keChuanContainer = object_getIvar(vc, keChuanIvar);
        ProbeLog(@"[PROBE]    对象实例: %@", keChuanContainer);

        // ================== 目标2：勘探 '課傳' 对象的内部 ==================
        if (keChuanContainer) {
            unsigned int ivarCount;
            Ivar *ivars = class_copyIvarList([keChuanContainer class], &ivarCount);
            ProbeLog(@"[PROBE] --- 正在勘探 '%@' 内部... ---", [keChuanContainer class]);
            
            BOOL foundPotentialList = NO;
            for (unsigned int i = 0; i < ivarCount; i++) {
                Ivar ivar = ivars[i];
                const char *name = ivar_getName(ivar);
                const char *type = ivar_getTypeEncoding(ivar);
                
                NSString *ivarNameStr = [NSString stringWithUTF8String:name];
                NSString *ivarTypeStr = [NSString stringWithUTF8String:type];
                ProbeLog(@"[PROBE]   - 发现内部变量: %@, 类型: %@", ivarNameStr, ivarTypeStr);
                
                // 启发式搜索：寻找包含 "天將", "將列表", "generals" 等关键词的变量
                if ([ivarNameStr localizedCaseInsensitiveContainsString:@"天將"] || [ivarNameStr localizedCaseInsensitiveContainsString:@"將列表"]) {
                     foundPotentialList = YES;
                     ProbeLog(@"[PROBE]     ‼️ 高度可疑目标! 正在深入检查...");
                     id potentialArray = object_getIvar(keChuanContainer, ivar);
                     
                     if ([potentialArray isKindOfClass:[NSArray class]]) {
                         NSArray *arr = (NSArray *)potentialArray;
                         ProbeLog(@"[PROBE]     ✅ 确认是 NSArray! 数量: %lu", (unsigned long)arr.count);
                         if (arr.count > 0) {
                            ProbeLog(@"[PROBE]     第一个元素: %@", arr.firstObject);
                            ProbeLog(@"[PROBE]     第一个元素的类: %@", [arr.firstObject class]);
                         }
                     } else if (potentialArray) {
                         ProbeLog(@"[PROBE]     ⚠️ 类型不是NSArray, 而是: %@", [potentialArray class]);
                     } else {
                         ProbeLog(@"[PROBE]     ℹ️ 变量当前为 nil。");
                     }
                }
            }
            free(ivars);
            
            if (!foundPotentialList) {
                ProbeLog(@"[PROBE] --- 在 '%@' 内部未找到明显的目标变量。 ---", [keChuanContainer class]);
            }
        }

    } else {
        ProbeLog(@"[PROBE] ❌ 失败! 在 ViewController 中未找到 '課傳' 或 '_課傳'。");
        
        unsigned int allIvarCount;
        Ivar *allIvars = class_copyIvarList([vc class], &allIvarCount);
        ProbeLog(@"[PROBE] --- 以下是 ViewController 的所有实例变量列表: ---");
        for (unsigned int i = 0; i < allIvarCount; i++) {
            Ivar ivar = allIvars[i];
            ProbeLog(@"[PROBE]   - %s", ivar_getName(ivar));
        }
        free(allIvars);
    }
    ProbeLog(@"[PROBE] ====== 侦查结束 ======");
}

- (void)showProbePanel {
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    if (!keyWindow || g_probePanelView) return;

    g_probePanelView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, keyWindow.bounds.size.width, keyWindow.bounds.size.height * 0.6)];
    g_probePanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    g_probePanelView.layer.borderColor = [UIColor cyanColor].CGColor;
    g_probePanelView.layer.borderWidth = 1.0;
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, g_probePanelView.bounds.size.width, 30)];
    titleLabel.text = @"Echo 侦查面板";
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [g_probePanelView addSubview:titleLabel];
    
    // 日志窗口
    g_probeLogTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 50, g_probePanelView.bounds.size.width - 20, g_probePanelView.bounds.size.height - 110)];
    g_probeLogTextView.backgroundColor = [UIColor blackColor];
    g_probeLogTextView.textColor = [UIColor greenColor];
    g_probeLogTextView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_probeLogTextView.editable = NO;
    g_probeLogTextView.text = @"日志窗口已就绪...\n";
    [g_probePanelView addSubview:g_probeLogTextView];
    
    // 按钮
    CGFloat buttonWidth = (g_probePanelView.bounds.size.width - 40) / 3.0;
    CGFloat buttonY = g_probePanelView.bounds.size.height - 50;
    
    UIButton *runButton = [UIButton buttonWithType:UIButtonTypeSystem];
    runButton.frame = CGRectMake(10, buttonY, buttonWidth, 40);
    [runButton setTitle:@"开始侦查" forState:UIControlStateNormal];
    [runButton addTarget:self action:@selector(runTheProbe:) forControlEvents:UIControlEventTouchUpInside];
    [g_probePanelView addSubview:runButton];
    
    UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    clearButton.frame = CGRectMake(20 + buttonWidth, buttonY, buttonWidth, 40);
    [clearButton setTitle:@"清空日志" forState:UIControlStateNormal];
    [clearButton addTarget:self action:@selector(clearProbeLog:) forControlEvents:UIControlEventTouchUpInside];
    [g_probePanelView addSubview:clearButton];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(30 + buttonWidth * 2, buttonY, buttonWidth, 40);
    [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(closeProbePanel) forControlEvents:UIControlEventTouchUpInside];
    [g_probePanelView addSubview:closeButton];
    
    [keyWindow addSubview:g_probePanelView];
}

- (void)clearProbeLog:(id)sender {
    if (g_probeLogTextView) {
        g_probeLogTextView.text = @"";
    }
}

- (void)closeProbePanel {
    if (g_probePanelView) {
        [g_probePanelView removeFromSuperview];
        g_probePanelView = nil;
        g_probeLogTextView = nil;
    }
}

@end


// =========================================================================
// 3. Tweak 入口，用于注入我们的侦查按钮
// =========================================================================

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    
    // 只在主 ViewController 上添加按钮
    if ([self isKindOfClass:NSClassFromString(@"六壬大占.ViewController")]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
            if (!keyWindow) return;

            // 防止重复添加
            if ([keyWindow viewWithTag:888888]) return;

            UIButton *probeTriggerButton = [UIButton buttonWithType:UIButtonTypeSystem];
            probeTriggerButton.frame = CGRectMake(10, 45, 80, 36);
            probeTriggerButton.tag = 888888;
            [probeTriggerButton setTitle:@"侦查" forState:UIControlStateNormal];
            probeTriggerButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
            [probeTriggerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            probeTriggerButton.layer.cornerRadius = 18;
            [probeTriggerButton addTarget:self action:@selector(showProbePanel) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:probeTriggerButton];
        });
    }
}

%end

%ctor {
    NSLog(@"[EchoProbe] 侦查脚本已加载。");
}
