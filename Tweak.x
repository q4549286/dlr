%hook UIView // 我们可以Hook一个通用的父类，比如UIView

// 当UIView初始化完成后，给它添加一个手势
- (id)initWithFrame:(CGRect)frame {
    id result = %orig; // 调用原始方法
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressForCopy:)];
    [self addGestureRecognizer:longPress];
    [longPress release];
    return result;
}

// 新增一个方法来处理手势
%new
- (void)handleLongPressForCopy:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        NSMutableString *foundText = [NSMutableString string];
        
        // 调用一个递归函数来查找并拼接文本
        [self findAndAppendTextInView:self toString:foundText];

        if (foundText.length > 0) {
            // 复制到剪贴板
            [[UIPasteboard generalPasteboard] setString:foundText];
            
            // 给用户一个提示（可选，但推荐）
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"复制成功" message:[NSString stringWithFormat:@"已复制 %lu 个字符", (unsigned long)foundText.length] preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
            
            // 获取顶层ViewController来弹出提示框
            UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
            [rootVC presentViewController:alert animated:YES completion:nil];

        }
    }
}

// 新增一个递归函数来遍历视图并提取文本
%new
- (void)findAndAppendTextInView:(UIView *)view toString:(NSMutableString *)text {
    // 检查当前视图是否是UILabel或UITextView
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (label.text.length > 0) {
            [text appendString:label.text];
            [text appendString:@"\n"]; // 添加换行符分隔
        }
    } else if ([view isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)view;
        if (textView.text.length > 0) {
            [text appendString:textView.text];
            [text appendString:@"\n"];
        }
    }

    // 递归遍历所有子视图
    for (UIView *subview in view.subviews) {
        [self findAndAppendTextInView:subview toString:text];
    }
}

%end
