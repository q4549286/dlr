#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog(@"[KeChuan-ReadOnly-Enhanced] " format, ##__VA_ARGS__)

static NSInteger const TestButtonTag = 556696; // 新的Tag

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// 这是一个更安全的字符串宏
#define SafeString(str) (str ?: @"")

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAIReadOnlyEnhancedAddons)
- (void)performReadOnlyEnhancedExtraction;
- (NSString *)extractKeChuanInfo_ReadOnlyEnhanced;
@end

%hook UIViewController

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
            [testButton setTitle:@"提取课传(只读增强)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemGreenColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performReadOnlyEnhancedExtraction) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

%new
- (void)performReadOnlyEnhancedExtraction {
    NSString *keChuanText = [self extractKeChuanInfo_ReadOnlyEnhanced];
    
    [UIPasteboard generalPasteboard].string = keChuanText;
    
    // 创建一个 UITextView 来显示格式化的文本，这样更容易阅读
    UIViewController *resultVC = [[UIViewController alloc] init];
    resultVC.view.backgroundColor = [UIColor whiteColor];
    
    UITextView *textView = [[UITextView alloc] initWithFrame:resultVC.view.bounds];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    textView.font = [UIFont systemFontOfSize:16];
    textView.editable = NO;
    textView.text = keChuanText;
    [resultVC.view addSubview:textView];
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:resultVC];
    resultVC.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" style:UIBarButtonItemStyleDone target:nav action:@selector(dismissViewControllerAnimated:completion:)];
    resultVC.title = @"课传信息";
    
    [self presentViewController:nav animated:YES completion:nil];
}

%new
- (NSString *)extractKeChuanInfo_ReadOnlyEnhanced {
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
                    
                    NSArray *colKeys = @[keys[3], keys[2], keys[1], keys[0]];
                    NSArray *colTitles = @[@"第一课", @"第二课", @"第三课", @"第四课"];
                
                    for (NSUInteger i = 0; i < colKeys.count; i++) {
                        NSMutableArray *colLabels = cols[colKeys[i]];
                        [colLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                        NSString *tianjiang = SafeString(((UILabel*)colLabels[0]).text);
                        NSString *dizhi = SafeString(((UILabel*)colLabels[1]).text);
                        NSString *ganzhi = SafeString(((UILabel*)colLabels[2]).text);
                        [resultString appendFormat:@"%@: %@上%@, 为%@\n", colTitles[i], ganzhi, dizhi, tianjiang];
                    }
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
        [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        
        NSArray *titles = @[@"初传", @"中传", @"末传"];
        for (NSUInteger i = 0; i < scViews.count; i++) {
            if (i >= titles.count) break;
            
            UIView *v = scViews[i];
            NSMutableArray *labels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], v, labels);
            [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            
            if (labels.count >= 2) {
                NSString *lq = SafeString(((UILabel*)labels.firstObject).text);
                NSString *dz = SafeString(((UILabel*)[labels objectAtIndex:labels.count - 2]).text);
                NSString *tj = SafeString(((UILabel*)[labels lastObject]).text);
                
                NSMutableString *shenSha = [NSMutableString string];
                if (labels.count > 3) {
                    for (NSUInteger j = 1; j < labels.count - 2; j++) {
                        [shenSha appendFormat:@"%@ ", ((UILabel*)labels[j]).text];
                    }
                }
                
                [resultString appendFormat:@"%@: %@ %@ %@(%@)\n", titles[i], lq, dz, [shenSha stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]], tj];
            }
        }
    }
    
    return [resultString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

%end
