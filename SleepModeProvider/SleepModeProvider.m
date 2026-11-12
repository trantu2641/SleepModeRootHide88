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


@interface SleepModeProvider : NSObject <CCSModuleProvider>
@end


@implementation SleepModeProvider

static NSString * const SleepModeIdentifier =
    @"com.trantu.sleepmode";


#pragma mark - Number Of Modules

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


#pragma mark - Supported Device Families

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
        nil];
}


#pragma mark - Required Capabilities

- (NSSet *)requiredDeviceCapabilitiesForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            SleepModeIdentifier]) {
        return nil;
    }

    return [NSSet set];
}


#pragma mark - Required Incapabilities

- (NSSet *)requiredDeviceIncapabilitiesForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            SleepModeIdentifier]) {
        return nil;
    }

    return [NSSet set];
}


#pragma mark - Associated Bundle Identifier

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            SleepModeIdentifier]) {
        return nil;
    }

    return @"com.trantu.sleepmode.module";
}


#pragma mark - Associated Bundle Version

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            SleepModeIdentifier]) {
        return nil;
    }

    return @"1.6.0";
}


#pragma mark - Visibility

- (NSUInteger)visibilityPreferenceForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            SleepModeIdentifier]) {
        return 0;
    }

    return 0;
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
        [bundle pathForResource:@"SleepModeProviderIcon"
                         ofType:@"png"];

    if (path == nil) {
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

    NSString *bundlePath =
        @"/Library/ControlCenter/Bundles/"
        @"SleepModeModule.bundle";

    NSBundle *bundle =
        [NSBundle bundleWithPath:bundlePath];

    if (bundle == nil) {
        NSLog(@"[SleepMode] SleepModeModule.bundle not found");

        return nil;
    }

    NSError *error = nil;

    if (![bundle isLoaded]) {

        BOOL loaded =
            [bundle loadAndReturnError:&error];

        if (!loaded) {

            NSLog(
                @"[SleepMode] Failed to load module bundle: %@",
                error
            );

            return nil;
        }
    }

    Class moduleClass =
        NSClassFromString(@"SleepModeModule");

    if (moduleClass == Nil) {

        NSLog(
            @"[SleepMode] SleepModeModule class not found"
        );

        return nil;
    }

    id module =
        [[moduleClass alloc] init];

    if (module == nil) {

        NSLog(
            @"[SleepMode] Failed to create SleepModeModule"
        );

        return nil;
    }

    return module;
}

@end
