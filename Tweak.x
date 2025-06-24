#import <UIKit/UIKit.h>
#import <objc/runtime.h>

%hook UIViewController

// --- 注入最终的侦察按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = self.view.window; if (!window) return;
            NSInteger buttonTag = 999999;
            [[window viewWithTag:buttonTag] removeFromSuperview];
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(10, 50, 180, 40);
            button.tag = buttonTag;
            [button setTitle:@"终极侦察(课传对象)" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:15];
            button.backgroundColor = [UIColor redColor];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [button addTarget:self action:@selector(inspectKeChuanObject) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:button];
        });
    }
}

%new
// --- 按钮的动作：侦察并显示`課傳`对象的实例变量 ---
- (void)inspectKeChuanObject {
    // 1. 获取`課傳`对象
    Ivar keChuanIvar = class_getInstanceVariable([self class], "課傳");
    if (!keChuanIvar) {
        // ... 错误处理 ...
        return;
    }
    id keChuanObject = object_getIvar(self, keChuanIvar);
    if (!keChuanObject) {
         // ... 错误处理 ...
        return;
    }

    // 2. 开始分析`課傳`对象
    Class keChuanClass = [keChuanObject class];
    NSMutableString *resultString = [NSMutableString stringWithFormat:@"'%@' 对象实例变量报告:\n\n", NSStringFromClass(keChuanClass)];

    unsigned int count;
    Ivar *ivars = class_copyIvarList(keChuanClass, &count);

    for (unsigned int i = 0; i < count; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        const char *type = ivar_getTypeEncoding(ivar);
        
        NSString *ivarName = [NSString stringWithUTF8String:name];
        NSString *ivarType = [NSString stringWithUTF8String:type];

        [resultString appendFormat:@"变量名: %@\n类型: %@\n", ivarName, ivarType];

        if (ivarType.length > 0 && [ivarType characterAtIndex:0] == '@') {
            @try {
                id value = object_getIvar(keChuanObject, ivar);
                [resultString appendFormat:@"值: %@\n", value];
                if ([value isKindOfClass:[NSArray class]]) {
                    NSArray *array = (NSArray *)value;
                    [resultString appendString:@"  (数组内容):\n"];
                    for (int j = 0; j < array.count; j++) {
                        [resultString appendFormat:@"  [%d]: %@\n", j, array[j]];
                    }
                }
                 [resultString appendString:@"\n"];
            } @catch (NSException *exception) {
                [resultString appendString:@"值: (无法读取)\n\n"];
            }
        } else {
             [resultString appendString:@"\n"];
        }
    }
    free(ivars);

    // 显示结果
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(0,0,250,300)];
    textView.text = resultString;
    textView.editable = NO;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"课传对象侦察报告" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert.view addSubview:textView];
    
    [alert.view addConstraint:[NSLayoutConstraint constraintWithItem:alert.view attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:400]];

    [alert addAction:[UIAlertAction actionWithTitle:@"复制并关闭" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        [UIPasteboard generalPasteboard].string = resultString;
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
%end
