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

static NSString * const kSleepModeIdentifier =
    @"com.trantu.sleepmode";

static NSString * const kSleepModeModuleIdentifier =
    @"com.trantu.sleepmode.module";

static NSString * const kSleepModeModulePath =
    @"/Library/ControlCenter/Bundles/SleepModeModule.bundle";


#pragma mark - Module count

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

    return kSleepModeIdentifier;
}


#pragma mark - Display name

- (NSString *)displayNameForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    return @"Chế độ ngủ";
}


#pragma mark - Associated bundle identifier

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    return kSleepModeModuleIdentifier;
}


#pragma mark - Minimum version

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    return @"1.6.0";
}


#pragma mark - Supported device families

- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    return [NSSet setWithObjects:
            @1,
            @2,
            nil];
}


#pragma mark - Required capabilities

- (NSSet *)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    return [NSSet setWithObjects:
            @"arm64",
            nil];
}


#pragma mark - Required incapabilities

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

    return 1;
}


#pragma mark - Settings icon

- (UIImage *)settingsIconForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    NSBundle *bundle =
        [NSBundle bundleForClass:[self class]];

    NSString *path =
        [bundle pathForResource:@"SleepModeProviderIcon"
                        ofType:@"png"];

    if (path == nil) {
        NSLog(@"[SleepMode] Provider icon không tồn tại");
        return nil;
    }

    return [UIImage imageWithContentsOfFile:path];
}


#pragma mark - Module instance

- (id)moduleInstanceForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    NSLog(@"[SleepMode] Provider: bắt đầu load Module");

    NSBundle *moduleBundle =
        [NSBundle bundleWithPath:kSleepModeModulePath];

    if (moduleBundle == nil) {

        NSLog(@"[SleepMode] Provider ERROR:");
        NSLog(@"[SleepMode] Không tìm thấy bundle:");
        NSLog(@"[SleepMode] %@",
              kSleepModeModulePath);

        return nil;
    }

    NSLog(@"[SleepMode] Provider: đã tìm thấy Module bundle");

    NSError *loadError = nil;

    if (![moduleBundle isLoaded]) {

        BOOL loaded =
            [moduleBundle loadAndReturnError:&loadError];

        if (!loaded) {

            NSLog(@"[SleepMode] Provider ERROR:");
            NSLog(@"[SleepMode] Không load được Module bundle");
            NSLog(@"[SleepMode] Error = %@",
                  loadError);

            return nil;
        }
    }

    NSLog(@"[SleepMode] Provider: Module bundle đã load");

    Class moduleClass =
        NSClassFromString(@"SleepModeModule");

    if (moduleClass == Nil) {

        NSLog(@"[SleepMode] Provider ERROR:");
        NSLog(@"[SleepMode] NSClassFromString(SleepModeModule) = nil");

        return nil;
    }

    NSLog(@"[SleepMode] Provider: tìm thấy class SleepModeModule");

    id module =
        [[moduleClass alloc] init];

    if (module == nil) {

        NSLog(@"[SleepMode] Provider ERROR:");
        NSLog(@"[SleepMode] Không thể init SleepModeModule");

        return nil;
    }

    NSLog(@"[SleepMode] Provider: SleepModeModule init OK");

    return module;
}

@end
