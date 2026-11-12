#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma mark - CCSModuleProvider

@protocol CCSModuleProvider <NSObject>

- (NSUInteger)numberOfProvidedModules;

- (NSString *)identifierForModuleAtIndex:
    (NSUInteger)index;

- (NSString *)displayNameForModuleIdentifier:
    (NSString *)identifier;

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:
    (NSString *)identifier;

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:
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


#pragma mark - SleepModeProvider

@interface SleepModeProvider : NSObject
<CCSModuleProvider>
@end


@implementation SleepModeProvider

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


- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return nil;
    }

    return @"1.6.0";
}


- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return nil;
    }

    return @"com.trantu.sleepmode.module";
}


- (id)moduleInstanceForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return nil;
    }

    /*
     * CCSupport sẽ liên kết module bundle
     * thông qua associatedBundleIdentifier.
     *
     * Không tự load bundle ở đây.
     */

    return nil;
}


- (UIImage *)settingsIconForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return nil;
    }

    NSBundle *bundle =
        [NSBundle bundleForClass:
            [self class]];

    NSString *path =
        [bundle pathForResource:
            @"SleepModeProviderIcon"
        ofType:@"png"];

    if (path == nil) {
        return nil;
    }

    return [UIImage imageWithContentsOfFile:
        path];
}


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
