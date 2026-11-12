#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@protocol CCSModuleProvider
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

static NSString * const kSleepModeModuleIdentifier =
    @"com.trantu.sleepmode";

static NSString *SleepModeRootlessPath(NSString *path)
{
    NSString *rootlessPath =
        [@"/var/jb" stringByAppendingPathComponent:path];

    if ([[NSFileManager defaultManager]
            fileExistsAtPath:rootlessPath]) {

        return rootlessPath;
    }

    return path;
}

static NSBundle *SleepModeModuleBundle(void)
{
    NSString *path =
        SleepModeRootlessPath(
            @"/Library/ControlCenter/Bundles/SleepModeModule.bundle"
        );

    return [NSBundle bundleWithPath:path];
}

static NSBundle *SleepModeProviderBundle(void)
{
    NSString *path =
        SleepModeRootlessPath(
            @"/Library/ControlCenter/CCSupport_Providers/SleepModeProvider.bundle"
        );

    return [NSBundle bundleWithPath:path];
}

static UIImage *SleepModeSettingsIcon(void)
{
    NSBundle *bundle =
        SleepModeProviderBundle();

    if (!bundle) {
        return nil;
    }

    UIImage *image =
        [UIImage imageNamed:
            @"SleepModeProviderIcon"
            inBundle:bundle
            compatibleWithTraitCollection:nil];

    if (image) {
        return image;
    }

    return
        [UIImage imageNamed:
            @"SleepMode"
            inBundle:bundle
            compatibleWithTraitCollection:nil];
}

@interface SleepModeProvider : NSObject
@end

@implementation SleepModeProvider

#pragma mark - CCSModuleProvider

+ (void)load
{
    /*
     * CCSupport load provider bundle bằng
     * NSPrincipalClass.
     *
     * Không cần hook CCSupport.
     */
}

- (NSUInteger)numberOfProvidedModules
{
    return 1;
}

- (NSString *)identifierForModuleAtIndex:(NSUInteger)index
{
    if (index == 0) {
        return kSleepModeModuleIdentifier;
    }

    return nil;
}

- (NSString *)displayNameForModuleIdentifier:(NSString *)identifier
{
    if ([identifier
            isEqualToString:kSleepModeModuleIdentifier]) {

        return @"Chế độ ngủ";
    }

    return nil;
}

- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:(NSString *)identifier
{
    if ([identifier
            isEqualToString:kSleepModeModuleIdentifier]) {

        /*
         * iPhone + iPad
         */
        return [NSSet setWithObjects:
                    @1,
                    @2,
                    nil];
    }

    return nil;
}

- (NSSet *)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    if ([identifier
            isEqualToString:kSleepModeModuleIdentifier]) {

        return [NSSet setWithObject:@"arm64"];
    }

    return nil;
}

- (NSSet *)requiredDeviceIncapabilitiesForModuleWithIdentifier:(NSString *)identifier
{
    return nil;
}

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:(NSString *)identifier
{
    if ([identifier
            isEqualToString:kSleepModeModuleIdentifier]) {

        return @"com.trantu.sleepmode.module";
    }

    return nil;
}

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString *)identifier
{
    if ([identifier
            isEqualToString:kSleepModeModuleIdentifier]) {

        return @"1.0";
    }

    return nil;
}

- (NSUInteger)visibilityPreferenceForModuleWithIdentifier:(NSString *)identifier
{
    return 0;
}

#pragma mark - Settings icon

- (UIImage *)settingsIconForModuleIdentifier:(NSString *)identifier
{
    if (![identifier
            isEqualToString:kSleepModeModuleIdentifier]) {

        return nil;
    }

    return SleepModeSettingsIcon();
}

#pragma mark - Module instance

- (id)moduleInstanceForModuleIdentifier:(NSString *)identifier
{
    if (![identifier
            isEqualToString:kSleepModeModuleIdentifier]) {

        return nil;
    }

    NSBundle *bundle =
        SleepModeModuleBundle();

    if (!bundle) {

        NSLog(
            @"[SleepMode] CCS: SleepModeModule.bundle not found"
        );

        return nil;
    }

    NSError *error = nil;

    if (![bundle isLoaded]) {

        BOOL loaded =
            [bundle loadAndReturnError:&error];

        if (!loaded) {

            NSLog(
                @"[SleepMode] CCS: failed to load module bundle: %@",
                error
            );

            return nil;
        }
    }

    Class moduleClass =
        NSClassFromString(@"SleepModeModule");

    if (!moduleClass) {

        /*
         * Một số trường hợp class chưa được resolve
         * ngay sau bundle load.
         */
        [bundle load];

        moduleClass =
            NSClassFromString(@"SleepModeModule");
    }

    if (!moduleClass) {

        NSLog(
            @"[SleepMode] CCS: SleepModeModule class not found"
        );

        return nil;
    }

    id module =
        [[moduleClass alloc] init];

    if (!module) {

        NSLog(
            @"[SleepMode] CCS: failed to create SleepModeModule"
        );

        return nil;
    }

    /*
     * Đây là điều kiện CCSupport yêu cầu
     * trước khi tạo CCUIModuleInstance.
     */
    Protocol *contentModuleProtocol =
        objc_getProtocol("CCUIContentModule");

    if (contentModuleProtocol &&
        ![module conformsToProtocol:
            contentModuleProtocol]) {

        NSLog(
            @"[SleepMode] CCS: module does not conform to CCUIContentModule"
        );

        return nil;
    }

    NSLog(
        @"[SleepMode] CCS: SleepModeModule instance created"
    );

    return module;
}

@end
