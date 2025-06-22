#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Scout] " format), ##__VA_ARGS__)

// 辅助函数保持不变
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

%hook 六壬大占_天地盤視圖類

// 当这个视图加载时，我们打印出它的所有方法，方便我们寻找目标
- (id)initWithCoder:(NSCoder *)aDecoder {
    id result = %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        PrintAllMethods([self class]);
    });
    return result;
}

// 【修正】我们不知道 handleTap: 是否存在，所以暂时不用 %orig
// 如果这个类真的有 handleTap:，这个钩子会覆盖它。
// 如果它没有，也没关系，不会编译错误。
- (void)handleTap:(UIGestureRecognizer *)gestureRecognizer {
    EchoLog(@"!!!!!! [GUESS] handleTap: CALLED !!!!!!");
    EchoLog(@"Gesture Recognizer: %@", gestureRecognizer);
    // 我们不能在这里使用 %orig，因为我们不确定原始方法是否存在。
    // 如果日志打印了，就说明我们猜对了方法名！
    // %orig;  // <--- 注释掉或删除这一行
    
    // 我们先调用原始实现，然后再打印日志
    %orig; 
}

// 这个方法是系统标准的，所以可以安全地使用 %orig
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    EchoLog(@"!!!!!! touchesEnded CALLED !!!!!!");
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    EchoLog(@"Touch location: %@", NSStringFromCGPoint(location));
    %orig(touches, event);
}


// 【新增一个猜测】很多手势处理方法都以 "handle" 开头
// 我们可以添加更多猜测
- (void)handleGesture:(UIGestureRecognizer *)gestureRecognizer {
    EchoLog(@"!!!!!! [GUESS] handleGesture: CALLED !!!!!!");
    %orig;
}

- (void)viewTapped:(UIGestureRecognizer *)gestureRecognizer {
    EchoLog(@"!!!!!! [GUESS] viewTapped: CALLED !!!!!!");
    %orig;
}

%end
