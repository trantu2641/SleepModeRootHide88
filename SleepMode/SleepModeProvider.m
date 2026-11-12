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


@implementation SleepModeProvider

#pragma mark - Provider

- (NSUInteger)numberOfProvidedModules
{
    return 1;
}


- (NSString *)identifierForModuleAtIndex:
    (NSUInteger)index
{
    if (index != 0) {
        return nil;
    }

    return SleepModeIdentifier;
}


- (NSString *)displayNameForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            SleepModeIdentifier]) {
        return nil;
    }

    return @"Chế độ ngủ";
}


#pragma mark - Device

- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            SleepModeIdentifier]) {
        return nil;
    }

    /*
     * iPhone + iPad
     */
    return [NSSet setWithObjects:
        @1,
        @2,
        nil];
}


#pragma mark - Icon

- (UIImage *)settingsIconForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            SleepModeIdentifier]) {
        return nil;
    }

    NSBundle *providerBundle =
        [NSBundle bundleForClass:[self class]];

    NSString *path =
        [providerBundle
            pathForResource:@"SleepModeProviderIcon"
                     ofType:@"png"];

    if (!path) {
        return nil;
    }

    return [UIImage imageWithContentsOfFile:path];
}


#pragma mark - Module

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
        return nil;
    }

    NSError *error = nil;

    BOOL loaded =
        [moduleBundle
            loadAndReturnError:&error];

    if (!loaded) {
        NSLog(
            @"[SleepMode] Không load được module: %@",
            error
        );

        return nil;
    }

    Class moduleClass =
        NSClassFromString(@"SleepModeModule");

    if (!moduleClass) {
        NSLog(
            @"[SleepMode] Không tìm thấy SleepModeModule"
        );

        return nil;
    }

    id module =
        [[moduleClass alloc] init];

    if (!module) {
        NSLog(
            @"[SleepMode] Không tạo được module"
        );

        return nil;
    }

    return module;
}

@end
