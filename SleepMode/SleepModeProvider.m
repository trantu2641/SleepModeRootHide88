#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@protocol CCSModuleProvider <NSObject>

@required

- (NSUInteger)numberOfProvidedModules;

- (NSString *)identifierForModuleAtIndex:
    (NSUInteger)index;

- (id)moduleInstanceForModuleIdentifier:
    (NSString *)identifier;

- (NSString *)displayNameForModuleIdentifier:
    (NSString *)identifier;

@optional

- (UIImage *)settingsIconForModuleIdentifier:
    (NSString *)identifier;

@end

static NSString * const kSleepModeModuleIdentifier =
    @"com.trantu.sleepmode";

static NSBundle *SleepModeModuleBundle(void)
{
    NSString *path =
        @"/Library/ControlCenter/Bundles/"
        @"SleepModeModule.bundle";

    return [NSBundle bundleWithPath:path];
}

@interface SleepModeProvider :
    NSObject <CCSModuleProvider>

@end

@implementation SleepModeProvider

- (NSUInteger)numberOfProvidedModules
{
    return 1;
}

- (NSString *)identifierForModuleAtIndex:
    (NSUInteger)index
{
    if (index != 0)
        return nil;

    return kSleepModeModuleIdentifier;
}

- (NSString *)displayNameForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            kSleepModeModuleIdentifier]) {
        return nil;
    }

    return @"Chế độ ngủ";
}

- (UIImage *)settingsIconForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            kSleepModeModuleIdentifier]) {
        return nil;
    }

    NSBundle *bundle =
        SleepModeModuleBundle();

    NSString *path =
        [bundle pathForResource:@"icon"
                         ofType:@"png"];

    if (!path)
        return nil;

    return [UIImage imageWithContentsOfFile:path];
}

- (id)moduleInstanceForModuleIdentifier:
    (NSString *)identifier
{
    if (![identifier isEqualToString:
            kSleepModeModuleIdentifier]) {
        return nil;
    }

    NSBundle *bundle =
        SleepModeModuleBundle();

    if (!bundle)
        return nil;

    NSError *error = nil;

    if (![bundle loadAndReturnError:&error]) {
        return nil;
    }

    Class moduleClass =
        NSClassFromString(@"SleepModeModule");

    if (!moduleClass)
        return nil;

    id module =
        [[moduleClass alloc] init];

    Protocol *protocol =
        objc_getProtocol("CCUIContentModule");

    if (protocol &&
        ![module conformsToProtocol:protocol]) {
        return nil;
    }

    return module;
}

@end
