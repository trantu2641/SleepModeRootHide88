#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma mark - CCSupport Protocols

@protocol CCSModuleProvider <NSObject>
@optional

- (NSString *)displayNameForModuleIdentifier:(NSString *)identifier;

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString *)identifier;

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:(NSString *)identifier;

- (NSString *)identifierForModuleAtIndex:(NSUInteger)index;

- (id)moduleInstanceForModuleIdentifier:(NSString *)identifier;

- (NSUInteger)numberOfProvidedModules;

- (NSArray *)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString *)identifier;

- (NSArray *)requiredDeviceIncapabilitiesForModuleWithIdentifier:(NSString *)identifier;

- (id)settingsIconForModuleIdentifier:(NSString *)identifier;

- (NSArray *)supportedDeviceFamiliesForModuleWithIdentifier:(NSString *)identifier;

- (NSInteger)visibilityPreferenceForModuleWithIdentifier:(NSString *)identifier;

@end

#pragma mark - SleepModeProvider

@interface SleepModeProvider : NSObject <CCSModuleProvider>
@end

@implementation SleepModeProvider

static NSString * const kSleepModeIdentifier =
    @"com.trantu.sleepmode.module";

static NSString * const kSleepModeBundleIdentifier =
    @"com.trantu.sleepmode.module";

static NSString * const kSleepModeBundlePath =
    @"/Library/ControlCenter/Bundles/SleepModeModule.bundle";

static NSString * const kSleepModeClassName =
    @"SleepModeModule";

#pragma mark - Display Name

- (NSString *)displayNameForModuleIdentifier:(NSString *)identifier
{
    if ([identifier isEqualToString:kSleepModeIdentifier]) {
        return @"Chế độ ngủ";
    }

    return nil;
}

#pragma mark - Associated Bundle Version

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString *)identifier
{
    if ([identifier isEqualToString:kSleepModeIdentifier]) {
        return @"1.6.0";
    }

    return nil;
}

#pragma mark - Associated Bundle Identifier

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:(NSString *)identifier
{
    if ([identifier isEqualToString:kSleepModeIdentifier]) {
        return kSleepModeBundleIdentifier;
    }

    return nil;
}

#pragma mark - Identifier

- (NSString *)identifierForModuleAtIndex:(NSUInteger)index
{
    if (index == 0) {
        return kSleepModeIdentifier;
    }

    return nil;
}

#pragma mark - Number Of Modules

- (NSUInteger)numberOfProvidedModules
{
    return 1;
}

#pragma mark - Module Instance

- (id)moduleInstanceForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    NSBundle *bundle =
        [NSBundle bundleWithPath:kSleepModeBundlePath];

    if (bundle == nil) {
        return nil;
    }

    Class moduleClass =
        NSClassFromString(kSleepModeClassName);

    if (moduleClass == Nil) {

        BOOL loaded = [bundle load];

        if (!loaded) {
            return nil;
        }

        moduleClass =
            NSClassFromString(kSleepModeClassName);
    }

    if (moduleClass == Nil) {
        return nil;
    }

    id module =
        [[moduleClass alloc] init];

    return module;
}

#pragma mark - Required Device Capabilities

- (NSArray *)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    return @[];
}

#pragma mark - Required Device Incapabilities

- (NSArray *)requiredDeviceIncapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    return @[];
}

#pragma mark - Settings Icon

- (id)settingsIconForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    return nil;
}

#pragma mark - Supported Device Families

- (NSArray *)supportedDeviceFamiliesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    /*
     1 = iPhone
     2 = iPad
    */
    return @[
        @(1),
        @(2)
    ];
}

#pragma mark - Visibility

- (NSInteger)visibilityPreferenceForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return -1;
    }

    return 0;
}

@end
