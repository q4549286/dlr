// =========================================================================
// V18 - 坐标侦察兵模式 (正确结构)
// =========================================================================

// 确保你已经 import 了必要的头文件
#import <UIKit/UIKit.h>
#import <substrate.h>

// 辅助函数可以放在这里
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if (!view || !storage) return; if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }


// 关键在这里！方法必须在 %hook 块内部
%hook 六壬大占_ViewController 

- (void)顯示天地盤觸摸WithSender:(UIGestureRecognizer *)sender {
    // 1. 先调用原始实现，让App正常弹出窗口
    %orig;

    // 2. 在原始实现之后，我们再获取坐标并打印
    NSString *plateViewClassName = @"六壬大占.天地盤視圖類";
    Class plateViewClass = NSClassFromString(plateViewClassName);
    if (!plateViewClass) {
        NSLog(@"[Echo-Scout] 错误: 找不到类 %@", plateViewClassName);
        return;
    }

    NSMutableArray *plateViews = [NSMutableArray array];
    // 这里要注意 self.view 可能是 ViewController 的 view，要从中找到天地盘视图
    FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);

    if (plateViews.count > 0) {
        UIView *plateView = plateViews.firstObject;
        CGPoint location = [sender locationInView:plateView];
        
        // 使用 NSLog 打印，方便在电脑端控制台查看
        NSLog(@"[Echo-Scout] 点击坐标: @{@\"name\": @\"新坐标\", @\"type\": @\"shangShen\", @\"point\": [NSValue valueWithCGPoint:CGPointMake(%.2f, %.2f)]},", location.x, location.y);
    } else {
        NSLog(@"[Echo-Scout] 错误: 在视图层级中找不到 %@", plateViewClassName);
    }
}

%end


%ctor {
    // 构造函数
    NSLog(@"[Echo-Scout] 坐标侦察兵已部署。请手动点击天地盘并查看日志。");
}
