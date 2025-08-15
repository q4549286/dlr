#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量、常量定义与辅助函数
// =========================================================================
#pragma mark - Constants & Colors
static const NSInteger kEchoControlButtonTag    = 556699;
static const NSInteger kEchoMainPanelTag        = 778899;
static const NSInteger kButtonTag_ExtractShenSha  = 101;
static const NSInteger kButtonTag_ClosePanel      = 998;

#define ECHO_COLOR_MAIN_BLUE    [UIColor colorWithRed:0.17 green:0.31 blue:0.51 alpha:1.0]
#define ECHO_COLOR_MAIN_TEAL    [UIColor colorWithRed:0.23 green:0.49 blue:0.49 alpha:1.0]
#define ECHO_COLOR_ACTION_CLOSE [UIColor colorWithWhite:0.25 alpha:1.0]

#pragma mark - Global State
static UIView *g_mainControlPanelView = nil;

#pragma mark - Helper Functions
// 日志函数 (简化版)
static void LogMessage(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[Echo神煞测试] %@", message);
}

// 递归查找子视图
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}

// 获取最顶层窗口
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
// 2. 接口声明与核心 Hook
// =========================================================================

@interface UIViewController (EchoShenShaTest)
- (void)createOrShowShenShaTestPanel;
- (void)handleShenShaButtonTap:(UIButton *)sender;
- (void)presentAIActionSheetWithReport:(NSString *)report;
- (NSString *)extractShenShaInfo;
@end

%hook UILabel
// 简化界面文字，便于识别
- (void)setText:(NSString *)text {
    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) {
        %orig(@"Echo");
    } else {
        %orig(text);
    }
}
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if ([attributedText.string isEqualToString:@"我的分类"] || [attributedText.string isEqualToString:@"我的分類"] || [attributedText.string isEqualToString:@"通類"]) {
        NSMutableAttributedString *newAttr = [attributedText mutableCopy];
        [newAttr.mutableString setString:@"Echo"];
        %orig(newAttr);
    } else {
        %orig(attributedText);
    }
}
%end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    // 仅在主界面添加按钮
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = GetFrontmostWindow();
            if (!keyWindow) return;
            if ([keyWindow viewWithTag:kEchoControlButtonTag]) {
                [[keyWindow viewWithTag:kEchoControlButtonTag] removeFromSuperview];
            }
            UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
            controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            controlButton.tag = kEchoControlButtonTag;
            [controlButton setTitle:@"神煞测试" forState:UIControlStateNormal];
            controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            controlButton.backgroundColor = ECHO_COLOR_MAIN_BLUE;
            [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            controlButton.layer.cornerRadius = 18;
            [controlButton addTarget:self action:@selector(createOrShowShenShaTestPanel) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:controlButton];
        });
    }
}

%new
- (void)createOrShowShenShaTestPanel {
    UIWindow *keyWindow = GetFrontmostWindow();
    if (!keyWindow) return;
    
    if (g_mainControlPanelView && g_mainControlPanelView.superview) {
        [g_mainControlPanelView removeFromSuperview];
        g_mainControlPanelView = nil;
        return;
    }

    g_mainControlPanelView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    g_mainControlPanelView.tag = kEchoMainPanelTag;
    g_mainControlPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(20, (keyWindow.bounds.size.height - 200) / 2, keyWindow.bounds.size.width - 40, 200)];
    contentView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    contentView.layer.cornerRadius = 15;
    [g_mainControlPanelView addSubview:contentView];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, contentView.bounds.size.width, 30)];
    titleLabel.text = @"神煞提取测试";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:titleLabel];

    UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
    extractButton.frame = CGRectMake(20, 70, contentView.bounds.size.width - 40, 50);
    [extractButton setTitle:@"提取神煞信息" forState:UIControlStateNormal];
    extractButton.backgroundColor = ECHO_COLOR_MAIN_TEAL;
    [extractButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    extractButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    extractButton.layer.cornerRadius = 10;
    extractButton.tag = kButtonTag_ExtractShenSha;
    [extractButton addTarget:self action:@selector(handleShenShaButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:extractButton];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(20, 140, contentView.bounds.size.width - 40, 40);
    [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    closeButton.backgroundColor = ECHO_COLOR_ACTION_CLOSE;
    [closeButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    closeButton.layer.cornerRadius = 10;
    closeButton.tag = kButtonTag_ClosePanel;
    [closeButton addTarget:self action:@selector(handleShenShaButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:closeButton];

    [keyWindow addSubview:g_mainControlPanelView];
}

%new
- (void)handleShenShaButtonTap:(UIButton *)sender {
    switch (sender.tag) {
        case kButtonTag_ExtractShenSha: {
            LogMessage(@"任务开始: 提取神煞信息...");
            NSString *shenShaResult = [self extractShenShaInfo];
            LogMessage(@"提取结果:\n---\n%@\n---", shenShaResult);
            if (shenShaResult.length > 0) {
                 [self presentAIActionSheetWithReport:shenShaResult];
            } else {
                 UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"未找到神煞信息或信息为空。" preferredStyle:UIAlertControllerStyleAlert];
                 [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
                 [self presentViewController:alert animated:YES completion:nil];
            }
            break;
        }
        case kButtonTag_ClosePanel:
            [self createOrShowShenShaTestPanel]; // 调用自身以关闭
            break;
        default:
            break;
    }
}

%new
- (void)presentAIActionSheetWithReport:(NSString *)report {
    if (!report || report.length == 0) return;
    [UIPasteboard generalPasteboard].string = report; 

    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"提取成功" message:@"神煞信息已复制到剪贴板" preferredStyle:UIAlertControllerStyleActionSheet];
    
    // 仅提供复制和取消选项
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"好的，已复制" style:UIAlertActionStyleDefault handler:nil];
    [actionSheet addAction:copyAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [actionSheet addAction:cancelAction];
    
    // 兼容 iPad
    if (actionSheet.popoverPresentationController) {
        actionSheet.popoverPresentationController.sourceView = self.view;
        actionSheet.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height, 1.0, 1.0);
        actionSheet.popoverPresentationController.permittedArrowDirections = 0;
    }
    
    [self presentViewController:actionSheet animated:YES completion:nil];
}

// =========================================================================
// 3. 核心提取函数
// =========================================================================

%new
- (NSString *)extractShenShaInfo {
    // 1. 定位神煞视图的类
    Class shenShaViewClass = NSClassFromString(@"六壬大占.神煞視圖");
    if (!shenShaViewClass) {
        LogMessage(@"错误: 找不到 '六壬大占.神煞視圖' 类。");
        return @"[神煞提取失败: 找不到视图类]";
    }

    // 2. 在当前视图中找到神煞视图的实例
    NSMutableArray *shenShaViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(shenShaViewClass, self.view, shenShaViews);
    if (shenShaViews.count == 0) {
        LogMessage(@"未在当前界面找到神煞视图。");
        return @""; // 可能当前盘面没有神煞信息，返回空字符串
    }
    UIView *containerView = shenShaViews.firstObject;

    // 3. 在神煞视图中找到 UICollectionView
    NSMutableArray *collectionViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], containerView, collectionViews);
    if (collectionViews.count == 0) {
        LogMessage(@"错误: 在神煞视图内找不到 UICollectionView。");
        return @"[神煞提取失败: 找不到集合视图]";
    }
    UICollectionView *collectionView = collectionViews.firstObject;

    // 4. 获取所有可见的单元格并进行精确排序
    NSMutableArray<UICollectionViewCell *> *cells = [[collectionView visibleCells] mutableCopy];
    [cells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
        if (roundf(v1.frame.origin.y) < roundf(v2.frame.origin.y)) {
            return NSOrderedAscending;
        }
        if (roundf(v1.frame.origin.y) > roundf(v2.frame.origin.y)) {
            return NSOrderedDescending;
        }
        return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)];
    }];

    if (cells.count == 0) {
        LogMessage(@"信息为空。");
        return @"";
    }

    // 5. 遍历单元格，提取文本并格式化
    NSMutableString *resultString = [NSMutableString string];
    CGFloat lastY = -1.0;

    for (UICollectionViewCell *cell in cells) {
        NSMutableArray *labels = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labels);
        
        [labels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
            return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)];
        }];

        NSMutableArray *textParts = [NSMutableArray array];
        for (UILabel *label in labels) {
            if (label.text.length > 0) {
                [textParts addObject:label.text];
            }
        }
        
        if (textParts.count == 0) continue;

        if (lastY > 0 && roundf(cell.frame.origin.y) > roundf(lastY)) {
            [resultString appendString:@"\n"];
        }

        if (resultString.length > 0 && ![resultString hasSuffix:@"\n"]) {
             [resultString appendString:@" | "];
        }
        
        if (textParts.count == 1) { // 适用于行首的标识，如 "亥"
            [resultString appendFormat:@"%@:", textParts.firstObject];
        } else if (textParts.count >= 2) { // 适用于神煞对，如 "死符" "申"
            [resultString appendFormat:@" %@(%@)", textParts[0], textParts[1]];
        } else {
             [resultString appendString:[textParts componentsJoinedByString:@" "]];
        }
        
        lastY = cell.frame.origin.y;
    }
    
    NSString *finalResult = [resultString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    // 清理可能产生的行首多余空格
    finalResult = [finalResult stringByReplacingOccurrencesOfString:@"\n " withString:@"\n"];

    LogMessage(@"提取成功。");
    return finalResult;
}

%end

%ctor {
    NSLog(@"[Echo神煞测试] Tweak 已加载。");
}
