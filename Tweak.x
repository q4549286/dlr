#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Scout] " format), ##__VA_ARGS__)

%hook 六壬大占_天地盤視圖類

// ==========================================================
// 核心侦察区域：我们只 Hook 我们猜测的方法
// ==========================================================

// 猜测 1: 标准的 touchesEnded
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    EchoLog(@"!!!!!! [SUCCESS] touchesEnded: CALLED! The app uses the standard touch handling method. !!!!!!");
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self];
    EchoLog(@"Touch location: %@", NSStringFromCGPoint(location));

    // 调用原始实现，让App正常工作
    %orig(touches, event);
}

// 猜测 2: 名为 handleTap 的手势处理
- (void)handleTap:(UIGestureRecognizer *)gestureRecognizer {
    EchoLog(@"!!!!!! [SUCCESS] handleTap: CALLED! We found the gesture handler! !!!!!!");
    EchoLog(@"Gesture Recognizer: %@", gestureRecognizer);
    %orig;
}

// 猜测 3: 名为 handleGesture 的手势处理
- (void)handleGesture:(UIGestureRecognizer *)gestureRecognizer {
    EchoLog(@"!!!!!! [SUCCESS] handleGesture: CALLED! We found the gesture handler! !!!!!!");
    EchoLog(@"Gesture Recognizer: %@", gestureRecognizer);
    %orig;
}

// 猜测 4: 名为 viewTapped 的手势处理
- (void)viewTapped:(UIGestureRecognizer *)gestureRecognizer {
    EchoLog(@"!!!!!! [SUCCESS] viewTapped: CALLED! We found the gesture handler! !!!!!!");
    EchoLog(@"Gesture Recognizer: %@", gestureRecognizer);
    %orig;
}

// ==========================================================
// 如果上面的方法都没有打印日志，你可以继续添加你的猜测。
// 例如，如果你在其他地方看到一个可疑的方法名，比如 "palaceTapped:"
// 你就可以在这里添加：
//
// - (void)palaceTapped:(id)sender {
//     EchoLog(@"!!!!!! [SUCCESS] palaceTapped: CALLED! !!!!!!");
//     %orig;
// }
// ==========================================================

%end
