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

static NSString * const kSleepModeModuleBundleIdentifier =
    @"com.trantu.sleepmode.module";

static NSString * const kSleepModeModuleBundlePath =
    @"/Library/ControlCenter/Bundles/SleepModeModule.bundle";

static NSString * const kSleepModeModuleClassName =
    @"SleepModeModule";


#pragma mark - Basic information

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


#pragma mark - Module metadata

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    /*
     * PHẢI trùng với:
     *
     * ControlCenter/SleepModeModule.bundle/Info.plist
     *
     * CFBundleIdentifier =
     * com.trantu.sleepmode.module
     */

    return kSleepModeModuleBundleIdentifier;
}


- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    return @"1.6.0";
}


- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    /*
     * 1 = iPhone
     * 2 = iPad
     */

    return [NSSet setWithObjects:@1, @2, nil];
}


- (NSSet *)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    return [NSSet setWithObjects:@"arm64", nil];
}


- (NSSet *)requiredDeviceIncapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeIdentifier]) {
        return nil;
    }

    return [NSSet set];
}


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

    /*
     * Icon của Provider nằm trong chính Provider bundle.
     *
     * Không lấy icon từ SleepModeModule.bundle.
     */

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    NSString *path =
        [bundle pathForResource:@"SleepModeProviderIcon"
                        ofType:@"png"];

    if (path == nil) {
        NSLog(@"[SleepMode] Không tìm thấy SleepModeProviderIcon.png");
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

    NSLog(@"[SleepMode] Đang load SleepModeModule.bundle");


    /*
     * Load bundle Module.
     */

    NSBundle *moduleBundle =
        [NSBundle bundleWithPath:kSleepModeModuleBundlePath];

    if (moduleBundle == nil) {

        NSLog(@"[SleepMode] ERROR: Không tìm thấy:");

        NSLog(@"[SleepMode] %@",
              kSleepModeModuleBundlePath);

        return nil;
    }


    /*
     * Nếu bundle chưa được load thì load nó.
     */

    if (![moduleBundle isLoaded]) {

        NSError *error = nil;

        BOOL loaded =
            [moduleBundle loadAndReturnError:&error];

        if (!loaded) {

            NSLog(@"[SleepMode] ERROR: Load Module thất bại: %@",
                  error);

            return nil;
        }
    }


    /*
     * Tìm class SleepModeModule.
     */

    Class moduleClass =
        NSClassFromString(kSleepModeModuleClassName);

    if (moduleClass == Nil) {

        NSLog(@"[SleepMode] ERROR: Không tìm thấy class SleepModeModule");

        return nil;
    }


    /*
     * Tạo instance.
     */

    id module =
        [[moduleClass alloc] init];

    if (module == nil) {

        NSLog(@"[SleepMode] ERROR: Không tạo được SleepModeModule");

        return nil;
    }


    NSLog(@"[SleepMode] SleepModeModule đã load thành công");

    return module;
}

@end
