#import <UIKit/UIKit.h>

// 提前声明我们要给UIView添加的新方法
@interface UIView (CopyTweak)
- (void)handleLongPressForCopy:(UILongPressGestureRecognizer *)gesture;
- (void)findAndAppendTextInView:(UIView *)view toString:(NSMutableString *)text;
- (UITextView *)findParentTextViewFrom:(UIView *)startView; // 新增一个辅助方法的声明
@end


%hook UIView

// 当UIView初始化时，添加我们的自定义手势
- (id)initWithFrame:(CGRect)frame {
    id result = %orig;
    if (result) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressForCopy:)];
        [self addGestureRecognizer:longPress];
    }
    return result;
}

%new
// 新增方法：处理长按手势
- (void)handleLongPressForCopy:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        NSString *finalText = nil;

        // --- 核心逻辑更新 ---
        // 1. 优先策略：向上查找父视图，看是否存在一个UITextView。
        UITextView *parentTextView = [self findParentTextViewFrom:gesture.view];
        if (parentTextView && parentTextView.text.length > 0) {
            // 如果找到了，直接获取它的全部文本
            finalText = parentTextView.text;
        } else {
            // 2. 备用策略：如果没找到，就使用原来的向下递归查找方法。
            NSMutableString *recursiveText = [NSMutableString string];
            [self findAndAppendTextInView:gesture.view toString:recursiveText];
            if (recursiveText.length > 0) {
                finalText = [recursiveText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            }
        }

        // 如果我们通过任何一种方式找到了文本，就复制并弹出提示
        if (finalText && finalText.length > 0) {
            [[UIPasteboard generalPasteboard] setString:finalText];
            
            // 使用现代API获取当前活跃的窗口
            UIWindow *activeWindow = nil;
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    // 有些App会有多个window，我们取最后一个，通常是UI的主window
                    activeWindow = scene.windows.lastObject; 
                    break;
                }
            }

            UIViewController *presentingVC = activeWindow.rootViewController;
            while (presentingVC.presentedViewController) {
                presentingVC = presentingVC.presentedViewController;
            }

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"复制成功"
                                                                             message:[NSString stringWithFormat:@"已复制 %lu 个字符", (unsigned long)finalText.length]
                                                                      preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            
            if (presentingVC) {
                [presentingVC presentViewController:alert animated:YES completion:nil];
            }
        }
    }
}

%new
// 新增辅助方法：从一个视图开始，向上遍历，寻找UITextView类型的父视图
- (UITextView *)findParentTextViewFrom:(UIView *)startView {
    UIView *currentView = startView;
    while (currentView) {
        if ([currentView isKindOfClass:[UITextView class]]) {
            return (UITextView *)currentView;
        }
        currentView = currentView.superview;
    }
    return nil; // 没找到
}


%new
// 备用方法：递归查找并拼接视图内的文本（用于处理非滚动视图）
- (void)findAndAppendTextInView:(UIView *)view toString:(NSMutableString *)text {
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (label.text.length > 0 && !label.isHidden) {
            [text appendString:label.text];
            [text appendString:@"\n"];
        }
    } else if ([view isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)view;
        if (textView.text.length > 0 && !textView.isHidden) {
            [text appendString:textView.text];
            [text appendString:@"\n"];
        }
    }

    for (UIView *subview in view.subviews) {
        [self findAndAppendTextInView:subview toString:text];
    }
}

%end
