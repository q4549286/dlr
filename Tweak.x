#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 宏定义与辅助函数 (精简版)
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-Sike-V3] " format), ##__VA_ARGS__)

static NSInteger const TestButtonTag = 998877;
static BOOL g_isExtracting = NO;
static NSString *g_currentItemKey = nil;
static NSMutableDictionary *g_capturedDetails = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }

// =========================================================================
// 核心逻辑
// =========================================================================

@interface UIViewController (EchoAITestAddons)
- (void)performSiKeTestExtraction;
- (void)extractSiKeSanChuanDetailsWithCompletion:(void (^)(NSString *detailsText))completion;
@end

%hook UIViewController

// --- 界面入口：添加测试按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([self.view.window viewWithTag:TestButtonTag]) return;
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(self.view.window.bounds.size.width - 150, 85, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"[测试]提取课传详情" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.2 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performSiKeTestExtraction) forControlEvents:UIControlEventTouchUpInside];
            [self.view.window addSubview:testButton];
        });
    }
}

// --- 核心：截获弹窗 (温和处理版) ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtracting && g_currentItemKey) {
        if (![viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            EchoLog(@"捕获到弹窗: %@, 采用温和处理模式。", NSStringFromClass([viewControllerToPresent class]));
            
            // 包装原始的completion block
            void (^newCompletion)(void) = ^{
                // 先执行原始的completion，确保弹窗完全显示
                if (completion) {
                    completion();
                }
                
                // 在弹窗显示后，我们再安全地操作
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIView *contentView = viewControllerToPresent.view;
                    NSMutableArray *allLabels = [NSMutableArray array];
                    FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                    [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
                        if (fabs(l1.frame.origin.y - l2.frame.origin.y) > 5) { return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)]; }
                        return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)];
                    }];

                    NSMutableArray *textParts = [NSMutableArray array];
                    for (UILabel *label in allLabels) {
                        if (label.text && label.text.length > 0) {
                            NSString *cleanedText = [[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                            if (cleanedText.length > 0) { [textParts addObject:cleanedText]; }
                        }
                    }
                    
                    NSString *fullText = [textParts componentsJoinedByString:@" -> "];
                    g_capturedDetails[g_currentItemKey] = fullText;
                    EchoLog(@"[捕获成功] Key: %@, 内容: %@", g_currentItemKey, fullText);
                    
                    // 提取完毕后，再关闭弹窗
                    [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
                });
            };
            
            // 使用我们包装后的 newCompletion 来执行原始的 presentViewController
            %orig(viewControllerToPresent, animated, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performSiKeTestExtraction {
    [self extractSiKeSanChuanDetailsWithCompletion:^(NSString *detailsText) {
        if (detailsText && detailsText.length > 0) {
            [UIPasteboard generalPasteboard].string = detailsText;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试成功" message:@"四课三传的详细信息已提取并复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试失败" message:@"未能提取到任何详细信息，请检查Log。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
}

%new
- (void)extractSiKeSanChuanDetailsWithCompletion:(void (^)(NSString *detailsText))completion {
    EchoLog(@"--- 开始 [独立测试 V3] 提取流程 ---");
    g_isExtracting = YES;
    g_capturedDetails = [NSMutableDictionary dictionary];

    NSMutableArray *clickableItems = [NSMutableArray array];
    
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    
    void (^findItemsInContainer)(Class, UIView*, NSString*) = ^(Class containerClass, UIView *parentView, NSString *prefix) {
        if (!containerClass) return;
        NSMutableArray *containers = [NSMutableArray array];
        FindSubviewsOfClassRecursive(containerClass, parentView, containers);
        if (containers.count > 0) {
            UIView* container = containers.firstObject;
            NSMutableArray *labels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], container, labels);
            
            for (UILabel *label in labels) {
                if (label.gestureRecognizers && label.gestureRecognizers.count > 0) {
                    NSString *uniqueKey = [NSString stringWithFormat:@"%@-%@-%p", prefix, label.text, (void*)label];
                    [clickableItems addObject:@{@"view": label, @"key": uniqueKey, @"text": label.text ?: @""}];
                }
            }
        }
    };
    
    findItemsInContainer(siKeViewClass, self.view, @"四课");
    findItemsInContainer(sanChuanViewClass, self.view, @"三传");

    if (clickableItems.count == 0) {
        EchoLog(@"[错误] 未找到任何带有手势的UILabel，提取中止。");
        g_isExtracting = NO;
        if (completion) completion(@"");
        return;
    }
    EchoLog(@"找到了 %lu 个可点击的课传项。", (unsigned long)clickableItems.count);

    NSMutableArray *workQueue = [clickableItems mutableCopy];
    __weak typeof(self) weakSelf = self;
    __block void (^processQueue)(void);
    processQueue = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || workQueue.count == 0) {
            EchoLog(@"--- 提取流程全部完成 ---");
            NSMutableString *resultStr = [NSMutableString string];
            for (NSDictionary *item in clickableItems) {
                NSString *key = item[@"key"];
                NSString *details = g_capturedDetails[key];
                if (details && details.length > 0) {
                    NSString *originalText = item[@"text"];
                    [resultStr appendFormat:@"【%@】%@\n", originalText, details];
                }
            }
            g_isExtracting = NO;
            if (completion) { completion([resultStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]); }
            processQueue = nil;
            return;
        }

        NSDictionary *itemInfo = workQueue.firstObject;
        [workQueue removeObjectAtIndex:0];
        UILabel *itemView = itemInfo[@"view"];
        g_currentItemKey = itemInfo[@"key"];
        
        EchoLog(@"正在处理: %@", g_currentItemKey);

        UITapGestureRecognizer *tap = itemView.gestureRecognizers.firstObject;
        if (tap && [tap isKindOfClass:[UITapGestureRecognizer class]]) {
            id target = [tap valueForKey:@"target"];
            NSString *actionString = @"顯示課傳摘要WithSender:"; 
            SEL action = NSSelectorFromString(actionString);
            
            if (target && action && [target respondsToSelector:action]) {
                EchoLog(@"触发点击 -> Target: %@, Action: %@", NSStringFromClass([target class]), actionString);
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [target performSelector:action withObject:tap];
                #pragma clang diagnostic pop
            } else {
                EchoLog(@"[错误] 无法触发点击。Target: %@, Action: %@", target, actionString);
            }
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            processQueue();
        });
    };
    processQueue();
}

%end
