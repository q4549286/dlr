#import <UIKit/UIKit.h>
#import <objc/runtime.h> // For associated objects

// --- Associated object key to prevent recursion in setText ---
static const void *kUILabelIsProcessingSetTextKey = &kUILabelIsProcessingSetTextKey;

%hook UILabel

- (void)setText:(NSString *)text {
    // Check if we are already processing this label's setText to prevent recursion
    // This happens when we set self.text or self.attributedText inside this hook.
    if (objc_getAssociatedObject(self, kUILabelIsProcessingSetTextKey)) {
        %orig; // Call original with the given text
        return;
    }

    // Mark as processing
    objc_setAssociatedObject(self, kUILabelIsProcessingSetTextKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // ‼️ Call %orig FIRST. This allows the app to set its initial text,
    // attributedText, font, color, etc. We will then modify it.
    %orig;

    // --- Start of our modifications ---

    BOOL modified = NO; // Flag to track if we made changes

    // --- 1. General Traditional to Simplified Conversion ---
    // Prefer attributedText if available, as it holds more styling.
    if (self.attributedText) {
        NSMutableAttributedString *newAttrText = [self.attributedText mutableCopy];
        NSString *originalString = newAttrText.string;

        CFStringTransform((__bridge CFMutableStringRef)newAttrText.mutableString, NULL, CFSTR("Hant-Hans"), false);

        // Only update if the string content actually changed
        if (![newAttrText.string isEqualToString:originalString]) {
            self.attributedText = newAttrText; // This will call setText: again, handled by our recursion guard
            modified = YES;
        }
    } else if (self.text) {
        NSMutableString *newText = [self.text mutableCopy];
        NSString *originalString = [self.text copy];

        CFStringTransform((__bridge CFMutableStringRef)newText, NULL, CFSTR("Hant-Hans"), false);

        // Only update if the string content actually changed
        if (![newText isEqualToString:originalString]) {
            self.text = newText; // This will call setText: again, handled by our recursion guard
            modified = YES;
        }
    }

    // --- 2. Specific Styling for "Echo定制" ---
    // IMPORTANT: Check self.text AFTER the Hant-Hans conversion,
    // as "通类" might have been converted to simplified if it had traditional characters.
    // Or, if "通类" was already simplified, it would remain "通类".
    // We are looking for the label that *originally* was "通类".
    // Let's assume after conversion, if it was "通类", it's still identifiable,
    // or we are targeting the text that *becomes* "Echo定制".

    // The user's original code checks for "通类" and *then* sets "Echo定制".
    // So, we need to know what "通类" becomes after simplification (if anything changes)
    // or if the logic is: if original is "通类", then change to "Echo定制" and style it.
    // Let's assume the input `text` to this method (captured before %orig) is what we need to check
    // for "通类". However, `%orig` is called first, so `self.text` is now the current text.

    // For clarity, let's assume the label we want to change to "Echo定制"
    // will have its text set to "通类" by the app.
    // We need to capture the text *before* %orig to reliably check for "通类"
    // However, the current hook structure calls %orig first.
    // A simpler approach: if a label's text (after simplification) is "通类", THEN change it.

    NSString *textAfterConversion = self.text; // This is the current text, possibly simplified

    if ([textAfterConversion isEqualToString:@"通类"]) { // Check if the (potentially simplified) text is "通类"
        NSString *finalString = @"Echo定制";

        // Font: The image shows "Echo定制" as smaller and white.
        // Let's use a fixed smaller size. Adjust 12.0 as needed.
        UIFont *echoFont = [UIFont systemFontOfSize:12.0 weight:UIFontWeightMedium];
        // If you need to base it on the original font:
        // UIFont *originalFont = self.font ?: [UIFont systemFontOfSize:17.0]; // Provide a fallback
        // UIFont *echoFont = [UIFont fontWithName:originalFont.fontName size:12.0];


        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = NSTextAlignmentCenter;

        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        attributes[NSFontAttributeName] = echoFont;
        attributes[NSForegroundColorAttributeName] = [UIColor whiteColor]; // Text is white in the image
        attributes[NSParagraphStyleAttributeName] = paragraphStyle;
        // The gray background is likely part of the UILabel's superview or the UILabel's backgroundColor
        // already set by the app. If not, you'd set self.backgroundColor here.

        NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:finalString attributes:attributes];
        self.attributedText = attributedString; // This will call setText: again
        modified = YES;
    }


    // If we modified the text or attributes, invalidate layout
    if (modified) {
        [self invalidateIntrinsicContentSize];
        [self setNeedsLayout]; // Good practice
    }

    // Clear the processing flag
    objc_setAssociatedObject(self, kUILabelIsProcessingSetTextKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

%end

// --- UIStackView Hook for "Echo定制" Layout ---
// This hook helps prevent the "Echo定制" label from being squished if it's in a UIStackView.
%hook UIStackView

- (void)layoutSubviews {
    %orig;

    for (UIView *subview in self.arrangedSubviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            
            // Check for the *final* displayed text of the label
            NSString *labelTextToCheck = label.text;
            if (label.attributedText) { // Prefer attributed string if it exists
                labelTextToCheck = label.attributedText.string;
            }

            if ([labelTextToCheck isEqualToString:@"Echo定制"]) {
                [label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
                // You might also want to set hugging priority if it's expanding too much
                // [label setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
                // break; // If you only expect one "Echo定制" label per stack view. Remove if multiple.
            }
        }
    }
}
%end
