#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 独立测试版 (V20 - 表格数据源探测)
// 目标: 探测格局、毕法、方法弹窗的数据源
// =========================================================================

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test] " format), ##__VA_ARGS__)

// 辅助函数
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) {
    if (!object || !ivarNameSuffix) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) { free(ivars); return nil; }
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

// 简繁转换钩子
%hook UILabel
- (void)setText:(NSString *)text { 
    if (!text) { %orig(text); return; }
    NSMutableString *simplifiedText = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, kCFStringTransformMandarinLatin, NO);
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, kCFStringTransformStripDiacritics, NO);
    %orig(simplifiedText);
}
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) { %orig(attributedText); return; }
    NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, kCFStringTransformMandarinLatin, NO);
    CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, kCFStringTransformStripDiacritics, NO);
    %orig(finalAttributedText);
}
%end


%hook UIViewController

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    
    // 我们只关心这个特定的ViewController
    Class targetClass = NSClassFromString(@"六壬大占.格局总览视图");
    if (targetClass && [viewControllerToPresent isKindOfClass:targetClass]) {
        
        // 阻止原弹窗显示
        flag = NO;
        
        // 延迟执行，确保VC内部数据已加载
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            NSMutableString *logOutput = [NSMutableString string];
            [logOutput appendFormat:@"探测目标: %@\n\n", NSStringFromClass([viewControllerToPresent class])];

            // 探测 '格局列', '法诀列', '方法列'
            NSArray *ivarNames = @[@"格局列", @"法诀列", @"方法列"];
            BOOL foundData = NO;

            for (NSString *ivarName in ivarNames) {
                [logOutput appendFormat:@"正在探测 '%@'...\n", ivarName];
                id dataArray = GetIvarValueSafely(viewControllerToPresent, ivarName);

                if (dataArray) {
                    foundData = YES;
                    [logOutput appendFormat:@"成功! 类型: %@, 数量: %ld\n", NSStringFromClass([dataArray class]), (long)([(id)dataArray count] ?: 0)];
                    
                    if ([dataArray isKindOfClass:[NSArray class]] && [(NSArray *)dataArray count] > 0) {
                        id firstObject = [(NSArray *)dataArray firstObject];
                        [logOutput appendFormat:@"数组第一个元素的类型: %@\n", NSStringFromClass([firstObject class])];
                        
                        // 尝试打印第一个元素的内容
                        if ([firstObject isKindOfClass:[NSObject class]]) {
                             [logOutput appendFormat:@"内容: %@\n", [firstObject description]];
                        }
                    }
                    [logOutput appendString:@"\n"];
                } else {
                    [logOutput appendString:@"失败: 未找到或为nil。\n\n"];
                }
            }

            if (!foundData) {
                [logOutput setString:@"所有已知的数据源变量(格局列, 法诀列, 方法列)都未找到。"];
            }

            // 弹出探测日志
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"数据源探测日志" message:logOutput preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                // 手动关闭被我们拦截的VC
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            }]];
            // 在主VC上弹出我们的日志窗口
            [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        });

        // 调用空的completion，因为我们自己处理了所有事情
        if (completion) {
            completion();
        }
        return;
    }
    
    %orig(viewControllerToPresent, flag, completion);
}

%end
