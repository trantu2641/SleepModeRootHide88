#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>


#pragma mark - CCSupport Provider Protocol

/*
 * CCSupport dùng runtime để giao tiếp với provider.
 * Không import header CCSupport để tránh phụ thuộc SDK.
 */

@interface SleepModeProvider : NSObject
@end


@implementation SleepModeProvider


#pragma mark - Provider identity

- (NSArray *)moduleIdentifiers
{
    return @[
        @"com.trantu.sleepmode.module"
    ];
}


#pragma mark - Display name

- (NSString *)displayNameForModuleIdentifier:(NSString *)identifier
{
    if ([identifier isEqualToString:@"com.trantu.sleepmode.module"]) {
        return @"Chế độ ngủ";
    }

    return identifier;
}


#pragma mark - Settings icon

- (UIImage *)settingsIconForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:@"com.trantu.sleepmode.module"]) {
        return nil;
    }

    NSString *path =
        [[NSBundle bundleForClass:[self class]]
            pathForResource:@"SleepMode"
            ofType:@"png"];

    if (!path) {
        path =
            [[NSBundle bundleForClass:[self class]]
                pathForResource:@"icon"
                ofType:@"png"];
    }

    if (!path) {
        return nil;
    }

    return [UIImage imageWithContentsOfFile:path];
}


#pragma mark - Module class

- (Class)moduleClassForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:@"com.trantu.sleepmode.module"]) {
        return Nil;
    }

    Class moduleClass =
        NSClassFromString(@"SleepModeModule");

    return moduleClass;
}


#pragma mark - Module bundle

- (NSBundle *)bundleForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:@"com.trantu.sleepmode.module"]) {
        return nil;
    }

    NSString *path =
        @"/Library/ControlCenter/Bundles/SleepModeModule.bundle";

    return [NSBundle bundleWithPath:path];
}


#pragma mark - Module instance

- (id)moduleInstanceForModuleIdentifier:(NSString *)identifier
{
    if (![identifier isEqualToString:@"com.trantu.sleepmode.module"]) {
        return nil;
    }

    Class moduleClass =
        NSClassFromString(@"SleepModeModule");

    if (!moduleClass) {
        NSBundle *bundle =
            [self bundleForModuleIdentifier:identifier];

        if (bundle && ![bundle isLoaded]) {
            [bundle load];
        }

        moduleClass =
            NSClassFromString(@"SleepModeModule");
    }

    if (!moduleClass) {
        return nil;
    }

    return [[moduleClass alloc] init];
}


@end
