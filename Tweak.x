#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
//  Echo Tweak v30.4 - Hybrid Hook Final
// =========================================================================

#pragma mark - Global UI & State
static const NSInteger kEchoControlButtonTag = 556699;
static NSString *g_lastGeneratedReport = nil;
#define ECHO_COLOR_MAIN_BLUE [UIColor colorWithRed:0.17 green:0.31 blue:0.51 alpha:1.0]

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

#pragma mark - API Extraction Logic (as a C function)

// The extraction logic itself is correct and remains unchanged.
static void runUltimateAPIExtraction_IMP(id self, SEL _cmd) {
    NSLog(@"[Echo API] Extraction initiated.");
    
    Ivar ivar = class_getInstanceVariable([self class], "ç¸½é«”æ¼”ç¤ºå™¨");
    id kePanModel = ivar ? object_getIvar(self, ivar) : nil;

    if (!kePanModel) {
        NSLog(@"[Echo API] FATAL: Could not get 'kePanModel' instance via object_getIvar!");
        return;
    }
    NSLog(@"[Echo API] Successfully accessed the core data model: %@", kePanModel);

    NSMutableString *report = [NSMutableString string];
    [report appendString:@"----- 标准化课盘 (API直取 v1.4) -----\n\n"];
    
    @try {
        id siZhu = [kePanModel valueForKey:@"å››æŸ±"];
        id xun = [kePanModel valueForKey:@"æ—¬"];
        id tianDiPan = [kePanModel valueForKey:@"å¤©åœ°ç›¤"];
        id siKe = [kePanModel valueForKey:@"å››èª²"];
        id sanChuan = [kePanModel valueForKey:@"ä¸‰å‚³"];
        id jiuZongMen = [kePanModel valueForKey:@"ä¹ å®—é–€èª²è±¡"];
        
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
    
    NSString *finalReport = [report stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    g_lastGeneratedReport = [finalReport copy];
    [UIPasteboard generalPasteboard].string = finalReport;
    NSLog(@"[Echo API] Extraction complete. Report copied to clipboard.");
}


#pragma mark - Tweak Hooking Logic

%hook UIViewController

// We hook the generic UIViewController's viewDidAppear:
- (void)viewDidAppear:(BOOL)animated {
    %orig;

    // Define the mangled name of our target ViewController
    NSString *targetClassName = @"_TtC12å…­å£¬å¤§å  14ViewController";
    
    // Check if the current view controller is the one we want to modify
    if ([NSStringFromClass([self class]) isEqualToString:targetClassName]) {

        // --- Method Injection (runs only once) ---
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSLog(@"[Echo Hybrid] Target ViewController appeared for the first time. Injecting method...");
            Class vcClass = [self class];
            SEL newMethodSelector = @selector(runUltimateAPIExtraction);
            class_addMethod(vcClass, newMethodSelector, (IMP)runUltimateAPIExtraction_IMP, "v@:");
            NSLog(@"[Echo Hybrid] Injected -runUltimateAPIExtraction into %@", targetClassName);
        });

        // --- Button Creation/Update (runs every time) ---
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = GetFrontmostWindow();
            if (!keyWindow) return;

            UIView *existingButton = [keyWindow viewWithTag:kEchoControlButtonTag];
            if (existingButton) {
                [keyWindow bringSubviewToFront:existingButton];
            } else {
                NSLog(@"[Echo Hybrid] Button not found, creating new one.");
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
            }
        });
    }
}

%end
