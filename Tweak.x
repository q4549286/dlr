#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 獨立測試版 (TableView 探測版)
// 目標: Hook cellForRowAtIndexPath，找到配置Cell的原始數據模型
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Debug] " format), ##__VA_ARGS__)

// 用来存储日志，以便在最后显示
static NSMutableString *g_logOutput = nil;

// 辅助函数：获取当前活跃的Window
static UIWindow *GetActiveWindow() {
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) { if (window.isKeyWindow) return window; }
                if (scene.windows.count > 0) return scene.windows.firstObject;
            }
        }
    }
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIApplication sharedApplication].keyWindow;
    #pragma clang diagnostic pop
}

// Hook 目标视图控制器
%hook 六壬大占_格局總覽視圖

// 当视图将要出现时，初始化日志
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    g_logOutput = [NSMutableString stringWithString:@"--- TableView 探測日誌 ---\n\n"];
    EchoLog(@"Log Initialized for 格局總覽視圖");
}

// 当视图将要消失时，显示日志
- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    if (g_logOutput) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"探測完成" message:g_logOutput preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [GetActiveWindow().rootViewController presentViewController:alert animated:YES completion:nil];
        g_logOutput = nil; // 清空日志，防止重复显示
    }
}

// 核心：Hook cellForRowAtIndexPath
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // 只探测一次，防止日志过多
    if (g_logOutput && [g_logOutput containsString:@"正在探測第 0 行"]) {
        return %orig;
    }

    if (g_logOutput) {
         [g_logOutput appendFormat:@"正在探測第 %ld 行...\n", (long)indexPath.row];
    }
    
    // 在这里，我们可以访问 self (也就是'格局总览视图'的实例)
    // 我们可以尝试再次获取数据源数组
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([self class], &ivarCount);
    if (ivars) {
        for (unsigned int i = 0; i < ivarCount; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            if (!name) continue;
            
            NSString *ivarName = [NSString stringWithUTF8String:name];
            // 我们寻找名字里包含"列"的数组
            if ([ivarName containsString:@"列"]) {
                id dataArray = object_getIvar(self, ivar);
                if (dataArray && [dataArray respondsToSelector:@selector(count)] && [(id)dataArray count] > indexPath.row) {
                    
                    id dataModel = [(id)dataArray objectAtIndex:indexPath.row];
                    
                    if (g_logOutput) {
                        [g_logOutput appendFormat:@"\n從變量 '%@' 中找到數據模型:\n", ivarName];
                        [g_logOutput appendFormat:@"數據模型類型: %@\n", NSStringFromClass([dataModel class])];
                        
                        // 探测数据模型内部的实例变量
                         [g_logOutput appendString:@"\n其內部變量有:\n"];
                        unsigned int modelIvarCount;
                        Ivar *modelIvars = class_copyIvarList([dataModel class], &modelIvarCount);
                        if (modelIvars) {
                             if (modelIvarCount == 0) {
                                [g_logOutput appendString:@"- (無可探測的實例變量)\n"];
                            } else {
                                for (unsigned int j = 0; j < modelIvarCount; j++) {
                                    const char *modelIvarName = ivar_getName(modelIvars[j]);
                                    if (modelIvarName) {
                                        [g_logOutput appendFormat:@"- %s\n", modelIvarName];
                                    }
                                }
                            }
                            free(modelIvars);
                        }
                    }
                }
            }
        }
        free(ivars);
    }

    return %orig;
}

%end
