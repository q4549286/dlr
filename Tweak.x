#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 侦察专用代码 V3 - 使用 object_getIvar 进行精准探测
// =========================================================================

static BOOL hasLogged_V3 = NO;

void showLoggingAlertForViewController_V3(UIViewController *vc);

// 日志生成和显示的核心函数
void showLoggingAlertForViewController_V3(UIViewController *vc) {
    if (hasLogged_V3) return;
    hasLogged_V3 = YES;

    NSMutableString *logMessage = [NSMutableString string];
    [logMessage appendString:@"--- 侦察日志 V3 (精准探测) ---\n\n"];
    [logMessage appendFormat:@"ViewController Instance: %@\n\n", vc];

    id targetObject = vc;

    // --- 使用 object_getIvar 精准探测实例变量 ---
    [logMessage appendString:@"--- IVARS (Direct Read) ---\n"];
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([targetObject class], &ivarCount);
    if (ivarCount == 0) {
        [logMessage appendString:@"(No ivars found)\n"];
    }
    for (int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *ivarName_c = ivar_getName(ivar);
        const char *ivarType_c = ivar_getTypeEncoding(ivar);
        if (ivarName_c) {
            NSString *ivarName = [NSString stringWithUTF8String:ivarName_c];
            NSString *ivarType = [NSString stringWithUTF8String:ivarType_c];
            id value = nil;
            @try {
                // 这是最关键的一步：直接从内存读取实例变量
                value = object_getIvar(targetObject, ivar);
            } @catch (NSException *exception) {
                value = [NSString stringWithFormat:@"(Exception on direct access: %@)", exception.reason];
            }
            [logMessage appendFormat:@"ivar: %@ (type: %@) = %@\n", ivarName, ivarType, value];
        }
    }
    free(ivars);

    // --- 创建并显示弹窗 ---
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"侦察日志 V3 (精准探测)" message:logMessage preferredStyle:UIAlertControllerStyleAlert];
        
        // 为长日志添加滚动视图
        UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 270, 400)]; // 给一个足够大的初始尺寸
        textView.text = logMessage;
        textView.editable = NO;
        textView.backgroundColor = [UIColor clearColor];
        textView.font = [UIFont systemFontOfSize:10]; // 用小一点的字体显示更多内容
        
        // 将TextView放入一个容器视图中，再设置给alert的accessoryView（如果支持）或直接添加到视图中
        // 为了简单兼容，我们直接修改message，并让用户可以复制
        [alert setValue:logMessage forKey:@"message"];

        UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"复制日志" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [UIPasteboard generalPasteboard].string = logMessage;
        }];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleCancel handler:nil];

        [alert addAction:copyAction];
        [alert addAction:okAction];
        
        UIWindow *activeWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
                if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                    activeWindow = windowScene.windows.firstObject;
                    break;
                }
            }
        }
        if (!activeWindow) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            activeWindow = [[UIApplication sharedApplication] keyWindow];
            #pragma clang diagnostic pop
        }
        [activeWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}


// Hook一个很晚才会出现的视图，确保数据已加载
%hook UIView 
- (void)didMoveToWindow {
    %orig;
    if ([self isKindOfClass:NSClassFromString(@"六壬大占.傳視圖")]) {
        UIResponder *responder = self;
        while ((responder = [responder nextResponder])) {
            if ([responder isKindOfClass:NSClassFromString(@"六壬大占.ViewController")]) {
                showLoggingAlertForViewController_V3((UIViewController *)responder);
                break;
            }
        }
    }
}
%end
