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

static NSString * const kSleepModeModuleIdentifier =
    @"com.trantu.sleepmode";

static NSString * const kSleepModeModuleBundleIdentifier =
    @"com.trantu.sleepmode.module";

static NSString * const kSleepModeModuleBundlePath =
    @"/Library/ControlCenter/Bundles/SleepModeModule.bundle";


#pragma mark - Required CCSModuleProvider methods

- (NSUInteger)numberOfProvidedModules
{
    return 1;
}


- (NSString *)identifierForModuleAtIndex:(NSUInteger)index
{
    if (index != 0) {
        return nil;
    }

    return kSleepModeModuleIdentifier;
}


- (NSString *)displayNameForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeModuleIdentifier]) {
        return nil;
    }

    return @"Chế độ ngủ";
}


- (id)moduleInstanceForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeModuleIdentifier]) {
        return nil;
    }

    /*
     * CCSupport sẽ gọi phương thức này khi cần tạo module.
     * Không load module trong quá trình Provider discovery.
     */

    NSBundle *bundle =
        [NSBundle bundleWithPath:kSleepModeModuleBundlePath];

    if (bundle == nil) {
        return nil;
    }

    NSError *error = nil;

    if (![bundle isLoaded]) {

        BOOL loaded =
            [bundle loadAndReturnError:&error];

        if (!loaded) {
            return nil;
        }
    }

    Class moduleClass =
        NSClassFromString(@"SleepModeModule");

    if (moduleClass == Nil) {
        return nil;
    }

    id module =
        [[moduleClass alloc] init];

    return module;
}


#pragma mark - Module metadata

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeModuleIdentifier]) {
        return nil;
    }

    return kSleepModeModuleBundleIdentifier;
}


- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeModuleIdentifier]) {
        return nil;
    }

    /*
     * Module hiện tại:
     * CFBundleVersion = 1.6.1
     */
    return @"1.6.1";
}


#pragma mark - Device compatibility

- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeModuleIdentifier]) {
        return nil;
    }

    /*
     * 1 = iPhone
     * 2 = iPad
     */
    return [NSSet setWithObjects:
        @1,
        @2,
        nil
    ];
}


- (NSSet *)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeModuleIdentifier]) {
        return nil;
    }

    /*
     * Không yêu cầu capability đặc biệt.
     */
    return [NSSet set];
}


- (NSSet *)requiredDeviceIncapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeModuleIdentifier]) {
        return nil;
    }

    return [NSSet set];
}


#pragma mark - Visibility

- (NSUInteger)visibilityPreferenceForModuleWithIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeModuleIdentifier]) {
        return 0;
    }

    /*
     * Cho phép module xuất hiện trong danh sách module.
     */
    return 0;
}


#pragma mark - Settings icon

- (UIImage *)settingsIconForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:kSleepModeModuleIdentifier]) {
        return nil;
    }

    NSBundle *bundle =
        [NSBundle bundleForClass:[self class]];

    NSString *path =
        [bundle pathForResource:@"SleepModeProviderIcon"
                         ofType:@"png"];

    if (path == nil) {
        return nil;
    }

    return [UIImage imageWithContentsOfFile:path];
}

@end
