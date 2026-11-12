#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#pragma mark - CCSupport Protocols

@protocol CCSModuleProvider <NSObject>

@required

- (NSString *)displayNameForModuleIdentifier:(NSString *)identifier;

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:(NSString *)identifier;

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString *)identifier;

- (NSUInteger)numberOfProvidedModules;

- (NSString *)identifierForModuleAtIndex:(NSUInteger)index;

- (id)moduleInstanceForModuleIdentifier:(NSString *)identifier;

- (id)settingsIconForModuleIdentifier:(NSString *)identifier;

- (NSArray *)supportedDeviceFamiliesForModuleWithIdentifier:(NSString *)identifier;

- (NSArray *)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString *)identifier;

- (NSArray *)requiredDeviceIncapabilitiesForModuleWithIdentifier:(NSString *)identifier;

- (NSInteger)visibilityPreferenceForModuleWithIdentifier:(NSString *)identifier;

@end

#pragma mark - Provider

@interface SleepModeProvider : NSObject <CCSModuleProvider>
@end

@implementation SleepModeProvider

#pragma mark - Constants

static NSString * const kModuleIdentifier =
    @"com.trantu.sleepmode.module";

static NSString * const kModuleClassName =
    @"SleepModeModule";

static NSString * const kModuleBundleIdentifier =
    @"com.trantu.sleepmode.module";

static NSString * const kModuleMinimumVersion =
    @"1.6.0";

static NSString * const kDisplayName =
    @"Chế độ ngủ";

#pragma mark - Display Name

- (NSString *)displayNameForModuleIdentifier:(NSString *)identifier
{
    if ([identifier isEqualToString:kModuleIdentifier]) {
        return kDisplayName;
    }

    return nil;
}

#pragma mark - Bundle Identifier

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:(NSString *)identifier
{
    if ([identifier isEqualToString:kModuleIdentifier]) {
        return kModuleBundleIdentifier;
    }

    return nil;
}

#pragma mark - Minimum Version

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString *)identifier
{
    if ([identifier isEqualToString:kModuleIdentifier]) {
        return kModuleMinimumVersion;
    }

    return nil;
}

#pragma mark - Number Of Modules

- (NSUInteger)numberOfProvidedModules
{
    return 1;
}

#pragma mark - Module Identifier

- (NSString *)identifierForModuleAtIndex:(NSUInteger)index
{
    if (index == 0) {
        return kModuleIdentifier;
    }

    return nil;
}

#pragma mark - Module Instance

- (id)moduleInstanceForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    /*
     CCSupport sẽ chịu trách nhiệm load associated bundle.
     
     Không:
     - bundleWithPath:
     - [bundle load]
     - dlopen()
     
     ở đây để tránh load bundle thủ công trong SpringBoard.
    */

    Class moduleClass = NSClassFromString(kModuleClassName);

    if (moduleClass == Nil) {
        return nil;
    }

    id module = [[moduleClass alloc] init];

    return module;
}

#pragma mark - Settings Icon

- (id)settingsIconForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    return nil;
}

#pragma mark - Device Families

- (NSArray *)supportedDeviceFamiliesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    /*
     iPhone + iPad
    */
    return @[
        @(1),
        @(2)
    ];
}

#pragma mark - Required Capabilities

- (NSArray *)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    return @[];
}

#pragma mark - Required Incapabilities

- (NSArray *)requiredDeviceIncapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    return @[];
}

#pragma mark - Visibility

- (NSInteger)visibilityPreferenceForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return -1;
    }

    /*
     0 = bình thường
    */
    return 0;
}

@end
