#import <UIKit/UIKit.h>

// 提前声明我们要给UIView添加的新方法
@interface UIView (CopyTweak)
- (void)handleLongPressForCopy:(UILongPressGestureRecognizer *)gesture;
- (void)findAndAppendTextInView:(UIView *)view toString:(NSMutableString *)text;
- (UITableView *)findParentTableViewFrom:(UIView *)startView; // 新增一个辅助方法的声明
@end


%hook UIView

// 当UIView初始化时，添加我们的自定义手势
- (id)initWithFrame:(CGRect)frame {
    id result = %orig;
    if (result) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressForCopy:)];
        longPress.minimumPressDuration = 0.5; // 设置长按时间
        [self addGestureRecognizer:longPress];
    }
    return result;
}

%new
// 新增方法：处理长按手势
- (void)handleLongPressForCopy:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        NSString *finalText = nil;
        NSMutableString *allText = [NSMutableString string];

        // --- 核心逻辑：专门为UITableView优化 ---
        // 1. 优先策略：向上查找父视图，看是否存在一个UITableView。
        UITableView *parentTableView = [self findParentTableViewFrom:gesture.view];
        if (parentTableView) {
            // 如果找到了，遍历整个UITableView的数据源来获取全部文本
            id<UITableViewDataSource> dataSource = parentTableView.dataSource;
            NSInteger sections = 1;
            if ([dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]) {
                sections = [dataSource numberOfSectionsInTableView:parentTableView];
            }

            for (NSInteger i = 0; i < sections; i++) {
                NSInteger rows = [dataSource tableView:parentTableView numberOfRowsInSection:i];
                for (NSInteger j = 0; j < rows; j++) {
                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:j inSection:i];
                    UITableViewCell *cell = [dataSource tableView:parentTableView cellForRowAtIndexPath:indexPath];
                    if (cell) {
                        // 在cell的contentView里递归查找所有文本并拼接
                        [self findAndAppendTextInView:cell.contentView toString:allText];
                    }
                }
            }
            if (allText.length > 0) {
                finalText = [allText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            }

        } else {
            // 2. 备用策略：如果不在UITableView里，就使用老方法。
            [self findAndAppendTextInView:gesture.view toString:allText];
            if (allText.length > 0) {
                 finalText = [allText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            }
        }

        // 如果我们通过任何一种方式找到了文本，就复制并弹出提示
        if (finalText && finalText.length > 0) {
            [[UIPasteboard generalPasteboard] setString:finalText];
            
            // 使用现代API获取当前活跃的窗口
            UIWindow *activeWindow = nil;
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
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
// 新增辅助方法：从一个视图开始，向上遍历，寻找UITableView类型的父视图
- (UITableView *)findParentTableViewFrom:(UIView *)startView {
    UIView *currentView = startView;
    while (currentView) {
        if ([currentView isKindOfClass:[UITableView class]]) {
            return (UITableView *)currentView;
        }
        currentView = currentView.superview;
    }
    return nil; // 没找到
}


%new
// 通用方法：递归查找并拼接一个视图内的所有文本
- (void)findAndAppendTextInView:(UIView *)view toString:(NSMutableString *)text {
    // 强制按从上到下的顺序排序子视图，保证文本顺序正确
    NSArray *sortedSubviews = [view.subviews sortedArrayUsingComparator:^NSComparisonResult(UIView *obj1, UIView *obj2) {
        if (obj1.frame.origin.y < obj2.frame.origin.y) {
            return NSOrderedAscending;
        } else if (obj1.frame.origin.y > obj2.frame.origin.y) {
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];

    for (UIView *subview in sortedSubviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            if (label.text.length > 0 && !label.isHidden) {
                [text appendString:label.text];
                [text appendString:@"\n"];
            }
        } else if ([subview isKindOfClass:[UITextView class]]) {
            UITextView *textView = (UITextView *)subview;
             if (textView.text.length > 0 && !textView.isHidden) {
                [text appendString:textView.text];
                [text appendString:@"\n"];
            }
        } else {
            // 如果不是Label或TextView，就继续深入它的子视图查找
            [self findAndAppendTextInView:subview toString:text];
        }
    }
}

%end
