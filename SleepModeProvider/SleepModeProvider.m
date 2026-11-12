#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>


#pragma mark - CCSModuleProvider

@protocol CCSModuleProvider <NSObject>

@required

- (NSUInteger)numberOfProvidedModules;

- (NSString *)identifierForModuleAtIndex:(NSUInteger)index;

- (id)moduleInstanceForModuleIdentifier:(NSString *)identifier;

- (NSString *)displayNameForModuleIdentifier:(NSString *)identifier;

@optional

- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:(NSString *)identifier;

- (NSSet *)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString *)identifier;

- (NSSet *)requiredDeviceIncapabilitiesForModuleWithIdentifier:(NSString *)identifier;

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:(NSString *)identifier;

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString *)identifier;

- (NSUInteger)visibilityPreferenceForModuleWithIdentifier:(NSString *)identifier;

- (UIImage *)settingsIconForModuleIdentifier:(NSString *)identifier;

@end


#pragma mark - Provider

@interface SleepModeProvider : NSObject <CCSModuleProvider>
@end


@implementation SleepModeProvider


static NSString * const kSleepModeIdentifier =
    @"com.trantu.sleepmode";

static NSString * const kSleepModeBundleIdentifier =
    @"com.trantu.sleepmode.module";


#pragma mark - Required methods

- (NSUInteger)numberOfProvidedModules
{
    return 1;
}


- (NSString *)identifierForModuleAtIndex:(NSUInteger)index
{
    if (index != 0) {
        return nil;
    }

    return kSleepModeIdentifier;
}


- (NSString *)displayNameForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    return @"Chế độ ngủ";
}


#pragma mark - Bundle metadata

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    return kSleepModeBundleIdentifier;
}


- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    /*
     * SleepModeModule.bundle hiện tại dùng version 1.6.0
     */
    return @"1.6.0";
}


#pragma mark - Device compatibility

- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    return [NSSet setWithObjects:
        @1,
        @2,
        nil
    ];
}


- (NSSet *)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    /*
     * Không yêu cầu capability đặc biệt.
     */
    return [NSSet set];
}


- (NSSet *)requiredDeviceIncapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    return [NSSet set];
}


#pragma mark - Visibility

- (NSUInteger)visibilityPreferenceForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return 0;
    }

    return 0;
}


#pragma mark - Settings icon

- (UIImage *)settingsIconForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    NSBundle *bundle =
        [NSBundle bundleForClass:[self class]];

    NSString *iconPath =
        [bundle pathForResource:@"SleepModeProviderIcon"
                         ofType:@"png"];

    if (iconPath == nil) {
        return nil;
    }

    return [UIImage imageWithContentsOfFile:iconPath];
}


#pragma mark - Module instance

- (id)moduleInstanceForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    /*
     * Provider:
     *
     * /Library/ControlCenter/CCSupport_Providers/
     *     SleepModeProvider.bundle
     *
     * Module:
     *
     * /Library/ControlCenter/Bundles/
     *     SleepModeModule.bundle
     */

    NSString *modulePath =
        @"/Library/ControlCenter/Bundles/SleepModeModule.bundle";

    NSBundle *moduleBundle =
        [NSBundle bundleWithPath:modulePath];

    if (moduleBundle == nil) {

        NSLog(@"[SleepMode] Module bundle not found: %@",
              modulePath);

        return nil;
    }


    NSError *error = nil;

    if (![moduleBundle isLoaded]) {

        BOOL loaded =
            [moduleBundle loadAndReturnError:&error];

        if (!loaded) {

            NSLog(@"[SleepMode] Failed to load module: %@",
                  error);

            return nil;
        }
    }


    Class moduleClass =
        NSClassFromString(@"SleepModeModule");

    if (moduleClass == Nil) {

        NSLog(@"[SleepMode] SleepModeModule class not found");

        return nil;
    }


    id module =
        [[moduleClass alloc] init];

    if (module == nil) {

        NSLog(@"[SleepMode] Failed to create SleepModeModule");

        return nil;
    }


    return module;
}

@end
