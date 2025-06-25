#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// V17 - “推土机”终极版
// =========================================================================

static UITextView *g_ bulldozerTextView = nil;

// 日志函数
static void LogToBulldozerPanel(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[BulldozerV17] %@", message);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_bulldozerTextView) {
            NSString *currentText = g_bulldozerTextView.text;
            g_bulldozerTextView.text = [currentText stringByAppendingFormat:@"%@\n", message];
            if (g_bulldozerTextView.text.length > 0) {
                [g_bulldozerTextView scrollRangeToVisible:NSMakeRange(g_bulldozerTextView.text.length - 1, 1)];
            }
        }
    });
}

// 递归在视图中寻找第一个UICollectionView
static UICollectionView* findCollectionViewInView(UIView *view) {
    if ([view isKindOfClass:[UICollectionView class]]) {
        return (UICollectionView *)view;
    }
    for (UIView *subview in view.subviews) {
        UICollectionView *collectionView = findCollectionViewInView(subview);
        if (collectionView) {
            return collectionView;
        }
    }
    return nil;
}

// 递归搜索所有文本
static void findTextRecursive(UIView* view, NSMutableArray<NSString *> *foundTexts) {
    if (view.hidden || view.alpha < 0.01) return;

    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (label.text.length > 0) [foundTexts addObject:label.text];
    } else if ([view isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)view;
        if (textView.text.length > 0) [foundTexts addObject:textView.text];
    } else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        if (button.titleLabel.text.length > 0) [foundTexts addObject:button.titleLabel.text];
    }

    for (UIView *subview in view.subviews) {
        findTextRecursive(subview, foundTexts);
    }
}


@interface UIViewController (BulldozerExtractor)
- (void)startBulldozerExtractionProcess;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
            NSInteger buttonTag = 170170;
            if ([keyWindow viewWithTag:buttonTag]) [[keyWindow viewWithTag:buttonTag] removeFromSuperview];
            
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(keyWindow.bounds.size.width - 220, keyWindow.bounds.size.height - 70, 200, 50);
            button.tag = buttonTag;
            [button setTitle:@"启动推土机" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:20];
            button.backgroundColor = [UIColor blackColor];
            [button setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
            button.layer.cornerRadius = 10;
            button.layer.borderColor = [UIColor redColor].CGColor;
            button.layer.borderWidth = 2.0;
            [button addTarget:self action:@selector(startBulldozerExtractionProcess) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:button];

            if (!g_bulldozerTextView || !g_bulldozerTextView.superview) {
                g_bulldozerTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 80, keyWindow.bounds.size.width - 20, keyWindow.bounds.size.height - 180)];
                g_bulldozerTextView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
                g_bulldozerTextView.textColor = [UIColor cyanColor];
                g_bulldozerTextView.font = [UIFont fontWithName:@"Menlo" size:12];
                g_bulldozerTextView.editable = NO;
                g_bulldozerTextView.hidden = YES;
                g_bulldozerTextView.layer.cornerRadius = 10;
                g_bulldozerTextView.layer.borderColor = [UIColor cyanColor].CGColor;
                g_bulldozerTextView.layer.borderWidth = 1.0;
                [keyWindow addSubview:g_bulldozerTextView];
            }
        });
    }
}

%new
- (void)startBulldozerExtractionProcess {
    if (g_bulldozerTextView) {
        g_bulldozerTextView.hidden = NO;
        g_bulldozerTextView.text = @"[推土机V17] 已启动...\n";
    }

    LogToBulldozerPanel(@"步骤1: 自动扫描UICollectionView...");
    UICollectionView *ketiView = findCollectionViewInView(self.view);
    
    if (!ketiView) {
        LogToBulldozerPanel(@"【致命错误】: 未能在视图中找到任何UICollectionView！提取终止。");
        return;
    }
    LogToBulldozerPanel(@"成功找到目标: %@", ketiView);

    id<UICollectionViewDelegate> delegate = ketiView.delegate;
    id<UICollectionViewDataSource> dataSource = ketiView.dataSource;

    if (!delegate || !dataSource) {
        LogToBulldozerPanel(@"【致命错误】: 目标没有 delegate 或 dataSource！提取终止。");
        return;
    }
    
    NSInteger itemCount = [dataSource collectionView:ketiView numberOfItemsInSection:0];
    LogToBulldozerPanel(@"发现 %ld 个单元格，准备开始夷平...", (long)itemCount);

    __block __weak void (^weakProcessItemAtIndex)(NSInteger);
    void (^processItemAtIndex)(NSInteger);

    weakProcessItemAtIndex = processItemAtIndex = ^(NSInteger index) {
        __strong void (^strongProcessItemAtIndex)(NSInteger) = weakProcessItemAtIndex;
        if (!strongProcessItemAtIndex) return;

        if (index >= itemCount) {
            LogToBulldozerPanel(@"\n--- 推土机作业完成！---");
            return;
        }

        LogToBulldozerPanel(@"\n---------------------------------");
        LogToBulldozerPanel(@"正在处理第 %ld 个单元格...", (long)index);
        
        UIWindow *window = self.view.window;
        NSSet *viewsBefore = [NSSet setWithArray:window.subviews];

        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
        
        if ([delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
            [delegate collectionView:ketiView didSelectItemAtIndexPath:indexPath];
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            LogToBulldozerPanel(@"-> 步骤2: 全屏快照对比...");
            
            NSSet *viewsAfter = [NSSet setWithArray:window.subviews];
            NSMutableSet *newViews = [NSMutableSet setWithSet:viewsAfter];
            [newViews minusSet:viewsBefore];

            if (newViews.count > 0) {
                UIView *popupView = newViews.anyObject;
                LogToBulldozerPanel(@"-> 步骤3: 成功捕获新视图！(%@)", [popupView class]);
                
                NSMutableArray<NSString *> *foundTexts = [NSMutableArray array];
                findTextRecursive(popupView, foundTexts);
                
                LogToBulldozerPanel(@"-> 提取内容: %@", [foundTexts componentsJoinedByString:@" | "]);

                LogToBulldozerPanel(@"-> 步骤4: 正在移除新视图...");
                [popupView removeFromSuperview];
                
                // 确保presentedViewController也被处理
                if(self.presentedViewController){
                    [self.presentedViewController dismissViewControllerAnimated:NO completion:^{
                        strongProcessItemAtIndex(index + 1);
                    }];
                } else {
                    strongProcessItemAtIndex(index + 1);
                }

            } else {
                LogToBulldozerPanel(@"-> 步骤3: 未发现任何新视图。检查presentedViewController...");
                 if(self.presentedViewController){
                    LogToBulldozerPanel(@"-> 发现 presentedViewController，按标准流程处理...");
                    NSMutableArray<NSString *> *foundTexts = [NSMutableArray array];
                    findTextRecursive(self.presentedViewController.view, foundTexts);
                    LogToBulldozerPanel(@"-> 提取内容: %@", [foundTexts componentsJoinedByString:@" | "]);
                    [self.presentedViewController dismissViewControllerAnimated:NO completion:^{
                        strongProcessItemAtIndex(index + 1);
                    }];
                 } else {
                    LogToBulldozerPanel(@"-> 彻底失败，无法找到任何弹窗。");
                    strongProcessItemAtIndex(index + 1);
                 }
            }
        });
    };

    processItemAtIndex(0);
}

%end
