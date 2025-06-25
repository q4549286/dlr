#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static UITextView *g_finalTextView = nil;

// 日志函数
static void LogToFinalPanel(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[ExtractorV16] %@", message);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_finalTextView) {
            NSString *currentText = g_finalTextView.text;
            g_finalTextView.text = [currentText stringByAppendingFormat:@"%@\n", message];
        }
    });
}

@interface UIViewController (FinalExtractor)
- (void)startFinalExtractionProcess;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger buttonTag = 160160;
            if ([keyWindow viewWithTag:buttonTag]) { [[keyWindow viewWithTag:buttonTag] removeFromSuperview]; }
            
            UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
            extractButton.frame = CGRectMake(keyWindow.bounds.size.width - 200, keyWindow.bounds.size.height - 60, 180, 44);
            extractButton.tag = buttonTag;
            [extractButton setTitle:@"开始终极提取" forState:UIControlStateNormal];
            extractButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
            extractButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
            [extractButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            extractButton.layer.cornerRadius = 8;
            [extractButton addTarget:self action:@selector(startFinalExtractionProcess) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:extractButton];

            // 创建一个用于显示结果的文本视图
            g_finalTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 100, keyWindow.bounds.size.width - 40, keyWindow.bounds.size.height - 200)];
            g_finalTextView.backgroundColor = [UIColor blackColor];
            g_finalTextView.textColor = [UIColor whiteColor];
            g_finalTextView.font = [UIFont fontWithName:@"Menlo" size:14];
            g_finalTextView.editable = NO;
            g_finalTextView.hidden = YES;
            g_finalTextView.layer.cornerRadius = 12;
            [keyWindow addSubview:g_finalTextView];
        });
    }
}

%new
- (void)startFinalExtractionProcess {
    g_finalTextView.hidden = NO;
    g_finalTextView.text = @"终极提取开始...\n";

    UICollectionView *ketiView = [self valueForKey:@"課體視圖"];
    if (!ketiView) {
        LogToFinalPanel(@"错误：找不到 '課體視圖' (UICollectionView)。");
        return;
    }

    id delegate = ketiView.delegate;
    if (!delegate) {
        LogToFinalPanel(@"错误：'課體視圖' 没有代理 (delegate)。");
        return;
    }
    
    NSInteger itemCount = [ketiView.dataSource collectionView:ketiView numberOfItemsInSection:0];
    LogToFinalPanel(@"发现 %ld 个课体单元格，开始遍历...", (long)itemCount);

    // 使用递归函数来处理异步流程
    __block void (^processItemAtIndex)(NSInteger) = ^(NSInteger index) {
        if (index >= itemCount) {
            LogToFinalPanel(@"\n--- 所有课体提取完毕！---");
            return;
        }

        LogToFinalPanel(@"\n---------------------------------");
        LogToFinalPanel(@"正在处理第 %ld 个单元格...", (long)index);
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:index inSection:0];
        
        // 1. 强行调用 delegate 方法
        if ([delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
            LogToFinalPanel(@"-> 步骤1: 强制调用 didSelectItemAtIndexPath:");
            [delegate collectionView:ketiView didSelectItemAtIndexPath:indexPath];
        } else {
             LogToFinalPanel(@"-> 步骤1: 代理不响应 didSelectItemAtIndexPath:");
        }

        // 2. 等待弹窗出现
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            LogToFinalPanel(@"-> 步骤2: 等待0.8秒后，寻找弹窗...");

            UIViewController *presentedVC = self.presentedViewController;
            if (presentedVC) {
                LogToFinalPanel(@"-> 步骤3: 成功找到弹窗！(%@)", [presentedVC class]);
                
                // 3. 在弹窗中寻找文本
                // 假设文本在弹窗的 view 的某个子 UILabel 中，我们递归搜索
                NSMutableArray<NSString *> *foundTexts = [NSMutableArray array];
                void (^findLabelsRecursive)(UIView*) = ^(UIView* view) {
                    if ([view isKindOfClass:[UILabel class]]) {
                        UILabel *label = (UILabel *)view;
                        if (label.text.length > 0) {
                            [foundTexts addObject:label.text];
                        }
                    }
                    for (UIView *subview in view.subviews) {
                        findLabelsRecursive(subview);
                    }
                };
                findLabelsRecursive(presentedVC.view);
                
                LogToFinalPanel(@"-> 提取内容: %@", [foundTexts componentsJoinedByString:@" | "]);

                // 4. 关闭弹窗
                [presentedVC dismissViewControllerAnimated:NO completion:^{
                    LogToFinalPanel(@"-> 步骤4: 关闭弹窗，准备下一个。");
                    processItemAtIndex(index + 1); // 处理下一个
                }];

            } else {
                LogToFinalPanel(@"-> 步骤3: 未找到弹窗。");
                processItemAtIndex(index + 1); // 直接处理下一个
            }
        });
    };

    // 从第一个开始
    processItemAtIndex(0);
}

%end
