#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-V6-FINAL] " format), ##__VA_ARGS__)

// =========================================================================
//  Hook UIViewController
// =========================================================================
%hook UIViewController

// -------------------------------------------------------------------------
// 1. 在主界面添加一个测试按钮 (无变化)
// -------------------------------------------------------------------------
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        if ([self.view.window viewWithTag:45678]) return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(10, 45, 120, 36);
            testButton.tag = 45678;
            [testButton setTitle:@"直取格局(V6)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor systemIndigoColor]; // 换个颜色以示区别
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(testGeJuExtractionTapped_V6) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}


// -------------------------------------------------------------------------
// 2. 【全新】按钮点击事件，直接提取，无需任何hook
// -------------------------------------------------------------------------
%new
- (void)testGeJuExtractionTapped_V6 {
    EchoLog(@"--- V6: 开始直接从 self 提取 ---");

    // 数据源很可能就在self(主VC)上，而不是在弹出的VC上
    // 我们尝试直接调用主VC上的getter
    SEL getterSelector = NSSelectorFromString(@"格局列");
    NSString *titleKey = @"標題";
    NSString *detailKey = @"解";
    NSString *resultText = @"";

    if ([self respondsToSelector:getterSelector]) {
        EchoLog(@"self 响应 getter '%@'，准备调用...", NSStringFromSelector(getterSelector));
        
        id dataSource = nil;
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        dataSource = [self performSelector:getterSelector];
        #pragma clang diagnostic pop
        
        EchoLog(@"直接从 self 调用 Getter，返回的数据: %@", dataSource);

        if (dataSource && [dataSource isKindOfClass:[NSArray class]]) {
            NSMutableArray *textParts = [NSMutableArray array];
            for (id item in (NSArray *)dataSource) {
                NSString *title = [item valueForKey:titleKey] ?: @"";
                NSString *detail = [item valueForKey:detailKey] ?: @"";
                if (title.length > 0 || detail.length > 0) {
                    [textParts addObject:[NSString stringWithFormat:@"%@: %@", title, detail]];
                }
            }
            if (textParts.count > 0) {
                resultText = [textParts componentsJoinedByString:@"\n"];
                EchoLog(@"[V6] 直接提取成功! 共 %lu 条格局。", (unsigned long)textParts.count);
            } else {
                resultText = @"直接提取成功，但数据源为空。";
            }
        } else {
            resultText = [NSString stringWithFormat:@"直接提取失败。Getter '%@' 返回的值不是有效的NSArray或为nil。实际值: %@", NSStringFromSelector(getterSelector), dataSource];
        }

    } else {
        resultText = @"直接提取失败: self (主VC) 不响应 '格局列' getter方法。";
        EchoLog(@"%@", resultText);
    }
    
    // 显示结果
    [UIPasteboard generalPasteboard].string = resultText;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"格局直接提取(V6)结果"
                                                                   message:resultText
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}


// -------------------------------------------------------------------------
// 3. 我们不再需要 hook presentViewController 了！
// -------------------------------------------------------------------------
// %hook presentViewController ...  // 全部删除或注释掉

%end
