#import <UIKit/UIKit.h>

%hook UILabel

- (void)setText:(NSString *)text {
    if ([text isEqualToString:@"通類"]) {
        text = @"我的分类"; 
    }
    %orig(text);
}

%end