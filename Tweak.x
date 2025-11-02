// =========================================================================
// V18 - 坐标侦察兵模式
// =========================================================================

// 原来的 %hook UIViewController ... %end 可以先整个注释掉

// 新增一个专门用于侦察的 Hook
%hook 六壬大占_ViewController 
// 注意：如果 FLEX 显示 Target-Action 的 target 是 ViewController，就用这个类名
// 如果是天地盘视图自己处理，就用 '六壬大占.天地盤視圖類'

// Hook 目标 Action 方法
- (void)顯示天地盤觸摸WithSender:(UIGestureRecognizer *)sender {
    // 先调用原始方法，确保功能正常
    %orig;

    // 获取当前点击在“天地盘”视图中的精确坐标
    // 我们假设 self.view 就是或者包含了那个“天地盘视图”
    // 如果不是，需要先找到那个视图实例
    NSString *plateViewClassName = @"六壬大占.天地盤視圖類";
    Class plateViewClass = NSClassFromString(plateViewClassName);
    NSMutableArray *plateViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);

    if (plateViews.count > 0) {
        UIView *plateView = plateViews.firstObject;
        CGPoint location = [sender locationInView:plateView];
        
        // 在Xcode控制台或者手机的系统日志中打印这个坐标
        // 使用 NSLog 是为了确保它能被看到
        NSLog(@"[Echo-Scout] 手动点击坐标: @{@\"point\": [NSValue valueWithCGPoint:CGPointMake(%.2f, %.2f)]}", location.x, location.y);
    }
}
%end

%ctor {
    // 构造函数现在什么都不用做，只是为了让logos能编译
    NSLog(@"[Echo-Scout] 坐标侦察兵已部署。");
}
