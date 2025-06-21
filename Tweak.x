#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// Section 1 & 2: 您的原始代码 (已移除繁简转换)
// =========================================================================
%hook UILabel
// 【关键修正】完全移除了 setText 和 setAttributedText 里的繁简转换逻辑
// 只保留您最初的文字替换功能
- (void)setText:(NSString *)text {
    if (!text) { %orig(text); return; }
    NSString *newString = nil;
    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } 
    else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; }
    else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; }

    if (newString) {
        %orig(newString);
    } else {
        %orig(text);
    }
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) { %orig(attributedText); return; }
    NSString *originalString = attributedText.string;
    NSString *newString = nil;
    if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } 
    else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; }
    else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; }

    if (newString) {
        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        [newAttributedText.mutableString setString:newString];
        %orig(newAttributedText);
    } else {
        %orig(attributedText);
    }
}
%end

static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }
%hook UIWindow
- (void)layoutSubviews { %orig; if (self.windowLevel != UIWindowLevelNormal) { return; } NSInteger watermarkTag = 998877; if ([self viewWithTag:watermarkTag]) { return; } NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; CGFloat rotationAngle = -30.0; CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag; watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; [self addSubview:watermarkView]; [self bringSubviewToFront:watermarkView]; }
%end


// =========================================================================
// Section 3: 【新功能】一键复制到 AI (最终诊断版 - 已移除繁简转换)
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;

@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalDiagnosis;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow || [keyWindow viewWithTag:CopyAiButtonTag]) { return; }
            UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
            copyButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45, 90, 36); 
            copyButton.tag = CopyAiButtonTag;
            [copyButton setTitle:@"诊断课体" forState:UIControlStateNormal];
            copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            copyButton.backgroundColor = [UIColor systemTealColor];
            [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            copyButton.layer.cornerRadius = 8;
            [copyButton addTarget:self action:@selector(copyAiButtonTapped_FinalDiagnosis) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:copyButton];
        });
    }
}

// 辅助方法：递归查找指定类的所有子视图
%new
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage {
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        [self findSubviewsOfClass:aClass inView:subview andStoreIn:storage];
    }
}

// 【终极诊断版】
%new
- (void)copyAiButtonTapped_FinalDiagnosis {
    NSMutableString *diagnosisResult = [NSMutableString string];

    // --- 步骤 1: 检查类是否能找到 ---
    Class ketiCellClass = NSClassFromString(@"六壬大占.课体单元");
    // 同时尝试繁体类名，以防万一
    if (!ketiCellClass) {
        ketiCellClass = NSClassFromString(@"六壬大占.課體單元");
    }

    if (ketiCellClass) {
        [diagnosisResult appendString:@"[成功] 找到了课体单元类。\n\n"];
    } else {
        [diagnosisResult appendString:@"[失败] 找不到 '六壬大占.课体单元' 或 '六壬大占.課體單元'。请用FLEX再次确认类名。\n"];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"诊断报告" message:diagnosisResult preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // --- 步骤 2: 查找所有课体单元格 ---
    NSMutableArray *ketiCells = [NSMutableArray array];
    [self findSubviewsOfClass:ketiCellClass inView:self.view andStoreIn:ketiCells];
    [diagnosisResult appendFormat:@"[信息] 共找到 %ld 个课体单元实例。\n\n", (unsigned long)ketiCells.count];

    if (ketiCells.count == 0) {
        [diagnosisResult appendString:@"[问题] 虽然找到了类，但在界面上没有找到它的实例。\n"];
    }

    // --- 步骤 3: 检查每个单元格内部 ---
    NSMutableString *fullKetiText = [NSMutableString string];
    int cellIndex = 0;
    for (UICollectionViewCell *cell in ketiCells) {
        NSMutableArray *labelsInCell = [NSMutableArray array];
        [self findSubviewsOfClass:[UILabel class] inView:cell.contentView andStoreIn:labelsInCell];
        
        if (labelsInCell.count > 0) {
            NSString* labelText = ((UILabel *)labelsInCell.firstObject).text ?: @"(空)";
            [diagnosisResult appendFormat:@"单元格 %d: 找到了UILabel，内容是 '%@'\n", cellIndex, labelText];
            [fullKetiText appendString:labelText];
        } else {
            [diagnosisResult appendFormat:@"单元格 %d: [警告] 内部没有找到UILabel！\n", cellIndex];
        }
        cellIndex++;
    }
    
    [diagnosisResult appendFormat:@"\n\n最终拼接结果:\n%@", fullKetiText];

    // --- 步骤 4: 显示完整的诊断报告 ---
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"课体提取诊断报告" message:diagnosisResult preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"复制报告" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:copyAction];
    [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
