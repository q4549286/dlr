#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog(@"[KeChuan-ReadOnly] " format, ##__VA_ARGS__)

static NSInteger const TestButtonTag = 556691; // 新的Tag

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// 这是一个更安全的字符串宏，避免之前的编译问题
#define SafeString(str) (str ?: @"")

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAIReadOnlyAddons)
- (void)performReadOnlyExtraction;
- (NSString *)extractKeChuanInfo_ReadOnly; // 核心提取函数
@end

%hook UIViewController

// --- viewDidLoad 保持不变 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            if ([keyWindow viewWithTag:TestButtonTag]) { [[keyWindow viewWithTag:TestButtonTag] removeFromSuperview]; }
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"测试课传(只读)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemOrangeColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performReadOnlyExtraction) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

%new
- (void)performReadOnlyExtraction {
    NSString *keChuanText = [self extractKeChuanInfo_ReadOnly];
    
    [UIPasteboard generalPasteboard].string = keChuanText;
    
    UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"只读版测试完成" message:keChuanText preferredStyle:UIAlertControllerStyleAlert];
    [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:successAlert animated:YES completion:nil];
}

%new
// --- 核心提取函数，100% 移植并改造自您的原始脚本 ---
- (NSString *)extractKeChuanInfo_ReadOnly {
    NSMutableString *resultString = [NSMutableString string];
    
    // --- Part A: 解析四课 ---
    [resultString appendString:@"【四课】\n"];
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *siKeViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews);
        if (siKeViews.count > 0) {
            UIView *container = siKeViews.firstObject;
            NSMutableArray *labels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], container, labels);
            
            if (labels.count >= 12) {
                NSMutableDictionary *cols = [NSMutableDictionary dictionary];
                for(UILabel *label in labels) {
                    NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))];
                    if(!cols[key]) { cols[key] = [NSMutableArray array]; }
                    [cols[key] addObject:label];
                }
                
                if (cols.allKeys.count == 4) {
                    NSArray *keys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }];
                    // keys[0]是最左边的列(第四课), keys[3]是最右边的列(第一课)
                    
                    // 为了代码清晰，我们按课的顺序处理
                    // 第一课
                    NSMutableArray *c1_labels = cols[keys[3]]; [c1_labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                    NSString *k1s = ((UILabel*)c1_labels[0]).text; NSString *k1t = ((UILabel*)c1_labels[1]).text; NSString *k1d = ((UILabel*)c1_labels[2]).text;
                    [resultString appendFormat:@"第一课: %@上 %@, 为%@\n", SafeString(k1d), SafeString(k1t), SafeString(k1s)];

                    // 第二课
                    NSMutableArray *c2_labels = cols[keys[2]]; [c2_labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                    NSString *k2s = ((UILabel*)c2_labels[0]).text; NSString *k2t = ((UILabel*)c2_labels[1]).text; NSString *k2d = ((UILabel*)c2_labels[2]).text;
                    [resultString appendFormat:@"第二课: %@上 %@, 为%@\n", SafeString(k2d), SafeString(k2t), SafeString(k2s)];

                    // 第三课
                    NSMutableArray *c3_labels = cols[keys[1]]; [c3_labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                    NSString *k3s = ((UILabel*)c3_labels[0]).text; NSString *k3t = ((UILabel*)c3_labels[1]).text; NSString *k3d = ((UILabel*)c3_labels[2]).text;
                    [resultString appendFormat:@"第三课: %@上 %@, 为%@\n", SafeString(k3d), SafeString(k3t), SafeString(k3s)];

                    // 第四课
                    NSMutableArray *c4_labels = cols[keys[0]]; [c4_labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                    NSString *k4s = ((UILabel*)c4_labels[0]).text; NSString *k4t = ((UILabel*)c4_labels[1]).text; NSString *k4d = ((UILabel*)c4_labels[2]).text;
                    [resultString appendFormat:@"第四课: %@上 %@, 为%@\n", SafeString(k4d), SafeString(k4t), SafeString(k4s)];
                }
            }
        }
    }
    
    [resultString appendString:@"\n【三传】\n"];
    // --- Part B: 解析三传 ---
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanViewClass) {
        NSMutableArray *scViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews);
        // 严格按Y坐标排序，确保是初、中、末的顺序
        [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        
        NSArray *titles = @[@"初传", @"中传", @"末传"];
        for (NSUInteger i = 0; i < scViews.count; i++) {
            if (i >= titles.count) break;
            
            UIView *v = scViews[i];
            NSMutableArray *labels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], v, labels);
            [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            
            if (labels.count >= 2) {
                NSString *lq = ((UILabel*)labels.firstObject).text;
                NSString *dz = ((UILabel*)[labels objectAtIndex:labels.count - 2]).text;
                NSString *tj = ((UILabel*)[labels lastObject]).text;
                
                // 提取神煞（可选，但您的原始脚本有这个逻辑）
                NSMutableString *shenSha = [NSMutableString string];
                if (labels.count > 3) {
                    for (NSUInteger j = 1; j < labels.count - 2; j++) {
                        [shenSha appendFormat:@"%@ ", ((UILabel*)labels[j]).text];
                    }
                }

                [resultString appendFormat:@"%@: %@ %@ %@ (%@)\n", titles[i], SafeString(lq), SafeString(dz), [shenSha stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]], SafeString(tj)];
            }
        }
    }
    
    return [resultString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

%end
