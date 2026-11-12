#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol CCSModuleProvider <NSObject>
@optional

- (NSUInteger)numberOfProvidedModules;

- (NSString *)identifierForModuleAtIndex:(NSUInteger)index;

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


@interface SleepModeProvider : NSObject
<CCSModuleProvider>
@end


@implementation SleepModeProvider

#pragma mark - Provider

- (NSUInteger)numberOfProvidedModules
{
    return 1;
}


- (NSString *)identifierForModuleAtIndex:
    (NSUInteger)index
{
    if (index == 0) {
        return @"com.trantu.sleepmode";
    }

    return nil;
}


- (NSString *)displayNameForModuleIdentifier:
    (NSString *)identifier
{
    if ([identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return @"Chế độ ngủ";
    }

    return nil;
}


#pragma mark - Module Bundle

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:
    (NSString *)identifier
{
    if ([identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return @"com.trantu.sleepmode.module";
    }

    return nil;
}


- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:
    (NSString *)identifier
{
    if ([identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return @"1.6.0";
    }

    return nil;
}


#pragma mark - Module Instance

- (id)moduleInstanceForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return nil;
    }


    NSString *path =
        @"/Library/ControlCenter/Bundles/"
         "SleepModeModule.bundle";


    NSBundle *bundle =
        [NSBundle bundleWithPath:path];


    if (!bundle) {

        NSLog(@"[SleepModeProvider] "
              @"Không tìm thấy SleepModeModule.bundle");

        return nil;
    }


    if (![bundle isLoaded]) {

        BOOL loaded =
            [bundle load];

        if (!loaded) {

            NSLog(@"[SleepModeProvider] "
                  @"Không load được module bundle");

            return nil;
        }
    }


    Class moduleClass =
        NSClassFromString(@"SleepModeModule");


    if (!moduleClass) {

        NSLog(@"[SleepModeProvider] "
              @"Không tìm thấy class SleepModeModule");

        return nil;
    }


    id instance =
        [[moduleClass alloc] init];


    NSLog(@"[SleepModeProvider] "
          @"Đã tạo SleepModeModule: %@",
          instance);

    return instance;
}


#pragma mark - Settings Icon

- (UIImage *)settingsIconForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return nil;
    }


    NSBundle *bundle =
        [NSBundle bundleForClass:[self class]];


    NSString *path =
        [bundle pathForResource:
            @"SleepModeProviderIcon"
        ofType:@"png"];


    if (!path) {

        path =
            @"/Library/ControlCenter/"
             "CCSupport_Providers/"
             "SleepModeProvider.bundle/"
             "SleepModeProviderIcon.png";
    }


    UIImage *image =
        [UIImage imageWithContentsOfFile:path];


    return image;
}


#pragma mark - Device

- (NSUInteger)supportedDeviceFamiliesForModuleWithIdentifier:
    (NSString *)identifier
{
    if ([identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return 1;
    }

    return 0;
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
    if ([identifier isEqualToString:
            @"com.trantu.sleepmode"]) {

        return 0;
    }

    return 0;
}

@end
