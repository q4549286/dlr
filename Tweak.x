#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Scout] " format), ##__VA_ARGS__)

// 一个辅助函数，用来打印一个对象的所有方法
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
    PrintAllMethods([self class]);
    return result;
}

// 我们猜测手势的回调方法名是 handleTap: 或者类似的
// 先尝试最常见的名字。如果日志没反应，可以换成其他可能的名字
// 比如 touchesEnded:withEvent:
- (void)handleTap:(UIGestureRecognizer *)gestureRecognizer {
    EchoLog(@"!!!!!! TARGET METHOD CALLED !!!!!!");
    EchoLog(@"Gesture Recognizer: %@", gestureRecognizer);
    // 我们可以尝试看看它内部调用了什么
    // 在这里下一个断点或者深入分析这个方法内部的逻辑
    %orig;
}

// 如果上面那个没反应，就试试这个
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    EchoLog(@"!!!!!! touchesEnded CALLED !!!!!!");
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    EchoLog(@"Touch location: %@", NSStringFromCGPoint(location));
    %orig(touches, event);
}

%end
