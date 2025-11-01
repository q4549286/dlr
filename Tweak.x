#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
//  Echo Tweak v30.0 - API Runtime Edition
// =========================================================================

#pragma mark - Global UI & State
static const NSInteger kEchoControlButtonTag = 556699;
static NSString *g_lastGeneratedReport = nil;
#define ECHO_COLOR_MAIN_BLUE [UIColor colorWithRed:0.17 green:0.31 blue:0.51 alpha:1.0]

// Forward declaration for the Swift class, we'll use its mangled name
@class _TtC12å…­å£¬å¤§å  14ViewController;

// Helper to get the key window
static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) { if (window.isKeyWindow) { frontmostWindow = window; break; } }
                if (frontmostWindow) break;
            }
        }
    }
    if (!frontmostWindow) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        frontmostWindow = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
    }
    return frontmostWindow;
}

#pragma mark - Core Tweak Logic

%hook _TtC12å…­å£¬å¤§å  14ViewController

// We hook viewDidLoad to add our button
- (void)viewDidLoad {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = GetFrontmostWindow();
        if (!keyWindow || [keyWindow viewWithTag:kEchoControlButtonTag]) return;

        UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
        controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 180, 45, 170, 36);
        controlButton.tag = kEchoControlButtonTag;
        [controlButton setTitle:@"推衍课盘 (API)" forState:UIControlStateNormal];
        controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        controlButton.backgroundColor = ECHO_COLOR_MAIN_BLUE;
        [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        controlButton.layer.cornerRadius = 18;
        [controlButton addTarget:self action:@selector(runUltimateAPIExtraction) forControlEvents:UIControlEventTouchUpInside];
        [keyWindow addSubview:controlButton];
    });
}

// This is our new, powerful extraction method. It requires NO header files.
%new
- (void)runUltimateAPIExtraction {
    NSLog(@"[Echo API] Extraction initiated.");
    
    // 1. Get the Core Data Model instance using MSHookIvar.
    // We use 'id' because we don't have the header file to know the type at compile time.
    // The variable name is the "garbled" version of "總體演示器".
    id kePanModel = MSHookIvar<id>(self, "ç¸½é«”æ¼”ç¤ºå™¨");

    if (!kePanModel) {
        NSLog(@"[Echo API] FATAL: Could not get 'kePanModel' instance!");
        return;
    }
    NSLog(@"[Echo API] Successfully accessed the core data model: %@", kePanModel);

    // 2. Prepare the report string.
    NSMutableString *report = [NSMutableString string];
    [report appendString:@"----- 标准化课盘 (API直取 v1.0) -----\n\n"];
    
    // 3. Extract data using Key-Value Coding (valueForKey:).
    // This is the safest way to get properties from a Swift object at runtime without headers.
    // The keys are the "garbled" property names from the header file.
    
    @try {
        id siZhu = [kePanModel valueForKey:@"å››æŸ±"];
        id xun = [kePanModel valueForKey:@"æ—¬"];
        id tianDiPan = [kePanModel valueForKey:@"å¤©åœ°ç›¤"];
        id siKe = [kePanModel valueForKey:@"å››èª²"];
        id sanChuan = [kePanModel valueForKey:@"ä¸‰å‚³"];
        id jiuZongMen = [kePanModel valueForKey:@"ä¹ å®—é–€èª²è±¡"];
        
        // Use the 'description' property of each object to get a formatted string
        NSString *siZhuDesc = [siZhu description] ?: @"[未获取]";
        NSString *xunDesc = [xun description] ?: @"[未获取]";
        NSString *tianDiPanDesc = [tianDiPan description] ?: @"[未获取]";
        NSString *siKeDesc = [siKe description] ?: @"[未获取]";
        NSString *sanChuanDesc = [sanChuan description] ?: @"[未获取]";
        NSString *jiuZongMenDesc = [jiuZongMen description] ?: @"[未获取]";

        [report appendFormat:@"// 1. 基础盘元\n- 四柱: %@\n- 旬: %@\n\n", siZhuDesc, xunDesc];
        [report appendString:@"// 2. 核心盘架\n"];
        [report appendFormat:@"// 2.1. 天地盘\n%@\n\n", tianDiPanDesc];
        [report appendFormat:@"// 2.2. 四课\n%@\n\n", siKeDesc];
        [report appendFormat:@"// 2.3. 三传\n%@\n\n", sanChuanDesc];
        [report appendFormat:@"// 3. 格局总览\n// 3.1. 九宗门\n%@\n\n", jiuZongMenDesc];
        
    } @catch (NSException *exception) {
        NSLog(@"[Echo API] Exception during data extraction: %@", exception);
        [report appendFormat:@"\n\n--- EXTRACTION ERROR ---\n%@", exception];
    }
    
    // 4. Finalize and output
    NSString *finalReport = [report stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    g_lastGeneratedReport = [finalReport copy];
    [UIPasteboard generalPasteboard].string = finalReport;
    
    NSLog(@"[Echo API] Extraction complete. Report copied to clipboard.");
    
    // You can add your notification pop-up here if you want
    // For example: [self showEchoNotificationWithTitle:@"API提取完成" message:@"课盘已直接从内存提取。"];
}

%end

// Ctor to initialize the hook
%ctor {
    %init;
}
