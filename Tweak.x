#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Scout] " format), ##__VA_ARGS__)

// 这是一个标准的C函数，里面不应该有任何 %orig 或 %hook 相关的代码
static void PrintAllMethods(Class aClass) {
    unsigned int methodCount = 0;
    Method *methods = class_copyMethodList(aClass, &methodCount);
    EchoLog(@"--- Methods for class %@ ---", NSStringFromClass(aClass));
    for (unsigned int i = 0; i < methodCount; i++) {
        Method method = methods[i];
        EchoLog(@"Method: %s", sel_getName(method_getName(method)));
    }
    free(methods);
    EchoLog(@"--- End of methods ---");
}

// %hook 只能用来包裹 Objective-C 的类
%hook 六壬大占_天地盤視圖類

// %orig 只能在被 %hook 的方法内部使用
- (id)initWithCoder:(NSCoder *)aDecoder {
    id result = %orig; // 这是合法的，因为在initWithCoder:方法内
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        PrintAllMethods([self class]);
    });
    return result;
}

// 我们猜测的方法。%orig是合法的，因为在被hook的方法内
- (void)handleTap:(UIGestureRecognizer *)gestureRecognizer {
    EchoLog(@"!!!!!! [GUESS] handleTap: CALLED !!!!!!");
    EchoLog(@"Gesture Recognizer: %@", gestureRecognizer);
    %orig;
}

// 这个方法是系统标准的，%orig是合法的
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    EchoLog(@"!!!!!! touchesEnded CALLED !!!!!!");
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    EchoLog(@"Touch location: %@", NSStringFromCGPoint(location));
    %orig(touches, event);
}

// 更多猜测
- (void)handleGesture:(UIGestureRecognizer *)gestureRecognizer {
    EchoLog(@"!!!!!! [GUESS] handleGesture: CALLED !!!!!!");
    %orig;
}

- (void)viewTapped:(UIGestureRecognizer *)gestureRecognizer {
    EchoLog(@"!!!!!! [GUESS] viewTapped: CALLED !!!!!!");
    %orig;
}

%end
