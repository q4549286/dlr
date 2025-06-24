#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 全局状态
// =========================================================================
static BOOL g_isListening = NO;
static NSMutableString *g_accumulatedResult = nil;
static NSInteger g_startButtonTag = 202401;
static NSInteger g_finishButtonTag = 202402;

// =========================================================================
// 2. 主功能实现
// =========================================================================
@interface UIViewController (TheScribe)
- (void)startScribeMode;
- (void)finishScribeMode;
@end

%hook UIViewController

// --- 注入最终的“书记员”工具栏 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = self.view.window; if (!window) return;
            
            // 移除旧按钮
            [[window viewWithTag:g_startButtonTag] removeFromSuperview];
            [[window viewWithTag:g_finishButtonTag] removeFromSuperview];

            // 创建“开始记录”按钮
            UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
            startButton.frame = CGRectMake(self.view.frame.size.width - 230, 50, 100, 44);
            startButton.tag = g_startButtonTag;
            [startButton setTitle:@"开始记录" forState:UIControlStateNormal];
            startButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            startButton.backgroundColor = [UIColor systemGreenColor];
            [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            startButton.layer.cornerRadius = 22;
            [startButton addTarget:self action:@selector(startScribeMode) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:startButton];

            // 创建“完成提取”按钮
            UIButton *finishButton = [UIButton buttonWithType:UIButtonTypeSystem];
            finishButton.frame = CGRectMake(self.view.frame.size.width - 120, 50, 110, 44);
            finishButton.tag = g_finishButtonTag;
            [finishButton setTitle:@"完成并复制" forState:UIControlStateNormal];
            finishButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            finishButton.backgroundColor = [UIColor systemRedColor];
            [finishButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            finishButton.layer.cornerRadius = 22;
            [finishButton addTarget:self action:@selector(finishScribeMode) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:finishButton];
        });
    }
}

// --- 拦截器，被动监听用户触发的弹窗 ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // 【【【核心逻辑】】】
    // 只有在“监听模式”下才工作
    if (g_isListening) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            
            // 我们需要延迟执行，确保弹窗的视图和数据已经完全加载
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSMutableString *allText = [NSMutableString string];
                for(UIView* v in viewControllerToPresent.view.subviews) {
                    if([v isKindOfClass:[UILabel class]]) {
                        NSString *text = ((UILabel*)v).text;
                        if (text) [allText appendFormat:@"%@ ", [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                NSString* capturedDetail = allText.length > 0 ? [allText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] : @"[无文本信息]";
                
                // 将捕获到的信息追加到全局结果中
                [g_accumulatedResult appendFormat:@"--- (记录 #%lu) ---\n%@\n\n", (unsigned long)(g_accumulatedResult.length > 0 ? [[g_accumulatedResult componentsSeparatedByString:@"---"] count] : 1), capturedDetail];

                // 提供一个短暂的视觉反馈，告诉用户记录成功
                UILabel *feedbackLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 40)];
                feedbackLabel.center = viewControllerToPresent.view.center;
                feedbackLabel.text = @"已记录";
                feedbackLabel.textColor = [UIColor whiteColor];
                feedbackLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
                feedbackLabel.textAlignment = NSTextAlignmentCenter;
                feedbackLabel.layer.cornerRadius = 10;
                feedbackLabel.clipsToBounds = YES;
                [viewControllerToPresent.view addSubview:feedbackLabel];
                [UIView animateWithDuration:1.0 animations:^{
                    feedbackLabel.alpha = 0;
                } completion:^(BOOL finished) {
                    [feedbackLabel removeFromSuperview];
                }];
            });
        }
    }
    
    // 【【【重要】】】
    // 无论如何，都正常执行原始的 presentViewController 方法
    // 我们不再干预UI流程
    %orig(viewControllerToPresent, flag, completion);
}

%new
// --- “开始记录”按钮的动作 ---
- (void)startScribeMode {
    g_isListening = YES;
    g_accumulatedResult = [NSMutableString string];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"记录模式已开始" message:@"请像平时一样，用手指点击您想提取的课盘内容。所有弹窗详情将被自动记录。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"明白了" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// --- “完成提取”按钮的动作 ---
- (void)finishScribeMode {
    if (!g_isListening) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"您尚未开始记录模式。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    g_isListening = NO;
    [UIPasteboard generalPasteboard].string = g_accumulatedResult;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"记录完成" message:@"所有记录内容已合并并复制到剪贴板！" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"太棒了！" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
