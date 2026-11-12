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


@interface SleepModeProvider :
    NSObject <CCSModuleProvider>

@end


@implementation SleepModeProvider


#pragma mark - Number

- (NSUInteger)numberOfProvidedModules
{
    return 1;
}


#pragma mark - Identifier

- (NSString *)identifierForModuleAtIndex:
    (NSUInteger)index
{
    if (index != 0) {
        return nil;
    }

    return SleepModeIdentifier;
}


#pragma mark - Display Name

- (NSString *)displayNameForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            SleepModeIdentifier]) {
        return nil;
    }

    return @"Chế độ ngủ";
}


#pragma mark - Device Families

- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            SleepModeIdentifier]) {
        return nil;
    }

    /*
     * 1 = iPhone
     * 2 = iPad
     */
    return [NSSet setWithObjects:
        @1,
        @2,
        nil];
}


#pragma mark - Settings Icon

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
        return nil;
    }

    return [UIImage imageWithContentsOfFile:path];
}


#pragma mark - Module Instance

- (id)moduleInstanceForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            SleepModeIdentifier]) {
        return nil;
    }


    NSString *modulePath =
        @"/Library/ControlCenter/Bundles/"
        @"SleepModeModule.bundle";


    NSBundle *moduleBundle =
        [NSBundle bundleWithPath:modulePath];

    if (!moduleBundle) {

        NSLog(
            @"[SleepMode] Không tìm thấy "
            @"SleepModeModule.bundle"
        );

        return nil;
    }


    NSError *error = nil;

    BOOL loaded =
        [moduleBundle
            loadAndReturnError:&error];

    if (!loaded) {

        NSLog(
            @"[SleepMode] Không load được "
            @"SleepModeModule.bundle: %@",
            error
        );

        return nil;
    }


    Class moduleClass =
        NSClassFromString(@"SleepModeModule");

    if (!moduleClass) {

        NSLog(
            @"[SleepMode] Không tìm thấy "
            @"class SleepModeModule"
        );

        return nil;
    }


    id module =
        [[moduleClass alloc] init];

    if (!module) {

        NSLog(
            @"[SleepMode] Không tạo được "
            @"SleepModeModule"
        );

        return nil;
    }


    return module;
}

@end
