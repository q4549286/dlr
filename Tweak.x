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
// ==========================================================
// “巡逻警察”状态栏强制显示方案 (V7 - The Last Resort)
// ==========================================================

// 我们Hook所有视图控制器的基类
%hook UIViewController

// 第一步：设定法律 - “状态栏不许隐藏”
// 这是我们希望遵守的规则
- (BOOL)prefersStatusBarHidden {
    return NO;
}

// 第二步：派警察巡逻 - “每次界面出现时，都强制执行法律”
// 这个方法在每个ViewController的视图显示后都会被调用
- (void)viewDidAppear:(BOOL)animated {
    // 先让它完成自己该做的事
    %orig;

    // --- 开始强制执法 ---

    // 执法手段1：现代、文明的方式
    // 告诉系统：“请根据我上面设定的法律，重新刷新一下状态栏！”
    // 这会触发上面的prefersStatusBarHidden方法
    if (@available(iOS 11.0, *)) {
        [self setNeedsStatusBarAppearanceUpdate];
    }

    // 执法手段2：老派、强硬的方式 (作为双重保险)
    // 直接对UIApplication下命令：“我不管你怎么想的，现在立刻把状态栏给我亮出来！”
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([[UIApplication sharedApplication] isStatusBarHidden]) {
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
    }
    #pragma clang diagnostic pop
}

%end
