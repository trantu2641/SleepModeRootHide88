#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol CCSModuleProvider <NSObject>

- (NSUInteger)numberOfProvidedModules;

- (NSString *)identifierForModuleAtIndex:
    (NSUInteger)index;

- (NSString *)displayNameForModuleIdentifier:
    (NSString *)identifier;

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:
    (NSString *)identifier;

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:
    (NSString *)identifier;

- (id)moduleInstanceForModuleIdentifier:
    (NSString *)identifier;

- (UIImage *)settingsIconForModuleIdentifier:
    (NSString *)identifier;

- (NSUInteger)supportedDeviceFamiliesForModuleWithIdentifier:
    (NSString *)identifier;

- (id)requiredDeviceCapabilitiesForModuleWithIdentifier:
    (NSString *)identifier;

- (id)requiredDeviceIncapabilitiesForModuleWithIdentifier:
    (NSString *)identifier;

- (NSUInteger)visibilityPreferenceForModuleWithIdentifier:
    (NSString *)identifier;

@end


@interface SleepModeProvider :
    NSObject <CCSModuleProvider>
@end


@implementation SleepModeProvider

#pragma mark - Module list

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

    return @"com.trantu.sleepmode";
}


- (NSString *)displayNameForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return nil;
    }

    return @"Chế độ ngủ";
}


#pragma mark - Associated bundle

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return nil;
    }

    return @"com.trantu.sleepmode.module";
}


- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return nil;
    }

    return @"1.6.0";
}


#pragma mark - Module instance

- (id)moduleInstanceForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return nil;
    }

    NSString *bundlePath =
        @"/Library/ControlCenter/Bundles/"
         "SleepModeModule.bundle";

    NSBundle *bundle =
        [NSBundle bundleWithPath:bundlePath];

    if (bundle == nil) {
        NSLog(@"[SleepModeProvider] "
              @"SleepModeModule.bundle not found");

        return nil;
    }

    Class moduleClass =
        NSClassFromString(@"SleepModeModule");

    if (moduleClass == Nil) {
        NSLog(@"[SleepModeProvider] "
              @"SleepModeModule class not found");

        return nil;
    }

    id module =
        [[moduleClass alloc] init];

    NSLog(@"[SleepModeProvider] "
          @"SleepModeModule instance = %@",
          module);

    return module;
}


#pragma mark - Settings icon

- (UIImage *)settingsIconForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return nil;
    }

    NSBundle *providerBundle =
        [NSBundle bundleForClass:
            [self class]];

    NSString *iconPath =
        [providerBundle
            pathForResource:@"SleepModeProviderIcon"
                     ofType:@"png"];

    if (iconPath == nil) {
        return nil;
    }

    return [UIImage imageWithContentsOfFile:
        iconPath];
}


#pragma mark - Device

- (NSUInteger)supportedDeviceFamiliesForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return 0;
    }

    return 1;
}


- (id)requiredDeviceCapabilitiesForModuleWithIdentifier:
    (NSString *)identifier
{
    return nil;
}


- (id)requiredDeviceIncapabilitiesForModuleWithIdentifier:
    (NSString *)identifier
{
    return nil;
}


#pragma mark - Visibility

- (NSUInteger)visibilityPreferenceForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return 0;
    }

    return 0;
}

@end
