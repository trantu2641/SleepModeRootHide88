- (id)moduleInstanceForModuleIdentifier:
    (NSString *)identifier
{
    NSLog(@"[SleepMode] Provider yêu cầu module: %@",
          identifier);

    if (![identifier isEqualToString:
          SleepModeIdentifier]) {

        NSLog(@"[SleepMode] Identifier không khớp");

        return nil;
    }

    NSString *modulePath =
        @"/Library/ControlCenter/Bundles/"
        @"SleepModeModule.bundle";

    NSLog(@"[SleepMode] Module path: %@",
          modulePath);

    NSBundle *moduleBundle =
        [NSBundle bundleWithPath:modulePath];

    if (!moduleBundle) {

        NSLog(
            @"[SleepMode] ERROR: không tìm thấy "
             "SleepModeModule.bundle"
        );

        return nil;
    }

    NSLog(
        @"[SleepMode] Đã tìm thấy bundle: %@",
        moduleBundle
    );

    NSError *error = nil;

    BOOL loaded =
        [moduleBundle
            loadAndReturnError:&error];

    NSLog(
        @"[SleepMode] load bundle = %d, error = %@",
        loaded,
        error
    );

    Class moduleClass =
        NSClassFromString(@"SleepModeModule");

    NSLog(
        @"[SleepMode] SleepModeModule class = %@",
        moduleClass
    );

    if (!moduleClass) {

        NSLog(
            @"[SleepMode] ERROR: class "
             "SleepModeModule không tồn tại"
        );

        return nil;
    }

    id module =
        [[moduleClass alloc] init];

    NSLog(
        @"[SleepMode] module instance = %@",
        module
    );

    if (!module) {

        NSLog(
            @"[SleepMode] ERROR: alloc/init module thất bại"
        );

        return nil;
    }

    NSLog(
        @"[SleepMode] MODULE ĐÃ TẠO THÀNH CÔNG"
    );

    return module;
}
