#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 最终提取代码 (V8 - 字典解析版)
// =========================================================================

#define EchoLog(format, ...) NSLog((@"[EchoAI] " format), ##__VA_ARGS__)

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

// 新增辅助函数：从字典中提取文字数组
static NSArray<NSString *> *ExtractStringsFromDictionary(NSDictionary *dict) {
    if (!dict || ![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    // Swift的字典在OC中可能需要特殊处理，我们先尝试标准的 allValues
    NSArray *layers = [dict allValues];
    if (layers.count == 0) return nil;

    NSMutableArray<NSString *> *strings = [NSMutableArray array];
    for (id layer in layers) {
        // 每个值是一个 CATextLayer，我们读取它的 string 属性
        if ([layer respondsToSelector:@selector(string)]) {
            id stringValue = [layer valueForKey:@"string"];
            if ([stringValue isKindOfClass:[NSString class]]) {
                [strings addObject:stringValue];
            } else if ([stringValue isKindOfClass:[NSAttributedString class]]) {
                [strings addObject:((NSAttributedString *)stringValue).string];
            }
        }
    }
    // 我们无法保证字典的值是按顺序的，所以这里先不排序，后续可能需要根据key排序
    return [strings copy];
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
            [testButton setTitle:@"提取天地盤" forState:UIControlStateNormal]; // 改名
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

        // 2. 获取字典对象
        NSDictionary *diGongDict = GetIvarValueSafely(plateView, @"地宮宮名列");
        NSDictionary *tianShenDict = GetIvarValueSafely(plateView, @"天神宮名列");
        NSDictionary *tianJiangDict = GetIvarValueSafely(plateView, @"天將宮名列");

        // 3. 从字典中提取文字数组
        NSArray<NSString *> *diGong = ExtractStringsFromDictionary(diGongDict);
        NSArray<NSString *> *tianShen = ExtractStringsFromDictionary(tianShenDict);
        NSArray<NSString *> *tianJiang = ExtractStringsFromDictionary(tianJiangDict);

        // 4. 检查数据
        if (!diGong || !tianShen || !tianJiang || diGong.count != 12 || tianShen.count != 12 || tianJiang.count != 12) {
             // ... 失败处理 ...
             return;
        }

        // 5. 格式化输出 (成功！)
        NSMutableString *resultText = [NSMutableString string];
        [resultText appendString:@"天地盤數據提取成功！\n\n"];
        // 由于字典无序，输出可能不是按子丑寅卯...，但数据是全的
        for (int i = 0; i < 12; i++) {
             // 暂时按数组默认顺序输出
             [resultText appendFormat:@"%@ - %@ - %@\n", diGong[i], tianShen[i], tianJiang[i]];
        }
        
        // 最终的排序方案可能需要分析字典的key，但目前先验证数据提取
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"成功！" message:resultText preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

    } @catch (NSException *exception) {
        // ...
    }
}

%end
