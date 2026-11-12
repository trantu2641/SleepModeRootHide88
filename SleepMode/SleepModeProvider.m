#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol CCSModuleProvider <NSObject>
@end


@interface SleepModeProvider : NSObject
<CCSModuleProvider>
@end


@implementation SleepModeProvider

- (NSUInteger)numberOfProvidedModules
{
    return 1;
}


- (NSString *)identifierForModuleAtIndex:(NSUInteger)index
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
        return nil;
    }

    return [UIImage imageWithContentsOfFile:path];
}

@end
