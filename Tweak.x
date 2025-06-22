#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 极简独立测试版 (V9 - 排序修正版)
// 目标: 修复数据配对和排序问题
// =========================================================================

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test] " format), ##__VA_ARGS__)

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
    @try {
        // 1. 查找视图
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類");
        if (!plateViewClass) return;
        
        UIWindow *keyWindow = self.view.window;
        if (!keyWindow) return;

        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
        if (plateViews.count == 0) return;
        
        id plateView = plateViews.firstObject;

        // 2. 获取三个核心字典
        NSDictionary *diGongDict = GetIvarValueSafely(plateView, @"地宮宮名列");
        NSDictionary *tianShenDict = GetIvarValueSafely(plateView, @"天神宮名列");
        NSDictionary *tianJiangDict = GetIvarValueSafely(plateView, @"天將宮名列");

        // 3. 检查字典有效性
        if (!diGongDict || !tianShenDict || !tianJiangDict ||
            ![diGongDict isKindOfClass:[NSDictionary class]] ||
            ![tianShenDict isKindOfClass:[NSDictionary class]] ||
            ![tianJiangDict isKindOfClass:[NSDictionary class]] ||
            diGongDict.count != 12) {
             // ... 失败处理 ...
             return;
        }

        // 4. 遍历地宫字典，用它的key去匹配其他字典，并组合数据
        NSMutableArray *palaceData = [NSMutableArray array];
        [diGongDict enumerateKeysAndObjectsUsingBlock:^(id key, id diGongLayer, BOOL *stop) {
            id tianShenLayer = tianShenDict[key];
            id tianJiangLayer = tianJiangDict[key];
            
            // 安全地从 layer 中提取 string
            NSString *diGongStr = @"?";
            NSString *tianShenStr = @"?";
            NSString *tianJiangStr = @"??";

            if ([diGongLayer respondsToSelector:@selector(string)]) {
                diGongStr = [diGongLayer valueForKey:@"string"];
            }
            if ([tianShenLayer respondsToSelector:@selector(string)]) {
                tianShenStr = [tianShenLayer valueForKey:@"string"];
            }
            if ([tianJiangLayer respondsToSelector:@selector(string)]) {
                tianJiangStr = [tianJiangLayer valueForKey:@"string"];
            }
            
            // 将配对好的数据存入字典
            NSDictionary *entry = @{
                @"diPan": diGongStr,
                @"tianPan": tianShenStr,
                @"tianJiang": tianJiangStr
            };
            [palaceData addObject:entry];
        }];
        
        // 5. 按地盘（子丑寅卯...）顺序进行排序
        NSArray *diPanOrder = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"];
        [palaceData sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            NSString *diPan1 = obj1[@"diPan"];
            NSString *diPan2 = obj2[@"diPan"];
            NSUInteger index1 = [diPanOrder indexOfObject:diPan1];
            NSUInteger index2 = [diPanOrder indexOfObject:diPan2];
            return [@(index1) compare:@(index2)];
        }];

        // 6. 格式化最终输出
        NSMutableString *resultText = [NSMutableString string];
        [resultText appendString:@"天地盤數據提取成功！(已排序)\n\n"];
        for (NSDictionary *entry in palaceData) {
            [resultText appendFormat:@"%@宮: %@(%@)\n", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]];
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"成功！" message:resultText preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

    } @catch (NSException *exception) {
        // ... 异常捕获代码 ...
    }
}

%end
