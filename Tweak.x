#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 告诉编译器，我们接下来要Hook的ViewController，它其实是一个UIViewController
@interface ViewController : UIViewController
@end

// --- 我们只Hook主控制器 ---
%hook ViewController

// 在视图完全显示后执行我们的代码
- (void)viewDidAppear:(BOOL)animated {
    // 先调用原始实现，这是好习惯
    %orig;

    // 防止重复执行
    if (objc_getAssociatedObject(self, "hasExportedForTest")) {
        return;
    }
    
    // --- 1. 定义我们要找的UILabel的精确位置 ---
    CGRect chartTypeFrame = CGRectMake(60, 5, 100, 40); 

    // --- 2. 存储找到的文本 ---
    __block NSString *chartTypeText = nil;

    // --- 3. 遍历视图，寻找目标UILabel ---
    // --- 新增的修复代码 ---
    // 使用 __block 来解决Block递归调用时自身为nil的问题
    __block void (^findLabelInView)(UIView *) = ^(UIView *view) {
    // --- 修复代码结束 ---
        // 如果已经找到了，就没必要继续了
        if (chartTypeText) return;

        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            
            CGRect frameInWindow = [label.superview convertRect:label.frame toView:nil];
            CGPoint centerInWindow = CGPointMake(CGRectGetMidX(frameInWindow), CGRectGetMidY(frameInWindow));
            
            if (CGRectContainsPoint(chartTypeFrame, centerInWindow)) {
                chartTypeText = label.text;
            }
        }
        
        // 递归进入子视图
        for (UIView *subview in view.subviews) {
            findLabelInView(subview);
        }
    };
    
    // 从控制器的主视图开始遍历
    findLabelInView(self.view);

    // --- 4. 检查结果并复制到剪贴板 ---
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

%end
