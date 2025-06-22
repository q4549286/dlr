#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 最终解决方案 (V15 - 整合推断版)
// =========================================================================

#define EchoLog(format, ...) NSLog((@"[EchoAI-Final] " format), ##__VA_ARGS__)

// ... (辅助函数 FindSubviewsOfClassRecursive 和 GetIvarValueSafely 保持不变) ...
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) {
    if (!object || !ivarNameSuffix) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) return nil;
    id value = nil;
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name) {
            NSString *ivarName = [NSString stringWithUTF8String:name];
            if ([ivarName hasSuffix:ivarNameSuffix]) {
                ptrdiff_t offset = ivar_getOffset(ivar);
                void **ivar_ptr = (void **)((__bridge void *)object + offset);
                value = (__bridge id)(*ivar_ptr);
                break;
            }
        }
    }
    free(ivars);
    return value;
}

// 核心提取函数
static NSString *ExtractTianDiPanInfo(id viewController) {
    @try {
        // 1. 查找视图
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類");
        if (!plateViewClass) return @"错误: 找不到天地盘视图类。";
        
        UIWindow *keyWindow = [viewController view].window;
        if (!keyWindow) return @"错误: 找不到keyWindow。";

        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
        if (plateViews.count == 0) return @"错误: 找不到天地盘视图实例。";
        
        id plateView = plateViews.firstObject;

        // 2. 获取 '課盤被動更新器' 对象
        id updater = GetIvarValueSafely(plateView, @"課盤被動更新器");
        if (!updater) return @"错误: 找不到'課盤被動更新器'对象。";

        // 3. 从 '更新器' 对象中获取三个核心字典
        NSDictionary *diGongDict = GetIvarValueSafely(updater, @"地宮宮名列");
        NSDictionary *tianShenDict = GetIvarValueSafely(updater, @"天神宮名列");
        NSDictionary *tianJiangDict = GetIvarValueSafely(updater, @"天將宮名列");

        if (!diGongDict || !tianShenDict || !tianJiangDict ||
            ![diGongDict isKindOfClass:[NSDictionary class]] || diGongDict.count != 12) {
             return @"错误: 从更新器获取字典数据失败。";
        }

        // 4. 安全地获取所有 CATextLayer 的值
        NSArray *diGongLayers = [diGongDict allValues];
        NSArray *tianShenLayers = [tianShenDict allValues];
        NSArray *tianJiangLayers = [tianJiangDict allValues];

        if (diGongLayers.count != 12 || tianShenLayers.count != 12 || tianJiangLayers.count != 12) {
            return @"错误: 字典值数组长度不匹配。";
        }
        
        // 5. 强制平行匹配并提取字符串
        NSMutableArray *palaceData = [NSMutableArray array];
        for (NSUInteger i = 0; i < 12; i++) {
            NSString *diGongStr = [[[diGongLayers objectAtIndex:i] valueForKey:@"string"] description] ?: @"?";
            NSString *tianShenStr = [[[tianShenLayers objectAtIndex:i] valueForKey:@"string"] description] ?: @"?";
            NSString *tianJiangStr = [[[tianJiangLayers objectAtIndex:i] valueForKey:@"string"] description] ?: @"??";

            NSDictionary *entry = @{
                @"diPan": diGongStr,
                @"tianPan": tianShenStr,
                @"tianJiang": tianJiangStr
            };
            [palaceData addObject:entry];
        }

        // 6. 按地盘（子丑寅卯...）顺序进行排序
        NSArray *diPanOrder = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"];
        [palaceData sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            NSString *diPan1 = obj1[@"diPan"];
            NSString *diPan2 = obj2[@"diPan"];
            NSUInteger index1 = [diPanOrder indexOfObject:diPan1];
            NSUInteger index2 = [diPanOrder indexOfObject:diPan2];
            return [@(index1) compare:@(index2)];
        }];

        // 7. 格式化输出
        NSMutableString *resultText = [NSMutableString stringWithString:@"天地盘:\n"];
        for (NSDictionary *entry in palaceData) {
            [resultText appendFormat:@"%@宫: %@(%@)\n", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]];
        }
        return resultText;

    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"捕获到异常: %@", exception.reason];
    }
}


@interface UIViewController (FinalTweak)
- (void)runFinalExtraction;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            [[keyWindow viewWithTag:12345] removeFromSuperview];
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.tag = 12345;
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 120, 45, 110, 36);
            [testButton setTitle:@"提取天地盤" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(runFinalExtraction) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
            [keyWindow bringSubviewToFront:testButton];
        });
    }
}

%new
- (void)runFinalExtraction {
    NSString *result = ExtractTianDiPanInfo(self);
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取结果" message:result preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
