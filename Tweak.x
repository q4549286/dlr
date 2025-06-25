// Filename: KeTiDetailExtractor_v1.0
// A new, focused script to extract the details of the "课体" (Course Body).

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =================================================================
// 1. Global Variables & Helper Functions
// =================================================================

static UITextView *g_logView = nil; // The log/result text view
static BOOL g_isExtracting = NO;    // A flag to control our hook

// A helper function to find all subviews of a specific class
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}

// Unified logging function
static void LogMessage(NSString *format, ...) {
    if (!g_logView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSString *fullMessage = [logPrefix stringByAppendingString:message];
        g_logView.text = [NSString stringWithFormat:@"%@\n%@", fullMessage, g_logView.text];
        NSLog(@"[KeTiExtractor] %@", message);
    });
}


// =================================================================
// 2. Core Hooking Logic
// =================================================================

// We will hook `presentViewController` to intercept the detail pop-up.
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    // Our hook is only active when the g_isExtracting flag is YES.
    if (g_isExtracting && ![vcToPresent isKindOfClass:[UIAlertController class]]) {
        LogMessage(@"捕获到详情弹窗: %@", NSStringFromClass([vcToPresent class]));
        
        // Make the pop-up invisible and appear instantly
        vcToPresent.view.alpha = 0.0f;
        animated = NO;
        
        // Create a new completion block to wrap the original one
        void (^extractionCompletion)(void) = ^{
            // Run the original completion block if it exists
            if (completion) {
                completion();
            }

            // --- This is where the extraction happens ---
            UIView *contentView = vcToPresent.view;
            NSMutableArray *allLabels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
            
            // Sort labels by their position on screen (top-to-bottom, then left-to-right)
            [allLabels sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
                if (roundf(obj1.frame.origin.y) < roundf(obj2.frame.origin.y)) return NSOrderedAscending;
                if (roundf(obj1.frame.origin.y) > roundf(obj2.frame.origin.y)) return NSOrderedDescending;
                return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)];
            }];
            
            // Join the text from all labels
            NSMutableArray<NSString *> *textParts = [NSMutableArray array];
            for (UILabel *label in allLabels) {
                if (label.text && label.text.length > 0) {
                    [textParts addObject:label.text];
                }
            }
            NSString *fullDetailText = [textParts componentsJoinedByString:@"\n"];
            
            LogMessage(@"--- 提取结果 ---");
            LogMessage(@"%@", fullDetailText);
            LogMessage(@"----------------");

            // Copy the result to the clipboard
            [UIPasteboard generalPasteboard].string = fullDetailText;
            LogMessage(@"结果已复制到剪贴板！");

            // Automatically dismiss the invisible pop-up
            [vcToPresent dismissViewControllerAnimated:NO completion:^{
                LogMessage(@"任务完成，弹窗已自动关闭。");
                g_isExtracting = NO; // Reset the flag
            }];
        };
        
        // Call the original `presentViewController` with our custom completion block
        Original_presentViewController(self, _cmd, vcToPresent, animated, extractionCompletion);
        
    } else {
        // If we are not extracting, just call the original method.
        Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
    }
}


// =================================================================
// 3. UI and Control Logic
// =================================================================

@interface UIViewController (KeTiExtractor)
- (void)setupExtractorPanel;
- (void)startKeTiExtraction;
- (void)closeExtractorPanel;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupExtractorPanel];
        });
    }
}

%new
- (void)setupExtractorPanel {
    UIWindow *keyWindow = self.view.window;
    if (!keyWindow || [keyWindow viewWithTag:789001]) return;

    // Main Panel
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 350, 400)];
    panel.tag = 789001;
    panel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.92];
    panel.layer.cornerRadius = 12;
    panel.layer.borderColor = [UIColor systemIndigoColor].CGColor;
    panel.layer.borderWidth = 1.5;

    // Title Label
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 350, 20)];
    titleLabel.text = @"课体详情提取器 v1.0";
    titleLabel.textColor = [UIColor systemIndigoColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:titleLabel];

    // Main Button
    UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
    extractButton.frame = CGRectMake(20, 50, panel.bounds.size.width - 40, 44);
    [extractButton setTitle:@"提取课体详情" forState:UIControlStateNormal];
    [extractButton addTarget:self action:@selector(startKeTiExtraction) forControlEvents:UIControlEventTouchUpInside];
    extractButton.backgroundColor = [UIColor systemIndigoColor];
    [extractButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    extractButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    extractButton.layer.cornerRadius = 8;
    [panel addSubview:extractButton];

    // Log View
    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 110, panel.bounds.size.width - 20, panel.bounds.size.height - 160)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor greenColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = NO;
    g_logView.layer.cornerRadius = 5;
    g_logView.text = @"点击上方按钮开始提取...";
    [panel addSubview:g_logView];

    // Close button
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(panel.bounds.size.width - 50, 5, 40, 40);
    [closeButton setTitle:@"X" forState:UIControlStateNormal];
    [closeButton.titleLabel setFont:[UIFont boldSystemFontOfSize:20]];
    [closeButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(closeExtractorPanel) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:closeButton];

    [keyWindow addSubview:panel];
}

%new
- (void)startKeTiExtraction {
    if (g_isExtracting) {
        LogMessage(@"错误：当前已有提取任务在进行中。");
        return;
    }
    
    LogMessage(@"开始任务：寻找课体视图...");

    // Find the collection view that contains the "课体" cell.
    UICollectionView *targetCV = nil;
    Class keTiCellClass = NSClassFromString(@"六壬大占.課體視圖");
    if (!keTiCellClass) {
        LogMessage(@"错误: 找不到 '六壬大占.課體視圖' 类。");
        return;
    }
    
    NSMutableArray<UICollectionView *> *allCVs = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], self.view, allCVs);
    
    for (UICollectionView *cv in allCVs) {
        for (UIView *cell in cv.visibleCells) {
            if ([cell isKindOfClass:keTiCellClass]) {
                targetCV = cv;
                break;
            }
        }
        if (targetCV) break;
    }

    if (!targetCV) {
        LogMessage(@"错误: 找不到包含课体视图的UICollectionView。");
        return;
    }
    
    // We assume the "课体" is the first item in the first section.
    // You can change this if you find it's a different item.
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0 inSection:0];
    
    id delegate = targetCV.delegate;
    if (delegate && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
        LogMessage(@"找到目标! 正在以编程方式点击 Section %ld, Item %ld", (long)indexPath.section, (long)indexPath.item);
        g_isExtracting = YES; // Set the flag right before we trigger the action
        [delegate collectionView:targetCV didSelectItemAtIndexPath:indexPath];
    } else {
        LogMessage(@"错误: 无法调用点击方法 (delegate or method not found)。");
    }
}

%new
- (void)closeExtractorPanel {
    UIView *panel = [self.view.window viewWithTag:789001];
    if (panel) {
        [panel removeFromSuperview];
    }
    g_logView = nil; // Clear the global reference
}

%end


// =================================================================
// 4. Constructor to Apply All Hooks
// =================================================================

%ctor {
    @autoreleasepool {
        Class vcClass = NSClassFromString(@"六壬大占.ViewController");
        if (vcClass) {
            MSHookMessageEx(vcClass, @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        }
    }
}
