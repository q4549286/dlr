#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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
    
    // --- 1. 定义我们要找的UILabel的大概位置 ---
    //    这里的坐标需要你用FLEX测量并替换！
    //    我根据之前的截图，填入一个示例值
    CGRect chartTypeFrame = CGRectMake(60, 5, 100, 40); // “返吟门”的大概位置

    // --- 2. 存储找到的文本 ---
    __block NSString *chartTypeText = nil;

    // --- 3. 遍历视图，寻找目标UILabel ---
    //    这是一个简化的内联遍历逻辑
    void (^findLabel)(UIView *) = ^(UIView *view) {
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            CGRect frameInWindow = [label.superview convertRect:label.frame toView:nil];
            CGPoint centerInWindow = CGPointMake(CGRectGetMidX(frameInWindow), CGRectGetMidY(frameInWindow));
            
            // 检查Label的中心点是否在我们定义的区域内
            if (CGRectContainsPoint(chartTypeFrame, centerInWindow)) {
                chartTypeText = label.text;
            }
        }
        for (UIView *subview in view.subviews) {
            // 递归查找
            // findLabel(subview); // 这里先不递归，因为目标UILabel可能就在顶层
        }
    };
    
    // 从控制器的主视图开始遍历所有子视图
    for (UIView *subview in self.view.subviews) {
        // 如果找到了就没必要继续了
        if(chartTypeText) break;
        
        // 这是一个更简单的遍历，只检查第一层子视图里的UILabel
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            CGRect frameInWindow = [label.superview convertRect:label.frame toView:nil];
            CGPoint centerInWindow = CGPointMake(CGRectGetMidX(frameInWindow), CGRectGetMidY(frameInWindow));

            if (CGRectContainsPoint(chartTypeFrame, centerInWindow)) {
                chartTypeText = label.text;
                break; // 找到就跳出循环
            }
        }
    }


    // --- 4. 检查结果并复制到剪贴板 ---
    if (chartTypeText) {
        // 假设“课格名称”和“起课方式”是同一个东西，或者我们需要组合
        // 我们这里就直接用找到的文本
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
        NSLog(@"[测试插件] 未能在指定区域找到UILabel。请检查坐标定义是否正确。");
    }
}

%end
