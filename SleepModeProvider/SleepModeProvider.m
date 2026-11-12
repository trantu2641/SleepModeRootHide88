#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

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


@interface SleepModeProvider : NSObject <CCSModuleProvider>
@end


@implementation SleepModeProvider

static NSString * const kModuleIdentifier =
    @"com.trantu.sleepmode";

static NSString * const kModuleBundleIdentifier =
    @"com.trantu.sleepmode.module";

static NSString * const kModuleBundlePath =
    @"/Library/ControlCenter/Bundles/SleepModeModule.bundle";


#pragma mark - Provider

- (NSUInteger)numberOfProvidedModules
{
    return 1;
}


#pragma mark - Module identifier

- (NSString *)identifierForModuleAtIndex:(NSUInteger)index
{
    if (index != 0) {
        return nil;
    }

    return kModuleIdentifier;
}


#pragma mark - Display name

- (NSString *)displayNameForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    return @"Chế độ ngủ";
}


#pragma mark - Associated bundle

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    return kModuleBundleIdentifier;
}


#pragma mark - Minimum version

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    return @"1.6.0";
}


#pragma mark - Device families

- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    return [NSSet setWithObjects:
        @1,
        @2,
        nil];
}


#pragma mark - Required capabilities

- (NSSet *)requiredDeviceCapabilitiesForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    return [NSSet set];
}


#pragma mark - Required incapabilities

- (NSSet *)requiredDeviceIncapabilitiesForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    return [NSSet set];
}


#pragma mark - Visibility

- (NSUInteger)visibilityPreferenceForModuleWithIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return 0;
    }

    return 1;
}


#pragma mark - Settings icon

- (UIImage *)settingsIconForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    NSBundle *bundle =
        [NSBundle bundleForClass:[self class]];

    NSString *path =
        [bundle pathForResource:@"SleepModeProviderIcon"
                        ofType:@"png"];

    if (path == nil) {
        NSLog(@"[SleepMode] Provider icon not found");
        return nil;
    }

    return [UIImage imageWithContentsOfFile:path];
}


#pragma mark - Module instance

- (id)moduleInstanceForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    NSLog(@"[SleepMode] Loading SleepModeModule");

    NSBundle *moduleBundle =
        [NSBundle bundleWithPath:kModuleBundlePath];

    if (moduleBundle == nil) {
        NSLog(@"[SleepMode] SleepModeModule.bundle not found");
        return nil;
    }

    NSError *error = nil;

    if (![moduleBundle isLoaded]) {

        if (![moduleBundle loadAndReturnError:&error]) {

            NSLog(@"[SleepMode] Module load failed: %@",
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

        NSLog(@"[SleepMode] SleepModeModule init failed");

        return nil;
    }

    NSLog(@"[SleepMode] SleepModeModule loaded OK");

    return module;
}

@end
