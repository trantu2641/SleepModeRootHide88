#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol CCSModuleProvider <NSObject>
@required

- (NSString *)displayNameForModuleIdentifier:(NSString *)identifier;

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString *)identifier;

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:(NSString *)identifier;

- (NSString *)identifierForModuleAtIndex:(NSUInteger)index;

- (id)moduleInstanceForModuleIdentifier:(NSString *)identifier;

- (NSUInteger)numberOfProvidedModules;

- (NSSet *)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString *)identifier;

- (NSSet *)requiredDeviceIncapabilitiesForModuleWithIdentifier:(NSString *)identifier;

- (id)settingsIconForModuleIdentifier:(NSString *)identifier;

- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:(NSString *)identifier;

- (BOOL)visibilityPreferenceForModuleWithIdentifier:(NSString *)identifier;

@end


@interface SleepModeProvider : NSObject <CCSModuleProvider>
@end


@implementation SleepModeProvider

static NSString * const SleepModeIdentifier =
    @"com.trantu.sleepmode";

static NSString * const SleepModeModuleBundlePath =
    @"/Library/ControlCenter/Bundles/SleepModeModule.bundle";

static NSString * const SleepModeModuleClassName =
    @"SleepModeModule";


#pragma mark - Display Name

- (NSString *)displayNameForModuleIdentifier:(NSString *)identifier
{
    if ([identifier isEqualToString:SleepModeIdentifier]) {
        return @"Chế độ ngủ";
    }

    return nil;
}


#pragma mark - Minimum Version

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString *)identifier
{
    if ([identifier isEqualToString:SleepModeIdentifier]) {
        return @"1.6.0";
    }

    return nil;
}


#pragma mark - Bundle Identifier

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:(NSString *)identifier
{
    if ([identifier isEqualToString:SleepModeIdentifier]) {
        return @"com.trantu.sleepmode";
    }

    return nil;
}


#pragma mark - Identifier

- (NSString *)identifierForModuleAtIndex:(NSUInteger)index
{
    if (index == 0) {
        return SleepModeIdentifier;
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
    if (![identifier isEqualToString:SleepModeIdentifier]) {
        return nil;
    }

    Class moduleClass = NSClassFromString(SleepModeModuleClassName);

    if (moduleClass != Nil) {
        return [[moduleClass alloc] init];
    }

    NSBundle *bundle =
        [NSBundle bundleWithPath:SleepModeModuleBundlePath];

    if (bundle == nil) {
        NSLog(@"[SleepMode] Không tìm thấy SleepModeModule.bundle");
        return nil;
    }

    NSError *error = nil;

    BOOL loaded =
        [bundle loadAndReturnError:&error];

    if (!loaded) {
        NSLog(@"[SleepMode] Không thể load SleepModeModule.bundle: %@",
              error);

        return nil;
    }

    moduleClass =
        NSClassFromString(SleepModeModuleClassName);

    if (moduleClass == Nil) {
        NSLog(@"[SleepMode] Không tìm thấy class SleepModeModule");
        return nil;
    }

    return [[moduleClass alloc] init];
}


#pragma mark - Required Device Capabilities

- (NSSet *)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:SleepModeIdentifier]) {
        return nil;
    }

    return [NSSet setWithObjects:
            @"arm64",
            nil];
}


#pragma mark - Required Device Incapabilities

- (NSSet *)requiredDeviceIncapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:SleepModeIdentifier]) {
        return nil;
    }

    return [NSSet set];
}


#pragma mark - Settings Icon

- (id)settingsIconForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:SleepModeIdentifier]) {
        return nil;
    }

    NSString *path =
        [SleepModeModuleBundlePath
         stringByAppendingPathComponent:@"SleepModeProviderIcon.png"];

    UIImage *image =
        [UIImage imageWithContentsOfFile:path];

    return image;
}


#pragma mark - Supported Device Families

- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:SleepModeIdentifier]) {
        return nil;
    }

    return [NSSet setWithObjects:
            @1,
            nil];
}


#pragma mark - Visibility

- (BOOL)visibilityPreferenceForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:SleepModeIdentifier]) {
        return NO;
    }

    return YES;
}

@end
