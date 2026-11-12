#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - CCSModuleProvider

@protocol CCSModuleProvider

@required

- (NSUInteger)numberOfProvidedModules;

- (NSString *)identifierForModuleAtIndex:
    (NSUInteger)index;

- (id)moduleInstanceForModuleIdentifier:
    (NSString *)identifier;

- (NSString *)displayNameForModuleIdentifier:
    (NSString *)identifier;

@optional

- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:
    (NSString *)identifier;

- (NSSet *)requiredDeviceCapabilitiesForModuleWithIdentifier:
    (NSString *)identifier;

- (NSSet *)requiredDeviceIncapabilitiesForModuleWithIdentifier:
    (NSString *)identifier;

- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:
    (NSString *)identifier;

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:
    (NSString *)identifier;

- (NSUInteger)visibilityPreferenceForModuleWithIdentifier:
    (NSString *)identifier;

- (UIImage *)settingsIconForModuleIdentifier:
    (NSString *)identifier;

@end


#pragma mark - Constants

static NSString * const
    kSleepModeModuleIdentifier =
        @"com.trantu.sleepmode";


#pragma mark - Rootless path

static NSString *SleepModeRootlessPath(NSString *path)
{
    NSString *rootlessPath =
        [@"/var/jb"
            stringByAppendingPathComponent:path];

    if ([[NSFileManager defaultManager]
            fileExistsAtPath:rootlessPath]) {

        return rootlessPath;
    }

    return path;
}


#pragma mark - Module bundle

static NSBundle *SleepModeModuleBundle(void)
{
    NSString *path =
        SleepModeRootlessPath(
            @"/Library/ControlCenter/Bundles/"
             "SleepModeModule.bundle"
        );

    return [NSBundle bundleWithPath:path];
}


#pragma mark - Provider bundle

static NSBundle *SleepModeProviderBundle(void)
{
    NSString *path =
        SleepModeRootlessPath(
            @"/Library/ControlCenter/"
             "CCSupport_Providers/"
             "SleepModeProvider.bundle"
        );

    return [NSBundle bundleWithPath:path];
}


#pragma mark - Settings icon

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

    return [UIImage imageNamed:
        @"SleepMode"
          inBundle:bundle
          compatibleWithTraitCollection:nil];
}


#pragma mark - Provider

@interface SleepModeProvider : NSObject
@end


@implementation SleepModeProvider


#pragma mark - Runtime protocol

+ (void)load
{
    Protocol *protocol =
        objc_getProtocol("CCSModuleProvider");

    if (protocol != NULL) {

        if (!class_conformsToProtocol(
                self,
                protocol)) {

            class_addProtocol(
                self,
                protocol
            );
        }
    }
}


#pragma mark - Number of modules

- (NSUInteger)numberOfProvidedModules
{
    return 1;
}


#pragma mark - Module identifier

- (NSString *)identifierForModuleAtIndex:
    (NSUInteger)index
{
    if (index == 0) {

        return kSleepModeModuleIdentifier;
    }

    return nil;
}


#pragma mark - Display name

- (NSString *)displayNameForModuleIdentifier:
    (NSString *)identifier
{
    if ([identifier
            isEqualToString:
                kSleepModeModuleIdentifier]) {

        return @"Chế độ ngủ";
    }

    return nil;
}


#pragma mark - Device families

- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:
    (NSString *)identifier
{
    if ([identifier
            isEqualToString:
                kSleepModeModuleIdentifier]) {

        return [NSSet
            setWithObjects:
                @1,
                @2,
                nil];
    }

    return nil;
}


#pragma mark - Device capabilities

- (NSSet *)requiredDeviceCapabilitiesForModuleWithIdentifier:
    (NSString *)identifier
{
    if ([identifier
            isEqualToString:
                kSleepModeModuleIdentifier]) {

        return [NSSet
            setWithObject:@"arm64"];
    }

    return nil;
}


#pragma mark - Visibility

- (NSUInteger)visibilityPreferenceForModuleWithIdentifier:
    (NSString *)identifier
{
    return 0;
}


#pragma mark - Settings icon

- (UIImage *)settingsIconForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier
            isEqualToString:
                kSleepModeModuleIdentifier]) {

        return nil;
    }

    return SleepModeSettingsIcon();
}


#pragma mark - Module instance

- (id)moduleInstanceForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier
            isEqualToString:
                kSleepModeModuleIdentifier]) {

        return nil;
    }

    NSBundle *bundle =
        SleepModeModuleBundle();

    if (!bundle) {

        NSLog(
            @"[SleepMode] Provider: "
             "SleepModeModule.bundle not found"
        );

        return nil;
    }


    NSError *error = nil;

    if (![bundle isLoaded]) {

        BOOL loaded =
            [bundle loadAndReturnError:
                &error];

        if (!loaded) {

            NSLog(
                @"[SleepMode] Provider: "
                 "cannot load module bundle: %@",
                error
            );

            return nil;
        }
    }


    Class moduleClass =
        NSClassFromString(
            @"SleepModeModule"
        );

    if (moduleClass == Nil) {

        NSLog(
            @"[SleepMode] Provider: "
             "SleepModeModule class not found"
        );

        return nil;
    }


    id module =
        [[moduleClass alloc] init];

    NSLog(
        @"[SleepMode] Provider: "
         "module instance created"
    );

    return module;
}

@end
