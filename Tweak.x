#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-V9-FINAL] " format), ##__VA_ARGS__)

// =========================================================================
// 全局变量
// =========================================================================
static NSMutableDictionary *g_testExtractedData = nil;

// =========================================================================
// 辅助函数
// =========================================================================
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}

static id GetIvarValueFromObject(id object, const char *ivarName) {
    Ivar ivar = class_getInstanceVariable([object class], ivarName);
    if (ivar) {
        return object_getIvar(object, ivar);
    }
    return nil;
}

// =========================================================================
//  Hook UIViewController
// =========================================================================
%hook UIViewController

// -------------------------------------------------------------------------
// 1. 添加测试按钮
// -------------------------------------------------------------------------
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        if ([self.view.window viewWithTag:45678]) return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return; // 这里用self.view.window没问题，因为它是在viewDidLoad之后
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(10, 45, 120, 36);
            testButton.tag = 45678;
            [testButton setTitle:@"格局提取(V9)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor systemTealColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(testGeJuExtractionTapped_V9) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// -------------------------------------------------------------------------
// 2. 拦截弹窗【防闪退版】
// -------------------------------------------------------------------------
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    %orig(viewControllerToPresent, flag, completion);

    if (g_testExtractedData == nil || [viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        
        if ([vcClassName isEqualToString:@"六壬大占.格局總覽視圖"]) {
            Class cellClass = NSClassFromString(@"六壬大占.格局單元");
            if (!cellClass) {
                g_testExtractedData[@"格局"] = @"提取失败: 找不到'六壬大占.格局單元'类。";
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
                return;
            }

            NSMutableArray *cells = [NSMutableArray array];
            FindSubviewsOfClassRecursive(cellClass, viewControllerToPresent.view, cells);
            
            [cells sortUsingComparator:^NSComparisonResult(UIView *obj1, UIView *obj2) {
                return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)];
            }];
            
            if (cells.count > 0) {
                NSMutableArray *textParts = [NSMutableArray array];
                for (id cell in cells) {
                    id titleObj = GetIvarValueFromObject(cell, "標題");
                    id detailObj = GetIvarValueFromObject(cell, "解");
                    NSString *title = [titleObj isKindOfClass:[NSString class]] ? titleObj : @"";
                    NSString *detail = [detailObj isKindOfClass:[NSString class]] ? detailObj : @"";
                    if (title.length > 0 || detail.length > 0) {
                        [textParts addObject:[NSString stringWithFormat:@"%@: %@", title, detail]];
                    }
                }
                
                if (textParts.count > 0) {
                    g_testExtractedData[@"格局"] = [textParts componentsJoinedByString:@"\n"];
                } else {
                    g_testExtractedData[@"格局"] = @"解析成功，但未能提取到有效文本。";
                }
            } else {
                 g_testExtractedData[@"格局"] = @"解析失败: 未找到任何'格局單元'Cell。";
            }
        } else {
             g_testExtractedData[@"格局"] = [NSString stringWithFormat:@"提取失败，拦截到错误的VC: %@", vcClassName];
        }

        [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
    });
}

// -------------------------------------------------------------------------
// 3. 按钮点击事件【已修复编译错误】
// -------------------------------------------------------------------------
%new
- (void)testGeJuExtractionTapped_V9 {
    EchoLog(@"--- V9: 开始触发格局弹窗 ---");
    g_testExtractedData = [NSMutableDictionary dictionary];

    SEL selectorGeJu = NSSelectorFromString(@"顯示格局總覽");
    if (![self respondsToSelector:selectorGeJu]) {
        return;
    }
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:selectorGeJu withObject:nil];
    #pragma clang diagnostic pop

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *resultText = g_testExtractedData[@"格局"] ?: @"提取失败，未捕获到任何内容。";
        
        [UIPasteboard generalPasteboard].string = resultText;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"格局提取(V9)结果"
                                                                       message:resultText
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        
        // --- 【核心编译错误修复】 ---
        // 使用现代API获取最顶层的ViewController来弹出Alert
        UIViewController *presentingVC = self;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    if ([scene.delegate respondsToSelector:@selector(window)]) {
                        UIWindow *window = [(id <UIWindowSceneDelegate>)scene.delegate window];
                        if (window) {
                           presentingVC = window.rootViewController;
                           while (presentingVC.presentedViewController) {
                               presentingVC = presentingVC.presentedViewController;
                           }
                        }
                    }
                    break;
                }
            }
        } else {
            // Fallback on earlier versions
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            presentingVC = [UIApplication sharedApplication].keyWindow.rootViewController;
            #pragma clang diagnostic pop
        }

        [presentingVC presentViewController:alert animated:YES completion:^{
            g_testExtractedData = nil;
        }];
    });
}

%end
