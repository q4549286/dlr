#import <UIKit/UIKit.h>

%hook UILabel

// 主要 hook setText: 方法
- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }

    NSString *newString = nil;

    // --- 第 1 步：检查是否是我们想修改的特定文本 ---

    // 案例一: "通类" 或 "我的分类" -> "Echo"
    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) {
        newString = @"Echo";
    } 
    // 案例二: "起課" (繁体) 或 "起课" (简体) -> "定制"
    else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) {
        newString = @"定制";
    }
    // 案例三: "法诀" (简体) 或 "法訣" (繁体) -> "毕法"
    else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) {
        newString = @"毕法";
    }

    // --- 如果匹配到了任何一个案例，就执行样式保留并替换 ---
    if (newString) {
        // 从 Label 自身获取当前正在使用的字体、颜色和对齐方式
        UIFont *currentFont = self.font;
        UIColor *currentColor = self.textColor;
        NSTextAlignment alignment = self.textAlignment;
        
        // 创建属性字典以保存样式
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        if (currentFont) attributes[NSFontAttributeName] = currentFont;
        if (currentColor) attributes[NSForegroundColorAttributeName] = currentColor;
        
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = alignment;
        attributes[NSParagraphStyleAttributeName] = paragraphStyle;

        // 使用新文本和旧样式，创建新的富文本
        NSAttributedString *newAttributedText = [[NSAttributedString alloc] initWithString:newString attributes:attributes];

        // 应用新的富文本并直接返回，不再执行后续代码
        [self setAttributedText:newAttributedText];
        return;
    }

    // --- 第 2 步：如果不是特殊文本，就执行通用的繁体转简体 ---
    NSMutableString *simplifiedText = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false);

    %orig(simplifiedText);
}

// 同时 hook setAttributedText: 以增强代码的健壮性
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) {
        %orig;
        return;
    }

    NSString *originalString = attributedText.string;
    NSString *newString = nil;

    // --- 同样，先检查特殊文本 ---
    if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) {
        newString = @"Echo";
    } 
    else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) {
        newString = @"定制";
    }
    // 案例三: "法诀" (简体) 或 "法訣" (繁体) -> "毕法"
    else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) {
        newString = @"毕法";
    }


    if (newString) {
        // 直接在富文本副本上修改字符串内容，保留所有样式
        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        [newAttributedText.mutableString setString:newString];
        %orig(newAttributedText);
        return;
    }
    
    // --- 再处理通用繁转简 ---
    NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false);
    
    %orig(newAttributedText);
}

%end
#import <UIKit/UIKit.h>

// ==========================================================
// iOS 13+ 状态栏强制显示“黄金标准”方案 (V9 - The Modern Way)
// ==========================================================

// 我们只Hook所有视图控制器的基类，因为这是现代iOS管理状态栏的唯一地方
%hook UIViewController

// 第一步：声明“法律”
// 当系统询问“这个页面的状态栏要不要隐藏？”时，我们斩钉截铁地回答“不！”
- (BOOL)prefersStatusBarHidden {
    return NO;
}

// 第二步：确保我们拥有“最高解释权”
// 有些容器控制器(如导航栏)会把状态栏的控制权交给它的子页面。
// 我们返回nil，等于告诉系统：“别问我的手下，直接问我！而我的答案永远是‘不隐藏’。”
- (UIViewController *)childViewControllerForStatusBarHidden {
    return nil;
}

// 第三步：在每次界面出现时，强制刷新“法律”
// 作为保险，每次界面显示时，我们都主动告诉系统：“请根据我的最新意愿，重新评估一下状态栏该怎么显示！”
// 这会强制系统再次调用上面的 prefersStatusBarHidden 方法。
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (@available(iOS 11.0, *)) {
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

%end
