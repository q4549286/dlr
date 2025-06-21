#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 侦察专用代码 - 将日志输出到弹窗
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233; // 保持按钮Tag一致

@interface UIViewController (LoggingAddon)
- (void)showLoggingAlert;
@end

%hook UIViewController

// 注入创建按钮的逻辑
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow || [keyWindow viewWithTag:CopyAiButtonTag]) { return; }
            UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
            copyButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45, 90, 36);
            copyButton.tag = CopyAiButtonTag;
            // 按钮标题可以保持不变，但功能已改为显示日志
            [copyButton setTitle:@"复制到AI" forState:UIControlStateNormal];
            copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            copyButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0]; // 改成红色，表示侦察模式
            [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            copyButton.layer.cornerRadius = 8;
            // 将按钮的点击事件指向我们新的日志显示方法
            [copyButton addTarget:self action:@selector(showLoggingAlert) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:copyButton];
        });
    }
}

// 这是核心的日志生成和显示方法
%new
- (void)showLoggingAlert {
    NSMutableString *logMessage = [NSMutableString string];

    [logMessage appendString:@"--- Logging ViewController Details ---\n\n"];
    [logMessage appendFormat:@"Self: %@\n\n", self];

    id targetObject = self; // 目标就是ViewController本身

    // --- 打印属性 (Properties) ---
    [logMessage appendString:@"--- PROPERTIES ---\n"];
    unsigned int propCount;
    objc_property_t *properties = class_copyPropertyList([targetObject class], &propCount);
    if (propCount == 0) {
        [logMessage appendString:@"(No properties found)\n"];
    }
    for (int i = 0; i < propCount; i++) {
        objc_property_t property = properties[i];
        const char *propName = property_getName(property);
        if (propName) {
            NSString *propertyName = [NSString stringWithUTF8String:propName];
            id value = nil;
            @try {
                value = [targetObject valueForKey:propertyName];
            } @catch (NSException *exception) {
                value = [NSString stringWithFormat:@"(Exception on access: %@)", exception.reason];
            }
            [logMessage appendFormat:@"@property: %@ = %@\n", propertyName, value];
        }
    }
    free(properties);
    [logMessage appendString:@"\n"];


    // --- 打印实例变量 (Ivars) ---
    [logMessage appendString:@"--- IVARS ---\n"];
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([targetObject class], &ivarCount);
    if (ivarCount == 0) {
        [logMessage appendString:@"(No ivars found)\n"];
    }
    for (int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *ivarName = ivar_getName(ivar);
        if (ivarName) {
            NSString *ivarNameStr = [NSString stringWithUTF8String:ivarName];
            id value = nil;
             @try {
                value = [targetObject valueForKey:ivarNameStr];
            } @catch (NSException *exception) {
                value = [NSString stringWithFormat:@"(Exception on access: %@)", exception.reason];
            }
            [logMessage appendFormat:@"ivar: %@ = %@\n", ivarNameStr, value];
        }
    }
    free(ivars);

    // --- 创建并显示弹窗 ---
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"侦察日志" message:@"" preferredStyle:UIAlertControllerStyleAlert];

    // 创建一个可滚动的文本视图来显示长日志
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectZero];
    textView.text = logMessage;
    textView.editable = NO;
    textView.backgroundColor = [UIColor clearColor];
    
    // 为了在弹窗中正确显示，需要一些约束设置
    textView.translatesAutoresizingMaskIntoConstraints = NO;
    [alert.view addSubview:textView];
    
    // 设置约束
    NSLayoutConstraint *leading = [NSLayoutConstraint constraintWithItem:textView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:alert.view attribute:NSLayoutAttributeLeading multiplier:1.0 constant:15];
    NSLayoutConstraint *trailing = [NSLayoutConstraint constraintWithItem:textView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:alert.view attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:-15];
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:textView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:alert.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:60];
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:textView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:alert.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:-60];
    
    [alert.view addConstraints:@[leading, trailing, top, bottom]];
    
    // 添加一个“好的”按钮
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

%end
