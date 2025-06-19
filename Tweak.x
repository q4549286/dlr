#import <UIKit/UIKit.h> // <-- THE MOST IMPORTANT FIX: Import the UIKit framework

%hook UIView

// When UIView initializes, add our custom gesture
- (id)initWithFrame:(CGRect)frame {
    id result = %orig; // Call the original initWithFrame:

    // We need to check if the view can have user interaction enabled.
    // Also, only add the gesture to the view itself, not to the recognizer.
    if (result) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressForCopy:)];
        [self addGestureRecognizer:longPress];
        // [longPress release]; // <-- REMOVED: This causes an error in ARC projects.
    }

    return result;
}

// Our new method to handle the long press
%new
- (void)handleLongPressForCopy:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        NSMutableString *foundText = [NSMutableString string];
        
        // Start the recursive search for text from the view that was pressed
        [self findAndAppendTextInView:gesture.view toString:foundText];

        if (foundText.length > 0) {
            // Trim leading/trailing whitespace and newlines
            NSString *finalText = [foundText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            // Copy to the system clipboard
            [[UIPasteboard generalPasteboard] setString:finalText];
            
            // Give the user a visual confirmation
            // We need to find the top-most view controller to present the alert
            UIViewController *presentingVC = [UIApplication sharedApplication].keyWindow.rootViewController;
            while (presentingVC.presentedViewController) {
                presentingVC = presentingVC.presentedViewController;
            }

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"复制成功"
                                                                             message:[NSString stringWithFormat:@"已复制 %lu 个字符", (unsigned long)finalText.length]
                                                                      preferredStyle:UIAlertControllerStyleAlert];

            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            
            [presentingVC presentViewController:alert animated:YES completion:nil];
        }
    }
}

// Our new recursive method to find all text in a view and its subviews
%new
- (void)findAndAppendTextInView:(UIView *)view toString:(NSMutableString *)text {
    // Check if the current view is a UILabel
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (label.text.length > 0 && !label.isHidden) {
            [text appendString:label.text];
            [text appendString:@"\n"]; // Use a newline to separate text from different labels
        }
    } 
    // Check if the current view is a UITextView
    else if ([view isKindOfClass:[UITextView class]]) {
        UITextView *textView = (UITextView *)view;
        if (textView.text.length > 0 && !textView.isHidden) {
            [text appendString:textView.text];
            [text appendString:@"\n"];
        }
    }

    // Recursively search in all subviews
    for (UIView *subview in view.subviews) {
        [self findAndAppendTextInView:subview toString:text];
    }
}

%end
