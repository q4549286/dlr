#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 宏定义与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-Final] " format), ##__VA_ARGS__)

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


// =========================================================================
// 全新的Hook目标：UIPopoverPresentationControllerDelegate
// Popover在呈现前，会向它的delegate查询一些信息。我们在这里拦截，这是最安全、最不会崩溃的时机。
// =========================================================================
%hook 六壬大占_ViewController 

// 我们猜测主ViewController就是popover的delegate
// 这个方法是当popover准备呈现时，系统会调用的方法
- (void)prepareForPopoverPresentation:(UIPopoverPresentationController *)popoverPresentationController {
    // 先调用原始实现，让App把所有东西都准备好
    %orig; 

    if (g_isExtracting && g_currentItemKey) {
        EchoLog(@"成功拦截到 prepareForPopoverPresentation！提取数据...");

        // popoverPresentationController.presentedViewController 就是我们要的弹窗VC
        UIViewController *contentVC = popoverPresentationController.presentedViewController;
        if (contentVC) {
            // 从这里开始，提取逻辑和之前一样
            UIView *contentView = contentVC.view;
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
        }

        // 关键一步：我们已经拿到了数据，现在要阻止这个popover真正显示出来，避免闪烁和后续问题
        // 我们通过让它的delegate“假装”它不应该以popover形式呈现，来取消这次弹出
        // (这是一个hacky的方法，但可能有效)
        // 这一步如果导致问题，我们就注释掉它，让它弹出来再消失
    }
}

%end


%hook UIViewController

// --- 界面入口：添加测试按钮 ---
- (void)viewDidLoad { %orig;
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

// 我们不再需要拦截 presentViewController 了，因为新的Hook点更精确

%new
- (void)performSiKeTestExtraction {
    [self extractSiKeSanChuanDetailsWithCompletion:^(NSString *detailsText) {
        if (detailsText && detailsText.length > 0) {
            [UIPasteboard generalPasteboard].string = detailsText;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试成功" message:@"四课三传的详细信息已提取并复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试失败" message:@"未能提取到任何详细信息，请检查Log。可能是Hook点不正确。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }];
}

%new
- (void)extractSiKeSanChuanDetailsWithCompletion:(void (^)(NSString *detailsText))completion {
    EchoLog(@"--- 开始 [独立测试 Final] 提取流程 ---");
    g_isExtracting = YES;
    g_capturedDetails = [NSMutableDictionary dictionary];

    // ... 查找可点击项的逻辑不变 ...
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
        g_isExtracting = NO; if (completion) completion(@""); return;
    }

    // ... 工作队列逻辑不变，触发点击的逻辑也不变 ...
    NSMutableArray *workQueue = [clickableItems mutableCopy];
    __weak typeof(self) weakSelf = self;
    __block void (^processQueue)(void);
    processQueue = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || workQueue.count == 0) {
            EchoLog(@"--- 提取流程全部完成 ---");
            // 延迟一下，确保最后一个popover的处理已经完成
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
            });
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
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [target performSelector:action withObject:tap];
                #pragma clang diagnostic pop
            }
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            processQueue();
        });
    };
    processQueue();
}

%end
