#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-v10] " format), ##__VA_ARGS__)

static BOOL g_isTestingNianMing = NO;
static NSString *g_currentItemToExtract = nil;
static NSMutableArray *g_capturedZhaiYaoArray = nil; 
static NSMutableArray *g_capturedGeJuArray = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

@interface UIViewController (DelegateTestAddon)
- (void)performFullContentExtractTest;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            NSInteger testButtonTag = 999009;
            if ([keyWindow viewWithTag:testButtonTag]) return;
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 200, 45, 90, 36);
            [testButton setTitle:@"测试完整内容" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:13];
            testButton.backgroundColor = [UIColor systemIndigoColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            testButton.tag = testButtonTag;
            
            [testButton addTarget:self action:@selector(performFullContentExtractTest) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            EchoLog(@"完整内容提取测试按钮已添加。");
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingNianMing && g_currentItemToExtract) {
        if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) { /* ... 操作表拦截逻辑，无变化 ... */
            UIAlertController *alert = (UIAlertController *)viewControllerToPresent;
            UIAlertAction *targetAction = nil;
            for (UIAlertAction *action in alert.actions) { if ([action.title isEqualToString:g_currentItemToExtract]) { targetAction = action; break; } }
            if (targetAction) {
                id handler = [targetAction valueForKey:@"handler"];
                if (handler) { ((void (^)(UIAlertAction *))handler)(targetAction); }
                return;
            }
        }
        
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        
        // --- 【核心升级】能处理 TableView 的文本提取逻辑 ---
        NSString* (^extractTextFromVC)(void) = ^NSString* {
            NSMutableString *fullText = [NSMutableString string];
            if (viewControllerToPresent.title) { [fullText appendFormat:@"%@\n", viewControllerToPresent.title]; }

            NSMutableArray *tableViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UITableView class], viewControllerToPresent.view, tableViews);

            if (tableViews.count > 0) {
                // --- 处理TableView ---
                EchoLog(@"检测到 UITableView，将遍历所有单元格。");
                UITableView *tableView = tableViews.firstObject;
                id<UITableViewDataSource> dataSource = tableView.dataSource;
                
                NSInteger sections = 1;
                if ([dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]) {
                    sections = [dataSource numberOfSectionsInTableView:tableView];
                }

                for (NSInteger section = 0; section < sections; section++) {
                    NSInteger rows = [dataSource tableView:tableView numberOfRowsInSection:section];
                    for (NSInteger row = 0; row < rows; row++) {
                        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                        UITableViewCell *cell = [dataSource tableView:tableView cellForRowAtIndexPath:indexPath];
                        
                        if (cell) {
                            NSMutableArray *labelsInCell = [NSMutableArray array];
                            FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labelsInCell);
                            [labelsInCell sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2){ return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)]; }];
                            for (UILabel *label in labelsInCell) {
                                if (label.text && label.text.length > 0) {
                                    [fullText appendFormat:@"%@\n", label.text];
                                }
                            }
                        }
                    }
                }
            } else {
                // --- 保持原有的普通视图处理逻辑 ---
                EchoLog(@"未检测到 UITableView，使用常规视图遍历。");
                NSMutableArray *v = [NSMutableArray array]; FindSubviewsOfClassRecursive([UIView class],viewControllerToPresent.view,v);
                [v filterUsingPredicate:[NSPredicate predicateWithBlock:^(id o,id b){return[o respondsToSelector:@selector(text)];}]];
                [v sortUsingComparator:^NSComparisonResult(UIView*v1,UIView*v2){return[@(v1.frame.origin.y)compare:@(v2.frame.origin.y)];}];
                for(UIView*view in v){NSString*text=[view valueForKey:@"text"];if(text&&text.length>0&&![fullText containsString:text]){[fullText appendFormat:@"%@\n",text];}}
            }
            return [fullText copy];
        };

        if ([g_currentItemToExtract isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) {
            [g_capturedZhaiYaoArray addObject:extractTextFromVC()];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;
        } else if ([g_currentItemToExtract isEqualToString:@"格局方法"] && [vcClassName containsString:@"年命格局視圖"]) {
            [g_capturedGeJuArray addObject:extractTextFromVC()];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performFullContentExtractTest {
    EchoLog(@"--- 开始(完整内容)提取所有年命信息测试 ---");
    
    g_isTestingNianMing = YES;
    g_capturedZhaiYaoArray = [NSMutableArray array];
    g_capturedGeJuArray = [NSMutableArray array];
    
    // ... 后续逻辑与v9完全相同，为简洁省略，但实际代码中是完整的 ...
    UICollectionView*t=nil;Class u=NSClassFromString(@"六壬大占.行年單元");NSMutableArray*c=[NSMutableArray array];FindSubviewsOfClassRecursive([UICollectionView class],self.view,c);for(UICollectionView*cv in c){if([cv.visibleCells.firstObject isKindOfClass:u]){t=cv;break;}}if(!t){g_isTestingNianMing=NO;return;}NSMutableArray*a=[NSMutableArray array];for(UIView*cell in t.visibleCells){if([cell isKindOfClass:u]){[a addObject:cell];}}[a sortUsingComparator:^NSComparisonResult(UIView*v1,UIView*v2){return[@(v1.frame.origin.x)compare:@(v2.frame.origin.x)];}];EchoLog(@"找到 %lu 个单元。",(unsigned long)a.count);void(^e)(NSString*,void(^)(void))=^(NSString*i,void(^b)(void)){dispatch_queue_t q=dispatch_queue_create("e",DISPATCH_QUEUE_SERIAL);dispatch_async(q,^{g_currentItemToExtract=i;EchoLog(@"===== 开始: %@ =====",i);for(UIView*cell in a){dispatch_sync(dispatch_get_main_queue(),^{id d=t.delegate;NSIndexPath*p=[t indexPathForCell:(UICollectionViewCell*)cell];if(d&&p){SEL s=@selector(collectionView:didSelectItemAtIndexPath:);if([d respondsToSelector:s]){#define W(code) _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored\"-Warc-performSelector-leaks\"") code; _Pragma("clang diagnostic pop")
    W([d performSelector:s withObject:t withObject:p]);}}});[NSThread sleepForTimeInterval:0.5];}g_currentItemToExtract=nil;EchoLog(@"===== %@ 完成 =====",i);if(b){dispatch_async(dispatch_get_main_queue(),b);}});};e(@"年命摘要",^{e(@"格局方法",^{NSMutableString*f=[NSMutableString string];for(NSUInteger i=0;i<a.count;i++){NSString*z=(i<g_capturedZhaiYaoArray.count)?g_capturedZhaiYaoArray[i]:@"[摘要未提取]\n";NSString*g=(i<g_capturedGeJuArray.count)?g_capturedGeJuArray[i]:@"[格局未提取]\n";[f appendString:z];[f appendString:@"\n--- 格局方法 ---\n"];[f appendString:g];[f appendString:@"\n====================\n"];}UIAlertController*l=[UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"完整提取 (%lu人)",(unsigned long)a.count]message:f preferredStyle:UIAlertControllerStyleAlert];[l addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:l animated:YES completion:^{g_isTestingNianMing=NO;}];});});
}
%end
