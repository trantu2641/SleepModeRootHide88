#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface CCSModuleProvider : NSObject
@end


static NSString * const kSleepModeIdentifier =
    @"com.trantu.sleepmode";

static NSString * const kSleepModeBundleIdentifier =
    @"com.trantu.sleepmode.module";


@interface SleepModeProvider : CCSModuleProvider
@end


@implementation SleepModeProvider


#pragma mark - Provider

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


#pragma mark - Associated bundle

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    /*
     * Đây là CFBundleIdentifier của
     * /Library/ControlCenter/Bundles/SleepModeModule.bundle
     */
    return kSleepModeBundleIdentifier;
}


- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    return @"1.6.0";
}


#pragma mark - Device compatibility

- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
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


- (NSSet *)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    /*
     * Không giới hạn capability.
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
     * Provider nằm ở:
     *
     * /Library/ControlCenter/CCSupport_Providers/
     *     SleepModeProvider.bundle
     *
     * Module nằm ở:
     *
     * /Library/ControlCenter/Bundles/
     *     SleepModeModule.bundle
     *
     * Dùng đường dẫn tương đối từ Provider để tránh
     * hard-code đường dẫn RootHide không cần thiết.
     */

    NSBundle *providerBundle =
        [NSBundle bundleForClass:[self class]];

    NSString *providerPath =
        providerBundle.bundlePath;

    NSString *modulePath =
        [[providerPath
            stringByAppendingPathComponent:
                @"../../Bundles/SleepModeModule.bundle"]
            stringByStandardizingPath];


    NSBundle *moduleBundle =
        [NSBundle bundleWithPath:modulePath];

    if (moduleBundle == nil) {
        NSLog(@"[SleepMode] Cannot find module bundle: %@",
              modulePath);

        return nil;
    }


    NSError *error = nil;

    if (![moduleBundle isLoaded]) {

        BOOL loaded =
            [moduleBundle loadAndReturnError:&error];

        if (!loaded) {

            NSLog(@"[SleepMode] Cannot load module bundle: %@",
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
