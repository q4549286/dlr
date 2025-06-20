#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// --- 新增的修复代码 ---
// 告诉编译器，我们接下来要Hook的ViewController，它其实是一个UIViewController
// 这样编译器就知道它有 .view 和 presentViewController: 等属性和方法了
@interface ViewController : UIViewController
@end
// --- 修复代码结束 ---


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
    //    坐标来源于您的截图: frame = {{61.9145, 6.80999}, {98.3333, 39}}
    //    为了保险，我们稍微扩大一点范围
    CGRect chartTypeFrame = CGRectMake(60, 5, 100, 40); 

    // --- 2. 存储找到的文本 ---
    __block NSString *chartTypeText = nil;

    // --- 3. 遍历视图，寻找目标UILabel ---
    //    这是一个递归函数，可以找到所有层级的UILabel
    void (^findLabelInView)(UIView *) = ^(UIView *view) {
        // 如果已经找到了，就没必要继续了
        if (chartTypeText) return;

        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            
            // 获取Label在整个屏幕上的绝对坐标
            CGRect frameInWindow = [label.superview convertRect:label.frame toView:nil];
            
            // 计算Label的中心点
            CGPoint centerInWindow = CGPointMake(CGRectGetMidX(frameInWindow), CGRectGetMidY(frameInWindow));
            
            // 检查Label的中心点是否在我们定义的区域内
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

        // 复制到剪贴板
        [[UIPasteboard generalPasteboard] setString:resultText];
        
        NSLog(@"[测试插件] 成功提取: %@", resultText);
        NSLog(@"[测试插件] 已复制到剪贴板!");

        // 弹窗提示
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试成功" 
                                                                         message:[NSString stringWithFormat:@"已复制内容:\n%@", resultText]
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        
        // 标记已执行
        objc_setAssociatedObject(self, "hasExportedForTest", @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    } else {
        NSLog(@"[测试插件] 未能在指定区域找到UILabel。请检查坐标定义或视图层级。");
        // 如果没有找到，也弹窗提示，方便调试
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试失败" 
                                                                         message:@"未能在指定区域找到目标文字，请检查插件代码中的坐标定义。"
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

%end
