// 替换旧的 copyAiButtonTapped 方法
%new
- (void)copyAiButtonTapped {
    NSArray *sortedLabels = objc_getAssociatedObject(self, &AllLabelsOnViewKey);
    if (!sortedLabels || sortedLabels.count == 0) {
        [self refreshAndSortLabelsForAiCopy];
        sortedLabels = objc_getAssociatedObject(self, &AllLabelsOnViewKey);
    }
    if (sortedLabels.count == 0) { NSLog(@"[TweakLog] 未找到任何 UILabel。"); return; }
    
    // ----- 打印调试日志，这是您寻找正确索引的唯一工具！-----
    NSMutableString *debugLog = [NSMutableString stringWithString:@"\n[TweakLog] --- 调试日志 ---\n"];
    for (int i = 0; i < sortedLabels.count; i++) {
        UILabel *label = sortedLabels[i];
        NSString *text = label.text ?: @"(空)";
        [debugLog appendFormat:@"索引 %d: '%@' | 位置: %@\n", i, text, NSStringFromCGRect(label.frame)];
    }
    NSLog(@"%@", debugLog);
    
    
    // ================== 全新的数据提取区域 ==================
    //
    //  请根据上面打印出的日志，将下面所有的 [99] 替换为正确的索引号！
    //
    
    // 起课方式 (比如 "元首门")
    NSString *methodName = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";
    
    // 四柱第一行 (比如 "乙巳年 壬午月")
    NSString *sichouLine1 = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";

    // 四柱第二行 (比如 "辛酉日 丁酉时")
    NSString *sichouLine2 = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";

    // 节令第一行 (比如 "夏时 火王")
    NSString *jielingLine1 = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";

    // 节令第二行 (比如 "夏至 初候")
    NSString *jielingLine2 = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";
    
    // 年柱神煞 (比如 "太岁"，它在底部表格中，在“己”的旁边)
    NSString *nianZhuSha = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";

    // 月柱神煞 (比如 "岁德"，它在底部表格中，在“庚”的旁边)
    NSString *yueZhuSha = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";

    // 天盘 (比如 "亥"，在罗盘上)
    NSString *tianPan = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";

    // 地盘 (比如 "寅"，在罗盘上)
    NSString *diPan = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";


    // 组合成您截图中的最终格式
    NSString *finalText = [NSString stringWithFormat:
        @"起课方式: %@\n"
        @"%@\n"
        @"%@\n"
        @"%@\n"
        @"%@\n"
        @"年柱: %@\n"
        @"月柱: %@\n"
        @"天盘: %@\n"
        @"地盘: %@\n\n"
        @"#奇门遁甲 #AI分析",
        methodName,
        sichouLine1,
        sichouLine2,
        jielingLine1,
        jielingLine2,
        nianZhuSha,
        yueZhuSha,
        tianPan,
        diPan
    ];
    
    // ----- 结束数据提取 -----
    
    [UIPasteboard generalPasteboard].string = finalText;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}
