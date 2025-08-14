////// Filename: TimeExtractor_for_LRDZ.xm
// 描述: 六壬大占App - 时间选择器独立提取脚本 v1.0
// 作者: AI (Based on user request)
// 功能:
//  - 在主界面添加一个“时间提取”按钮。
//  - 点击按钮后，静默调用并解析“时间选择”弹窗。
//  - 将提取并格式化的时间信息通过一个结果弹窗显示，并提供复制功能。
//  - 本脚本完全独立，可用于专项功能测试。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================

// 用于识别我们的按钮和控制提取流程的标志
static const NSInteger kTimeExtractorButtonTag = 20240813;
static BOOL g_isExtractingTimeInfo = NO;

// 辅助函数：递归查找指定类的所有子视图
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}

// 辅助函数：获取最顶层的窗口
static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        frontmostWindow = window;
                        break;
                    }
                }
                if (frontmostWindow) break;
            }
        }
    }
    if (!frontmostWindow) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        frontmostWindow = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
    }
    return frontmostWindow;
}


// =========================================================================
// 2. 核心Hook：拦截弹窗
// =========================================================================

// 保存原始的 presentViewController 方法指针
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));

// 我们自己的 presentViewController 实现
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    
    // 检查是否是我们触发的，并且弹窗类型是否正确
    if (g_isExtractingTimeInfo && [NSStringFromClass([vcToPresent class]) containsString:@"時間選擇視圖"]) {
        
        NSLog(@"[TimeExtractor] 成功拦截到'時間選擇視圖'。");
        
        // 重置标志，避免干扰正常操作
        g_isExtractingTimeInfo = NO;
        
        // 让弹窗在后台处理，用户不可见
        vcToPresent.view.alpha = 0.0f;
        animated = NO;
        
        // 创建一个新的完成回调，在原始回调执行后开始我们的提取工作
        void (^extractionCompletion)(void) = ^{
            if (completion) {
                completion();
            }

            // --- 数据提取核心逻辑 ---
            UIView *contentView = vcToPresent.view;
            
            // 1. 查找所有UILabel
            NSMutableArray *allLabels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
            
            // 2. 按垂直位置排序，确保文本顺序正确
            [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
                return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)];
            }];
            
            // 3. 格式化提取文本
            NSMutableString *extractedText = [NSMutableString string];
            BOOL foundTimeDetailsHeader = NO;
            for (UILabel *label in allLabels) {
                NSString *text = label.text;
                if (!text || text.length == 0) continue;
                
                // 找到“四时五行”这个关键标题后，开始拼接下面的详细信息
                if ([text containsString:@"四时五行"]) {
                    foundTimeDetailsHeader = YES;
                    [extractedText appendFormat:@"%@\n", text]; // 添加标题本身
                    continue;
                }
                
                // 如果已经找到了标题，就拼接后续所有标签的文本
                if (foundTimeDetailsHeader) {
                    [extractedText appendFormat:@"%@\n", text];
                } else { // 如果还没找到，就先提取像“日期”、“时刻”这样的独立信息
                     if ([text containsString:@"日期"] || [text containsString:@"时刻"]) {
                         // 简单的提取，可以根据需要进行更复杂的键值对解析
                         [extractedText appendFormat:@"%@\n", text];
                     }
                }
            }
            
            // 清理最后的空行
            NSString *finalResult = [extractedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSLog(@"[TimeExtractor] 提取结果:\n%@", finalResult);
            
            // 4. 显示结果弹窗
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *resultAlert = [UIAlertController alertControllerWithTitle:@"时间信息提取结果"
                                                                                       message:finalResult
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                
                UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"复制" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [UIPasteboard generalPasteboard].string = finalResult;
                    NSLog(@"[TimeExtractor] 结果已复制到剪贴板。");
                }];
                
                UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil];
                
                [resultAlert addAction:copyAction];
                [resultAlert addAction:closeAction];
                
                // 从 self (也就是 ViewController) 来呈现结果弹窗
                [self presentViewController:resultAlert animated:YES completion:nil];
            });

            // 5. 关闭后台的、不可见的时间选择器
            [vcToPresent dismissViewControllerAnimated:NO completion:nil];
        };

        // 调用原始的 presentViewController，但使用我们注入了提取逻辑的回调
        Original_presentViewController(self, _cmd, vcToPresent, animated, extractionCompletion);
        return;
    }

    // 如果不是我们想要拦截的弹窗，就执行原始逻辑
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}


// =========================================================================
// 3. UI注入与事件处理
// =========================================================================

%hook 六壬大占.ViewController

// 在视图加载完成后，添加我们的按钮
- (void)viewDidLoad {
    %orig;

    // 使用 dispatch_after 确保界面元素已完成布局
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = GetFrontmostWindow();
        if (!keyWindow || [keyWindow viewWithTag:kTimeExtractorButtonTag]) {
            return; // 如果没找到窗口或者按钮已存在，则不处理
        }
        
        // 创建“时间提取”按钮
        UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
        // 放置在“Echo 解析”按钮的下方
        extractButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 36 + 10, 140, 36);
        extractButton.tag = kTimeExtractorButtonTag;
        [extractButton setTitle:@"时间提取" forState:UIControlStateNormal];
        extractButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        extractButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.35 alpha:1.0]; // 使用绿色区分
        [extractButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        extractButton.layer.cornerRadius = 18;
        extractButton.layer.shadowColor = [UIColor blackColor].CGColor;
        extractButton.layer.shadowOffset = CGSizeMake(0, 2);
        extractButton.layer.shadowOpacity = 0.4;
        extractButton.layer.shadowRadius = 3;
        
        // 添加点击事件
        [extractButton addTarget:self action:@selector(handleTimeExtractTap) forControlEvents:UIControlEventTouchUpInside];
        
        [keyWindow addSubview:extractButton];
        NSLog(@"[TimeExtractor] “时间提取”按钮已添加。");
    });
}

// 新增方法：处理按钮点击
%new
- (void)handleTimeExtractTap {
    NSLog(@"[TimeExtractor] “时间提取”按钮被点击。");
    
    // 设置标志，告诉我们的 hook 准备拦截
    g_isExtractingTimeInfo = YES;
    
    // 获取方法选择器
    SEL showTimePickerSelector = NSSelectorFromString(@"顯示時間選擇");
    
    if ([self respondsToSelector:showTimePickerSelector]) {
        // 调用原始App的方法来弹出时间选择器
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:showTimePickerSelector];
        #pragma clang diagnostic pop
    } else {
        NSLog(@"[TimeExtractor] 错误: 找不到 '顯示時間選擇' 方法。");
        g_isExtractingTimeInfo = NO; // 重置标志
        // 可以加一个弹窗提示用户
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"错误" message:@"无法调用时间选择器功能，可能是App版本不兼容。" preferredStyle:UIAlertControllerStyleAlert];
        [errorAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:errorAlert animated:YES completion:nil];
    }
}

%end


// =========================================================================
// 4. 构造函数：应用所有Hook
// =========================================================================

%ctor {
    @autoreleasepool {
        // Hook UIViewController 的 present 方法
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        
        // 确保 ViewController 的 hook 生效
        %init(六壬大占_ViewController);

        NSLog(@"[TimeExtractor] v1.0 独立时间提取脚本已加载。");
    }
}
