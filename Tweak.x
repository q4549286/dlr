#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 獨立測試版 (格局彈窗 - 繁體純淨探測版)
// 目标: 逐層深入，安全探測'格局列'的內部結構 (無簡繁轉換)
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Debug] " format), ##__VA_ARGS__)

// 輔助函數: 安全地獲取實例變量的值
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) {
    if (!object) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) { free(ivars); return nil; }
    id value = nil;
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name) {
            NSString *ivarName = [NSString stringWithUTF8String:name];
            // 使用繁體中文後綴匹配
            if ([ivarName hasSuffix:ivarNameSuffix]) {
                ptrdiff_t offset = ivar_getOffset(ivar);
                void **ivar_ptr = (void **)((__bridge void *)object + offset);
                value = (__bridge id)(*ivar_ptr);
                break;
            }
        }
    }
    free(ivars);
    return value;
}

%hook UIViewController

// Hook 彈窗方法
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    
    Class targetClass = NSClassFromString(@"六壬大占.格局總覽視圖");
    if (targetClass && [viewControllerToPresent isKindOfClass:targetClass]) {
        
        // 延遲執行以確保VC和其數據已加載
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSMutableString *logOutput = [NSMutableString string];
            [logOutput appendString:@"--- 開始探測格局彈窗 ---\n\n"];
            
            // ================= 探測核心 =================
            @try {
                // 1. 獲取數據源數組
                id geJuLieObject = GetIvarValueSafely(viewControllerToPresent, @"格局列");
                
                if (!geJuLieObject) {
                    [logOutput appendString:@"1. '格局列' 結果: nil\n"];
                    goto show_log; // 直接跳轉到顯示日誌
                }

                [logOutput appendFormat:@"1. '格局列' 類型: %@\n", NSStringFromClass([geJuLieObject class])];
                
                // 2. 探測數量
                if (![geJuLieObject respondsToSelector:@selector(count)]) {
                    [logOutput appendString:@"2. 對象不支持 count 方法。\n"];
                    goto show_log;
                }
                NSUInteger count = [(id)geJuLieObject count];
                [logOutput appendFormat:@"2. 數量: %ld\n", (unsigned long)count];

                // 3. 探測第一個元素
                if (count == 0) {
                     [logOutput appendString:@"3. 數組為空，無法探測第一個元素。\n"];
                     goto show_log;
                }
                if (![geJuLieObject respondsToSelector:@selector(objectAtIndex:)]) {
                    [logOutput appendString:@"3. 對象不支持 objectAtIndex: 方法。\n"];
                    goto show_log;
                }
                id firstElement = [(id)geJuLieObject objectAtIndex:0];
                if (!firstElement) {
                     [logOutput appendString:@"3. 第一個元素為 nil。\n"];
                     goto show_log;
                }
                [logOutput appendFormat:@"3. 第一個元素的類型是: %@\n", NSStringFromClass([firstElement class])];

                // 4. 探測第一個元素的內部實例變量
                [logOutput appendString:@"\n4. 正在探測第一個元素的實例變量...\n"];
                unsigned int ivarCount;
                Ivar *ivars = class_copyIvarList([firstElement class], &ivarCount);
                 if (!ivars) {
                    [logOutput appendString:@"無法獲取第一個元素的實例變量列表。\n"];
                } else {
                    if (ivarCount == 0) {
                        [logOutput appendString:@"該對象沒有可探測的實例變量。\n"];
                    } else {
                        for (unsigned int i = 0; i < ivarCount; i++) {
                            Ivar ivar = ivars[i];
                            const char *name = ivar_getName(ivar);
                            const char *type = ivar_getTypeEncoding(ivar);
                            if (name && type) {
                                 [logOutput appendFormat:@"- 變量名: %s, 類型編碼: %s\n", name, type];
                            }
                        }
                    }
                    free(ivars);
                }

            } @catch (NSException *exception) {
                [logOutput appendFormat:@"\n!!! 在探測過程中捕獲到異常 !!!\n\n%@\n%@", exception.name, exception.reason];
            }
            
        show_log:;
            // ============================================

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"格局彈窗探測日誌" message:logOutput preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            // 使用主window的rootViewController來彈出，防止vc已經被dismiss
            [[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:alert animated:YES completion:nil];
        });
        
        // 阻止原彈窗顯示
        return; 
    }
    
    %orig(viewControllerToPresent, flag, completion);
}

%end
