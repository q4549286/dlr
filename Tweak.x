#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 核心 Hook
// =========================================================================
static void (*Original_ViewController_didSelectItem)(id, SEL, id, id);

static void Tweak_ViewController_didSelectItem(id self, SEL _cmd, UICollectionView *collectionView, NSIndexPath *indexPath) {
    NSLog(@"[IndexPath侦察兵] ==================== Delegate 方法被调用 ====================");
    NSLog(@"[IndexPath侦察兵] CollectionView: <%@: %p>", NSStringFromClass([collectionView class]), collectionView);
    NSLog(@"[IndexPath侦察兵] IndexPath: [Section: %ld, Item: %ld]", (long)indexPath.section, (long)indexPath.item);
    
    // 我们可以尝试获取 cell 里的内容，来判断点击了什么
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    if (cell) {
        NSMutableArray *labels = [NSMutableArray array];
        // 简单的递归查找 UILabel
        void (^findLabels)(UIView *) = ^(UIView *view) {
            if ([view isKindOfClass:[UILabel class]]) {
                [labels addObject:((UILabel *)view).text];
            }
            for (UIView *subview in view.subviews) {
                findLabels(subview);
            }
        };
        findLabels(cell.contentView);
        NSLog(@"[IndexPath侦察兵] Cell 内容: %@", [labels componentsJoinedByString:@" | "]);
    } else {
        NSLog(@"[IndexPath侦察兵] Cell 内容: (无法获取，可能不可见)");
    }
    
    NSLog(@"[IndexPath侦察兵] =========================================================");

    // 调用原始方法
    Original_ViewController_didSelectItem(self, _cmd, collectionView, indexPath);
}


%ctor {
    @autoreleasepool {
        Class vcClass = NSClassFromString(@"六壬大占.ViewController");
        if (vcClass) {
             SEL originalSelector = @selector(collectionView:didSelectItemAtIndexPath:);
             MSHookMessageEx(vcClass, originalSelector, (IMP)Tweak_ViewController_didSelectItem, (IMP *)&Original_ViewController_didSelectItem);
             NSLog(@"[IndexPath侦察兵] 已加载。请手动点击课体或天地盘。");
        } else {
             NSLog(@"[IndexPath侦察兵] 错误: 找不到 ViewController 类。");
        }
    }
}
