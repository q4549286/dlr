#import <UIKit/UIKit.h>

// 提前声明我们要给UIView添加的新方法，解决“no visible @interface”报错
// 这就像一个目录，告诉编译器这些方法是存在的
@interface UIView (CopyTweak)
- (void)handleLongPressForCopy:(UILongPressGestureRecognizer *)gesture;
- (void)findAndAppendTextInView:(UIView *)view toString:(NSMutableString *)text;
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
        NSMutableString *foundText = [NSMutableString string];
        
        // 从被长按的视图开始，递归查找文本
        [self findAndAppendTextInView:gesture.view toString:foundText];

        if (foundText.length > 0) {
            NSString *finalText = [foundText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            [[UIPasteboard generalPasteboard] setString:finalText];
            
            // --- 这是修复 'keyWindow' is deprecated 警告的部分 ---
            // 使用现代API获取当前活跃的窗口
            UIWindow *activeWindow = nil;
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    activeWindow = scene.windows.firstObject;
                    break;
                }
            }

            // 获取顶层视图控制器来弹出提示框
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
// 新增方法：递归查找并拼接视图内的文本
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
