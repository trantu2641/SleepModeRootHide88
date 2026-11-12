#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol CCSModuleProvider <NSObject>

@required

- (NSUInteger)numberOfProvidedModules;

- (NSString *)identifierForModuleAtIndex:
    (NSUInteger)index;

- (id)moduleInstanceForModuleIdentifier:
    (NSString *)identifier;

- (NSString *)displayNameForModuleIdentifier:
    (NSString *)identifier;

@optional

- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:
    (NSString *)identifier;

- (NSSet *)requiredDeviceCapabilitiesForModuleWithIdentifier:
    (NSString *)identifier;

- (NSSet *)requiredDeviceIncapabilitiesForModuleWithIdentifier:
    (NSString *)identifier;

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:
    (NSString *)identifier;

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:
    (NSString *)identifier;

- (NSUInteger)visibilityPreferenceForModuleWithIdentifier:
    (NSString *)identifier;

- (UIImage *)settingsIconForModuleIdentifier:
    (NSString *)identifier;

@end


static NSString * const SleepModeIdentifier =
    @"com.trantu.sleepmode";


@interface SleepModeProvider : NSObject
<
CCSModuleProvider
>
@end


@implementation SleepModeProvider


- (NSUInteger)numberOfProvidedModules
{
    NSLog(@"[SleepMode] Provider numberOfProvidedModules -> 1");

    return 1;
}


- (NSString *)identifierForModuleAtIndex:
    (NSUInteger)index
{
    if (index != 0) {
        NSLog(
            @"[SleepMode] Provider identifier index không hợp lệ: %lu",
            (unsigned long)index
        );

        return nil;
    }

    NSLog(
        @"[SleepMode] Provider identifier -> %@",
        SleepModeIdentifier
    );

    return SleepModeIdentifier;
}


- (NSString *)displayNameForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
          SleepModeIdentifier]) {

        return nil;
    }

    NSLog(
        @"[SleepMode] Provider displayName -> Chế độ ngủ"
    );

    return @"Chế độ ngủ";
}


- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
          SleepModeIdentifier]) {

        return nil;
    }

    return [NSSet setWithObjects:
        @1,
        @2,
        nil
    ];
}


- (UIImage *)settingsIconForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
          SleepModeIdentifier]) {

        return nil;
    }

    NSBundle *bundle =
        [NSBundle bundleForClass:[self class]];

    NSString *path =
        [bundle pathForResource:
            @"SleepModeProviderIcon"
            ofType:@"png"];

    if (!path) {

        NSLog(
            @"[SleepMode] Provider không tìm thấy icon: SleepModeProviderIcon.png"
        );

        return nil;
    }

    UIImage *image =
        [UIImage imageWithContentsOfFile:path];

    NSLog(
        @"[SleepMode] Provider settings icon = %@",
        image
    );

    return image;
}


- (id)moduleInstanceForModuleIdentifier:
    (NSString *)identifier
{
    NSLog(
        @"[SleepMode] Provider yêu cầu module: %@",
        identifier
    );

    if (![identifier isEqualToString:
          SleepModeIdentifier]) {

        NSLog(
            @"[SleepMode] Provider identifier không khớp"
        );

        return nil;
    }


    NSString *modulePath =
        @"/Library/ControlCenter/Bundles/SleepModeModule.bundle";


    NSBundle *moduleBundle =
        [NSBundle bundleWithPath:modulePath];


    if (!moduleBundle) {

        NSLog(
            @"[SleepMode] Không tìm thấy bundle: %@",
            modulePath
        );

        return nil;
    }


    NSLog(
        @"[SleepMode] Đã tìm thấy bundle: %@",
        moduleBundle.bundlePath
    );


    NSError *error = nil;

    BOOL loaded =
        [moduleBundle loadAndReturnError:&error];


    NSLog(
        @"[SleepMode] load bundle = %d",
        loaded
    );


    if (!loaded) {

        NSLog(
            @"[SleepMode] Không load được SleepModeModule.bundle: %@",
            error
        );

        return nil;
    }


    Class moduleClass =
        NSClassFromString(@"SleepModeModule");


    NSLog(
        @"[SleepMode] SleepModeModule class = %@",
        moduleClass
    );


    if (!moduleClass) {

        NSLog(
            @"[SleepMode] Không tìm thấy class SleepModeModule"
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
            @"[SleepMode] Không tạo được SleepModeModule"
        );

        return nil;
    }


    NSLog(
        @"[SleepMode] MODULE ĐÃ TẠO THÀNH CÔNG"
    );


    return module;
}

@end
