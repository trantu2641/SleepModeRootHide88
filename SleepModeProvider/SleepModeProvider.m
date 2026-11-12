// SleepModeProvider.m
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Khai báo tối thiểu của CCSupport (nếu repo đã có header CCSModuleProvider.h thì dùng header đó)
@interface CCSModuleProvider : NSObject
@end

static NSString *const kSleepModeID = @"com.trantu.sleepmode";

@interface SleepModeProvider : CCSModuleProvider
@end

@implementation SleepModeProvider

- (NSUInteger)numberOfProvidedModules {
    return 1;
}

- (NSString *)identifierForModuleAtIndex:(NSUInteger)index {
    return index == 0 ? kSleepModeID : nil;
}

- (NSString *)displayNameForModuleIdentifier:(NSString *)identifier {
    return [identifier isEqualToString:kSleepModeID] ? @"Chế độ ngủ" : nil;
}

// === SỬA CHÍNH: phải trả về nil ===
// Bản cũ trả về "com.trantu.sleepmode.module" (không phải app) nên iOS ẩn module khỏi danh sách.
- (NSString *)associatedBundleIdentifierForModuleWithIdentifier:(NSString *)identifier {
    return nil;
}

- (NSString *)associatedBundleMinimumVersionForModuleWithIdentifier:(NSString *)identifier {
    return nil;
}

- (NSSet *)supportedDeviceFamiliesForModuleWithIdentifier:(NSString *)identifier {
    return [NSSet setWithObjects:@1, @2, nil]; // iPhone, iPad
}

- (NSSet *)requiredDeviceCapabilitiesForModuleWithIdentifier:(NSString *)identifier {
    return nil;
}

- (NSSet *)requiredDeviceIncapabilitiesForModuleWithIdentifier:(NSString *)identifier {
    return nil;
}

- (NSUInteger)visibilityPreferenceForModuleWithIdentifier:(NSString *)identifier {
    return [identifier isEqualToString:kSleepModeID] ? 1 : 0; // giữ nguyên như bản cũ
}

- (UIImage *)settingsIconForModuleIdentifier:(NSString *)identifier {
    NSBundle *me = [NSBundle bundleForClass:self.class];
    NSString *p = [me pathForResource:@"SleepModeProviderIcon" ofType:@"png"];
    if (!p) { NSLog(@"[SleepMode] Provider icon not found"); return nil; }
    return [UIImage imageWithContentsOfFile:p];
}

// === SỬA PHỤ: không dùng đường dẫn cứng /Library/... (hỏng trên RootHide) ===
- (id)moduleInstanceForModuleIdentifier:(NSString *)identifier {
    if (![identifier isEqualToString:kSleepModeID]) return nil;
    NSLog(@"[SleepMode] Loading SleepModeModule");

    // .../ControlCenter/CCSupport_Providers/SleepModeProvider.bundle  ->  .../ControlCenter/Bundles/SleepModeModule.bundle
    NSString *mine = [NSBundle bundleForClass:self.class].bundlePath;
    NSString *path = [[mine stringByAppendingPathComponent:@"../../Bundles/SleepModeModule.bundle"]
                      stringByStandardizingPath];

    NSBundle *bundle = [NSBundle bundleWithPath:path];
    if (!bundle) { NSLog(@"[SleepMode] SleepModeModule.bundle not found: %@", path); return nil; }

    if (!bundle.isLoaded) {
        NSError *err = nil;
        if (![bundle loadAndReturnError:&err]) {
            NSLog(@"[SleepMode] Module load failed: %@", err);
            return nil;
        }
    }
    Class cls = NSClassFromString(@"SleepModeModule");
    if (!cls) { NSLog(@"[SleepMode] SleepModeModule class not found"); return nil; }

    id module = [[cls alloc] init];
    if (!module) { NSLog(@"[SleepMode] SleepModeModule init failed"); return nil; }
    NSLog(@"[SleepMode] SleepModeModule loaded OK");
    return module;
}

@end
