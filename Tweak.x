#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量、常量定义
// =========================================================================

// 上下文感知提取的核心全局变量
static NSString *g_currentExtractionContext = nil;
static void (^g_genericCompletionHandler)(NSString *result) = nil;


#define SUPPRESS_LEAK_WARNING(code) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    code; \
    _Pragma("clang diagnostic pop")

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}


// =========================================================================
// 2. 核心 Hook
// =========================================================================

@interface UIViewController (EchoContextAwareEngine)
- (void)extractSharedPopupWithContext:(NSString *)context 
                         selectorName:(NSString *)selectorName 
                           completion:(void (^)(NSString *result))completion;
@end


static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    
    // 核心拦截逻辑：检查上下文是否存在
    if (g_currentExtractionContext != nil) {
        
        // 【请确认】这里使用您提到的父容器VC类名。如果这个不准，可以换成检查 vcToPresent.title
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
        if ([vcClassName containsString:@"格局總覽視圖"]) {
            
            NSLog(@"[Echo无痕提取] 拦截成功！上下文: %@", g_currentExtractionContext);
            
            // 1. 无痕加载 View
            UIView *contentView = vcToPresent.view;
            
            // 2. 直接提取数据 (这是您原来版本中针对这类弹窗的解析逻辑)
            NSMutableArray *textParts = [NSMutableArray array];
            NSMutableArray *stackViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UIStackView class], contentView, stackViews);
            [stackViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
            
            for (UIStackView *stackView in stackViews) {
                NSArray *arrangedSubviews = stackView.arrangedSubviews;
                if (arrangedSubviews.count >= 1 && [arrangedSubviews[0] isKindOfClass:[UILabel class]]) {
                    UILabel *titleLabel = arrangedSubviews[0];
                    NSString *rawTitle = titleLabel.text ?: @"";
                    // 清理标题中的赘余词
                    rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 毕法" withString:@""];
                    rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 法诀" withString:@""];
                    rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 格局" withString:@""];
                    rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 方法" withString:@""];
                    NSString *cleanTitle = [rawTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    
                    NSMutableArray *descParts = [NSMutableArray array];
                    if (arrangedSubviews.count > 1) {
                        for (NSUInteger i = 1; i < arrangedSubviews.count; i++) {
                            if ([arrangedSubviews[i] isKindOfClass:[UILabel class]]) {
                                [descParts addObject:((UILabel *)arrangedSubviews[i]).text];
                            }
                        }
                    }
                    NSString *fullDesc = [[descParts componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
                    [textParts addObject:[NSString stringWithFormat:@"%@→%@", cleanTitle, [fullDesc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]];
                }
            }
            NSString *finalContent = [textParts componentsJoinedByString:@"\n"];
            
            // 3. 回调结果并重置状态
            if (g_genericCompletionHandler) {
                g_genericCompletionHandler(finalContent);
            }
            
            NSLog(@"[Echo无痕提取] %@ 处理完成。", g_currentExtractionContext);

            // 4. 清理上下文和回调，为下次任务做准备
            g_currentExtractionContext = nil;
            g_genericCompletionHandler = nil;

            // 5. 终止 VC 呈现，实现“无痕”
            return;
        }
    }
    
    // 对于其他所有情况，正常调用原始方法
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

%hook UIViewController

// 新增一个通用的、上下文感知的提取函数
%new
- (void)extractSharedPopupWithContext:(NSString *)context 
                         selectorName:(NSString *)selectorName 
                           completion:(void (^)(NSString *result))completion {
    
    if (g_currentExtractionContext != nil) {
        NSLog(@"[Echo无痕提取] 错误：上一个任务 '%@' 尚未完成。", g_currentExtractionContext);
        return;
    }
    
    NSLog(@"[Echo无痕提取] 任务启动，上下文: %@", context);
    
    // 1. 设置上下文和回调
    g_currentExtractionContext = context;
    g_genericCompletionHandler = [completion copy];
    
    // 2. 触发动作
    SEL selector = NSSelectorFromString(selectorName);
    if ([self respondsToSelector:selector]) {
        SUPPRESS_LEAK_WARNING([self performSelector:selector withObject:nil]);
    } else {
        NSLog(@"[Echo无痕提取] 错误: 无法响应选择器 '%@'", selectorName);
        if (g_genericCompletionHandler) {
            g_genericCompletionHandler([NSString stringWithFormat:@"[提取失败: 找不到方法 '%@']", selectorName]);
        }
        // 清理状态
        g_currentExtractionContext = nil;
        g_genericCompletionHandler = nil;
    }
}


// =========================================================
// 以下是测试用的触发函数，您可以从您的控制面板按钮调用它们
// =========================================================

%new
- (void)TEST_handle_BiFa_Button_Tap {
    [self extractSharedPopupWithContext:@"BiFa" 
                           selectorName:@"顯示法訣總覽" 
                             completion:^(NSString *result) {
        NSLog(@"[测试结果] 毕法要诀:\n%@", result);
        // 在这里，您可以将 result 格式化并发送到 AI
    }];
}

%new
- (void)TEST_handle_GeJu_Button_Tap {
    [self extractSharedPopupWithContext:@"GeJu"
                           selectorName:@"顯示格局總覽"
                             completion:^(NSString *result) {
        NSLog(@"[测试结果] 格局要览:\n%@", result);
    }];
}

%new
- (void)TEST_handle_FangFa_Button_Tap {
    [self extractSharedPopupWithContext:@"FangFa"
                           selectorName:@"顯示方法總覽"
                             completion:^(NSString *result) {
        NSLog(@"[测试结果] 解析方法:\n%@", result);
    }];
}

%end


// =========================================================================
// 3. 构造函数
// =========================================================================
%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[Echo上下文感知测试脚本] 已加载。");
    }
}
