#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 告诉编译器，我们接下来要Hook的ViewController，它其实是一个UIViewController
@interface ViewController : UIViewController
// 我们把递归函数声明为一个私有辅助方法
- (void)findLabelInView:(UIView *)view withTargetFrame:(CGRect)targetFrame foundText:(__strong NSString **)foundText;
@end

// --- 我们只Hook主控制器 ---
%hook ViewController

// 在视图完全显示后执行我们的代码
- (void)viewDidAppear:(BOOL)animated {
    // 先调用原始实现
    %orig;

    if (objc_getAssociatedObject(self, "hasExportedForTest")) {
        return;
    }
    
    // 1. 定义目标区域
    CGRect chartTypeFrame = CGRectMake(60, 5, 100, 40); 

    // 2. 准备一个变量来接收结果
    NSString *chartTypeText = nil;

    // 3. 调用我们的辅助方法来查找
    [self findLabelInView:self.view withTargetFrame:chartTypeFrame foundText:&chartTypeText];

    // 4. 检查结果并复制到剪贴板
    if (chartTypeText) {
        NSString *resultText = [NSString stringWithFormat:@"课格名称/起课方式: %@", chartTypeText];

        [[UIPasteboard generalPasteboard] setString:resultText];
        
        NSLog(@"[测试插件] 成功提取: %@", resultText);
        NSLog(@"[测试插件] 已复制到剪贴板!");

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试成功" 
                                                                         message:[NSString stringWithFormat:@"已复制内容:\n%@", resultText]
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        
        objc_setAssociatedObject(self, "hasExportedForTest", @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    } else {
        NSLog(@"[测试插件] 未能在指定区域找到UILabel。请检查坐标定义或视图层级。");

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试失败" 
                                                                         message:@"未能在指定区域找到目标文字，请检查插件代码中的坐标定义。"
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

// --- 新增的辅助方法实现 ---
// 这个方法不属于Hook的一部分，而是我们给ViewController类新增的一个方法
// 所以它要放在 %hook 和 %end 的外面
%new
// 这是一个私有方法，专门用来递归遍历视图
- (void)findLabelInView:(UIView *)view withTargetFrame:(CGRect)targetFrame foundText:(__strong NSString **)foundText {
    // 如果已经找到了，就没必要继续了
    if (*foundText) return;

    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        
        CGRect frameInWindow = [label.superview convertRect:label.frame toView:nil];
        CGPoint centerInWindow = CGPointMake(CGRectGetMidX(frameInWindow), CGRectGetMidY(frameInWindow));
        
        if (CGRectContainsPoint(targetFrame, centerInWindow)) {
            // 通过指针的指针，修改外部变量的值
            *foundText = label.text;
            return; // 找到就返回
        }
    }
    
    // 递归进入子视图
    for (UIView *subview in view.subviews) {
        [self findLabelInView:subview withTargetFrame:targetFrame foundText:foundText];
    }
}

%end
