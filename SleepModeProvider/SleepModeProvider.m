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

static NSString * const kProviderIdentifier =
    @"com.trantu.sleepmode.provider";

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


#pragma mark - Associated module bundle

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    return kModuleBundleIdentifier;
}


#pragma mark - Minimum module version

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    return @"1.6.0";
}


#pragma mark - Supported device families

- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    /*
     * iPhone + iPad
     */
    return [NSSet setWithObjects:
            @1,
            @2,
            nil];
}


#pragma mark - Required capabilities

- (NSSet *)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    return [NSSet setWithObjects:
            @"arm64",
            nil];
}


#pragma mark - Required incapabilities

- (NSSet *)requiredDeviceIncapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    return [NSSet set];
}


#pragma mark - Visibility

- (NSUInteger)visibilityPreferenceForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return 0;
    }

    /*
     * 1 = cho phép hiển thị trong danh sách module.
     */
    return 1;
}


#pragma mark - Settings icon

- (UIImage *)settingsIconForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    NSBundle *providerBundle =
        [NSBundle bundleForClass:[self class]];

    NSString *iconPath =
        [providerBundle pathForResource:@"SleepModeProviderIcon"
                                ofType:@"png"];

    if (iconPath == nil) {

        NSLog(@"[SleepMode] Provider:");
        NSLog(@"[SleepMode] Không tìm thấy SleepModeProviderIcon.png");

        return nil;
    }

    UIImage *image =
        [UIImage imageWithContentsOfFile:iconPath];

    return image;
}


#pragma mark - Module instance

- (id)moduleInstanceForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kModuleIdentifier]) {
        return nil;
    }

    NSLog(@"[SleepMode] Provider:");
    NSLog(@"[SleepMode] moduleInstanceForModuleIdentifier");

    NSLog(@"[SleepMode] Module path = %@",
          kModuleBundlePath);

    NSBundle *moduleBundle =
        [NSBundle bundleWithPath:kModuleBundlePath];

    if (moduleBundle == nil) {

        NSLog(@"[SleepMode] ERROR:");
        NSLog(@"[SleepMode] Không tìm thấy SleepModeModule.bundle");

        return nil;
    }

    NSLog(@"[SleepMode] Đã tìm thấy Module bundle");

    NSError *error = nil;

    if (![moduleBundle isLoaded]) {

        BOOL loaded =
            [moduleBundle loadAndReturnError:&error];

        if (!loaded) {

            NSLog(@"[SleepMode] ERROR:");
            NSLog(@"[SleepMode] Load Module thất bại");
            NSLog(@"[SleepMode] %@", error);

            return nil;
        }
    }

    NSLog(@"[SleepMode] Module bundle loaded");

    Class moduleClass =
        NSClassFromString(@"SleepModeModule");

    if (moduleClass == Nil) {

        NSLog(@"[SleepMode] ERROR:");
        NSLog(@"[SleepMode] Không tìm thấy class SleepModeModule");

        return nil;
    }

    NSLog(@"[SleepMode] Tìm thấy SleepModeModule");

    id module =
        [[moduleClass alloc] init];

    if (module == nil) {

        NSLog(@"[SleepMode] ERROR:");
        NSLog(@"[SleepMode] init SleepModeModule thất bại");

        return nil;
    }

    NSLog(@"[SleepMode] SleepModeModule init OK");

    return module;
}

@end
