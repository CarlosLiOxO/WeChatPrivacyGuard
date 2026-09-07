#import "AppDelegate.h"
#import "ApplicationCatalog.h"
#import "ApplicationVisibilityController.h"
#import "EnergyStateCoordinator.h"
#import "FaceRiskEvaluator.h"
#import "FaceJudgementModeStore.h"
#import "OwnerAwareFaceCoordinator.h"
#import "OwnerFaceEnrollmentWindowController.h"
#import "OwnerFaceProfileStore.h"
#import "PresenceDebouncer.h"
#import "ProtectionActionCoordinator.h"
#import "ProtectionModeStore.h"
#import "ProtectedApplicationStore.h"
#import "ProtectedWindowActivityMonitor.h"
#import "WindowPrivacyOverlayController.h"
#import <ServiceManagement/ServiceManagement.h>

static NSString *const WeChatBundleIdentifier = @"com.tencent.xinWeChat";
static NSString *const ProtectionDistanceDefaultsKey = @"protectionDistance";
static NSString *const ResponseSpeedDefaultsKey = @"responseSpeed";

typedef NS_ENUM(NSInteger, ResponseSpeed) {
    ResponseSpeedFast = 0,
    ResponseSpeedStandard = 1,
    ResponseSpeedSteady = 2,
};

static NSTimeInterval RequiredDurationForResponseSpeed(ResponseSpeed speed) {
    switch (speed) {
        case ResponseSpeedStandard:
            return 0.50;
        case ResponseSpeedSteady:
            return 0.80;
        case ResponseSpeedFast:
        default:
            return 0.25;
    }
}

@interface AppDelegate ()
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) CameraService *cameraService;
@property(nonatomic, strong) FaceRiskEvaluator *riskEvaluator;
@property(nonatomic, strong) PresenceDebouncer *debouncer;
@property(nonatomic) ProtectionDistance protectionDistance;
@property(nonatomic) ResponseSpeed responseSpeed;
@property(nonatomic, strong) NSMenu *protectionDistanceMenu;
@property(nonatomic, strong) NSMenu *responseSpeedMenu;
@property(nonatomic, strong) ProtectionModeStore *protectionModeStore;
@property(nonatomic, strong) ProtectionActionCoordinator *protectionCoordinator;
@property(nonatomic) ProtectionMode protectionMode;
@property(nonatomic, strong) NSMenu *protectionModeMenu;
@property(nonatomic, strong) FaceJudgementModeStore *faceJudgementModeStore;
@property(nonatomic) FaceJudgementMode faceJudgementMode;
@property(nonatomic, strong) NSMenu *faceJudgementModeMenu;
@property(nonatomic, strong) OwnerFaceProfileStore *ownerFaceProfileStore;
@property(nonatomic, strong, nullable) OwnerFaceProfile *ownerFaceProfile;
@property(nonatomic, strong, nullable) OwnerAwareFaceCoordinator *ownerAwareCoordinator;
@property(nonatomic, strong, nullable) OwnerFaceEnrollmentWindowController *enrollmentController;
@property(nonatomic, strong) NSMenuItem *clearOverlayItem;
@property(nonatomic, copy, nullable) NSString *protectionActionStatus;
@property(nonatomic) BOOL protectionEnabled;
@property(nonatomic) CameraServiceState cameraState;
@property(nonatomic, strong) NSMenuItem *stateMenuItem;
@property(nonatomic, strong) NSMenuItem *toggleProtectionItem;
@property(nonatomic, strong) NSMenuItem *loginItem;
@property(nonatomic, strong) NSMenu *extraApplicationMenu;
@property(nonatomic, strong) ApplicationCatalog *applicationCatalog;
@property(nonatomic, strong) ProtectedApplicationStore *applicationStore;
@property(nonatomic, strong, nullable) ProtectedApplication *selectedExtraApplication;
@property(nonatomic, copy) NSArray<ProtectedApplication *> *installedApplications;
@property(nonatomic) BOOL applicationScanInProgress;
@property(nonatomic, strong) ProtectedWindowActivityMonitor *windowActivityMonitor;
@property(nonatomic, strong) EnergyStateCoordinator *energyStateCoordinator;
@property(nonatomic) BOOL systemAwake;
@property(nonatomic) BOOL screenUnlocked;
@property(nonatomic) BOOL cameraRequestedToRun;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSNumber *storedDistance = [defaults objectForKey:ProtectionDistanceDefaultsKey];
    NSNumber *storedSpeed = [defaults objectForKey:ResponseSpeedDefaultsKey];
    NSInteger distanceValue = storedDistance ? storedDistance.integerValue : ProtectionDistanceStandard;
    NSInteger speedValue = storedSpeed ? storedSpeed.integerValue : ResponseSpeedFast;
    self.protectionDistance = distanceValue >= ProtectionDistanceNear && distanceValue <= ProtectionDistanceFar
        ? distanceValue : ProtectionDistanceStandard;
    self.responseSpeed = speedValue >= ResponseSpeedFast && speedValue <= ResponseSpeedSteady
        ? speedValue : ResponseSpeedFast;

    self.cameraService = [[CameraService alloc] init];
    self.cameraService.delegate = self;
    self.riskEvaluator = [[FaceRiskEvaluator alloc] initWithProtectionDistance:self.protectionDistance];
    self.debouncer = [[PresenceDebouncer alloc]
        initWithRequiredDuration:RequiredDurationForResponseSpeed(self.responseSpeed)];
    self.applicationCatalog = [[ApplicationCatalog alloc] init];
    self.applicationStore = [[ProtectedApplicationStore alloc]
        initWithUserDefaults:NSUserDefaults.standardUserDefaults];
    self.protectionModeStore = [[ProtectionModeStore alloc] initWithUserDefaults:defaults];
    self.protectionMode = self.protectionModeStore.protectionMode;
    self.faceJudgementModeStore = [[FaceJudgementModeStore alloc] initWithUserDefaults:defaults];
    self.ownerFaceProfileStore = [[OwnerFaceProfileStore alloc]
        initWithKeychainClient:[[SystemOwnerFaceKeychainClient alloc] init]];
    self.ownerFaceProfile = [self.ownerFaceProfileStore loadProfileAndReturnError:nil];
    self.faceJudgementMode = self.faceJudgementModeStore.faceJudgementMode;
    if (self.faceJudgementMode == FaceJudgementModeUnknownPerson && !self.ownerFaceProfile) {
        self.faceJudgementMode = FaceJudgementModeSecondPerson;
        [self.faceJudgementModeStore saveFaceJudgementMode:self.faceJudgementMode];
    }
    WindowPrivacyOverlayController *overlayController = [[WindowPrivacyOverlayController alloc] init];
    self.protectionCoordinator = [[ProtectionActionCoordinator alloc]
        initWithOverlayController:overlayController hideHandler:^BOOL(NSString *bundleIdentifier) {
            return [ApplicationVisibilityController hideApplicationWithBundleIdentifier:bundleIdentifier];
        }];
    self.protectionCoordinator.protectionMode = self.protectionMode;
    __weak typeof(self) weakSelf = self;
    self.protectionCoordinator.stateDidChange = ^(ProtectionActionState state,
                                                   NSString *statusMessage,
                                                   BOOL canClearOverlay) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.protectionActionStatus = statusMessage;
        self.clearOverlayItem.enabled = canClearOverlay;
        [self updateInterfaceForState:self.cameraState message:nil];
    };
    self.selectedExtraApplication = [self.applicationStore selectedApplication];
    self.installedApplications = @[];

    NSNumber *storedProtection = [NSUserDefaults.standardUserDefaults objectForKey:@"protectionEnabled"];
    self.protectionEnabled = storedProtection ? storedProtection.boolValue : YES;
    [self configureStatusItem];
    if (self.faceJudgementMode == FaceJudgementModeUnknownPerson) {
        [self activateUnknownPersonModeShowingErrors:YES];
    }
    [self configureDefaultLoginItemIfNeeded];
    [self refreshApplicationCatalog:nil];
    [self configureEnergyManagement];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self.windowActivityMonitor stopMonitoring];
    [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self];
    [NSDistributedNotificationCenter.defaultCenter removeObserver:self];
    [self.protectionCoordinator stop];
    [self.cameraService stop];
}

- (void)configureEnergyManagement {
    self.systemAwake = YES;
    self.screenUnlocked = YES;
    self.energyStateCoordinator = [[EnergyStateCoordinator alloc] init];
    self.windowActivityMonitor = [[ProtectedWindowActivityMonitor alloc]
        initWithProtectedBundleIdentifiers:[self protectedBundleIdentifiers]];
    __weak typeof(self) weakSelf = self;
    self.windowActivityMonitor.visibilityDidChange = ^(ProtectedWindowVisibility visibility) {
        (void)visibility;
        [weakSelf reevaluateEnergyState];
    };

    NSNotificationCenter *workspaceCenter = NSWorkspace.sharedWorkspace.notificationCenter;
    [workspaceCenter addObserver:self selector:@selector(systemWillPause:)
                            name:NSWorkspaceWillSleepNotification object:nil];
    [workspaceCenter addObserver:self selector:@selector(systemDidResume:)
                            name:NSWorkspaceDidWakeNotification object:nil];
    [workspaceCenter addObserver:self selector:@selector(systemWillPause:)
                            name:NSWorkspaceScreensDidSleepNotification object:nil];
    [workspaceCenter addObserver:self selector:@selector(systemDidResume:)
                            name:NSWorkspaceScreensDidWakeNotification object:nil];

    NSDistributedNotificationCenter *distributedCenter = NSDistributedNotificationCenter.defaultCenter;
    [distributedCenter addObserver:self selector:@selector(screenDidLock:)
                              name:@"com.apple.screenIsLocked" object:nil
                suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    [distributedCenter addObserver:self selector:@selector(screenDidUnlock:)
                              name:@"com.apple.screenIsUnlocked" object:nil
                suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];

    [self.windowActivityMonitor checkNow];
    [self reevaluateEnergyState];
}

- (void)systemWillPause:(NSNotification *)notification {
    (void)notification;
    self.systemAwake = NO;
    [self reevaluateEnergyState];
}

- (void)systemDidResume:(NSNotification *)notification {
    (void)notification;
    self.systemAwake = YES;
    [self.windowActivityMonitor checkNow];
    [self reevaluateEnergyState];
}

- (void)screenDidLock:(NSNotification *)notification {
    (void)notification;
    self.screenUnlocked = NO;
    [self reevaluateEnergyState];
}

- (void)screenDidUnlock:(NSNotification *)notification {
    (void)notification;
    self.screenUnlocked = YES;
    [self.windowActivityMonitor checkNow];
    [self reevaluateEnergyState];
}

- (void)reevaluateEnergyState {
    if (!self.energyStateCoordinator || !self.windowActivityMonitor) return;
    [self.energyStateCoordinator
        updateWithProtectionEnabled:self.protectionEnabled
        systemAvailable:(self.systemAwake && self.screenUnlocked)
        enrollmentActive:self.enrollmentController != nil
        windowVisibility:self.windowActivityMonitor.currentVisibility];

    NSTimeInterval monitoringInterval = self.energyStateCoordinator.windowMonitoringInterval;
    if (monitoringInterval > 0) {
        [self.windowActivityMonitor startMonitoringWithInterval:monitoringInterval];
    } else {
        [self.windowActivityMonitor stopMonitoring];
    }

    BOOL shouldRun = self.energyStateCoordinator.cameraShouldRun;
    if (shouldRun != self.cameraRequestedToRun) {
        self.cameraRequestedToRun = shouldRun;
        if (shouldRun) {
            [self.cameraService start];
        } else {
            [self.debouncer reset];
            [self.ownerAwareCoordinator reset];
            [self.protectionCoordinator stop];
            [self.cameraService stop];
        }
    } else if (shouldRun && self.cameraState == CameraServiceStateStopped) {
        [self.cameraService start];
    }
    [self updateInterfaceForState:self.cameraState message:nil];
}

- (void)configureStatusItem {
    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.toolTip = @"微信隐私守卫";

    NSMenu *menu = [[NSMenu alloc] init];
    self.stateMenuItem = [[NSMenuItem alloc] initWithTitle:@"正在启动…" action:nil keyEquivalent:@""];
    self.stateMenuItem.enabled = NO;
    [menu addItem:self.stateMenuItem];
    [menu addItem:NSMenuItem.separatorItem];

    self.toggleProtectionItem = [[NSMenuItem alloc] initWithTitle:@"暂停保护"
                                                           action:@selector(toggleProtection:)
                                                    keyEquivalent:@""];
    self.toggleProtectionItem.target = self;
    self.toggleProtectionItem.state = self.protectionEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:self.toggleProtectionItem];

    NSMenuItem *testItem = [[NSMenuItem alloc] initWithTitle:@"立即测试保护"
                                                      action:@selector(testProtection:)
                                               keyEquivalent:@""];
    testItem.target = self;
    [menu addItem:testItem];

    NSMenuItem *openItem = [[NSMenuItem alloc] initWithTitle:@"打开微信"
                                                      action:@selector(openWeChat:)
                                               keyEquivalent:@""];
    openItem.target = self;
    [menu addItem:openItem];

    NSMenuItem *extraApplicationItem = [[NSMenuItem alloc] initWithTitle:@"额外保护应用"
                                                                  action:nil
                                                           keyEquivalent:@""];
    self.extraApplicationMenu = [[NSMenu alloc] initWithTitle:@"额外保护应用"];
    self.extraApplicationMenu.delegate = self;
    extraApplicationItem.submenu = self.extraApplicationMenu;
    [menu addItem:extraApplicationItem];
    [self rebuildExtraApplicationMenu];

    NSMenuItem *modeItem = [[NSMenuItem alloc] initWithTitle:@"保护方式"
                                                      action:nil
                                               keyEquivalent:@""];
    self.protectionModeMenu = [[NSMenu alloc] initWithTitle:@"保护方式"];
    modeItem.submenu = self.protectionModeMenu;
    [menu addItem:modeItem];
    [self rebuildProtectionModeMenu];

    NSMenuItem *judgementItem = [[NSMenuItem alloc] initWithTitle:@"判断方式"
                                                          action:nil
                                                   keyEquivalent:@""];
    self.faceJudgementModeMenu = [[NSMenu alloc] initWithTitle:@"判断方式"];
    judgementItem.submenu = self.faceJudgementModeMenu;
    [menu addItem:judgementItem];
    [self rebuildFaceJudgementModeMenu];

    self.clearOverlayItem = [[NSMenuItem alloc] initWithTitle:@"立即解除遮罩"
                                                        action:@selector(clearPrivacyOverlay:)
                                                 keyEquivalent:@""];
    self.clearOverlayItem.target = self;
    self.clearOverlayItem.enabled = NO;
    [menu addItem:self.clearOverlayItem];

    NSMenuItem *distanceItem = [[NSMenuItem alloc] initWithTitle:@"保护距离"
                                                          action:nil
                                                   keyEquivalent:@""];
    self.protectionDistanceMenu = [[NSMenu alloc] initWithTitle:@"保护距离"];
    distanceItem.submenu = self.protectionDistanceMenu;
    [menu addItem:distanceItem];
    [self rebuildProtectionDistanceMenu];

    NSMenuItem *speedItem = [[NSMenuItem alloc] initWithTitle:@"响应速度"
                                                       action:nil
                                                keyEquivalent:@""];
    self.responseSpeedMenu = [[NSMenu alloc] initWithTitle:@"响应速度"];
    speedItem.submenu = self.responseSpeedMenu;
    [menu addItem:speedItem];
    [self rebuildResponseSpeedMenu];

    [menu addItem:NSMenuItem.separatorItem];

    self.loginItem = [[NSMenuItem alloc] initWithTitle:@"登录时启动"
                                                 action:@selector(toggleLoginItem:)
                                          keyEquivalent:@""];
    self.loginItem.target = self;
    self.loginItem.state = SMAppService.mainAppService.status == SMAppServiceStatusEnabled
        ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:self.loginItem];

    NSMenuItem *privacyItem = [[NSMenuItem alloc] initWithTitle:@"摄像头隐私设置…"
                                                         action:@selector(openCameraSettings:)
                                                  keyEquivalent:@""];
    privacyItem.target = self;
    [menu addItem:privacyItem];
    [menu addItem:NSMenuItem.separatorItem];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"退出微信隐私守卫"
                                                      action:@selector(quit:)
                                               keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];
    self.statusItem.menu = menu;
    [self updateInterfaceForState:CameraServiceStateStopped message:nil];
}

- (void)configureDefaultLoginItemIfNeeded {
    if ([NSUserDefaults.standardUserDefaults boolForKey:@"didConfigureLoginItem"]) return;
    NSError *error = nil;
    if (SMAppService.mainAppService.status != SMAppServiceStatusEnabled &&
        ![SMAppService.mainAppService registerAndReturnError:&error]) {
        [self showAlertWithTitle:@"无法启用登录时启动" message:error.localizedDescription];
    }
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"didConfigureLoginItem"];
    self.loginItem.state = SMAppService.mainAppService.status == SMAppServiceStatusEnabled
        ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)toggleProtection:(id)sender {
    self.protectionEnabled = !self.protectionEnabled;
    [NSUserDefaults.standardUserDefaults setBool:self.protectionEnabled forKey:@"protectionEnabled"];
    self.toggleProtectionItem.state = self.protectionEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [self.debouncer reset];
    if (self.protectionEnabled) {
        [self.windowActivityMonitor checkNow];
    } else {
        [self.protectionCoordinator stop];
    }
    [self reevaluateEnergyState];
}

- (void)testProtection:(id)sender {
    [self.protectionCoordinator testProtectionAtTime:NSProcessInfo.processInfo.systemUptime
                                    bundleIdentifiers:[self protectedBundleIdentifiers]];
}

- (void)clearPrivacyOverlay:(id)sender {
    [self.protectionCoordinator clearOverlay];
}

- (void)openWeChat:(id)sender {
    [ApplicationVisibilityController openOrActivateBundleIdentifier:WeChatBundleIdentifier];
}

- (void)menuWillOpen:(NSMenu *)menu {
    if (menu == self.extraApplicationMenu) {
        [self refreshApplicationCatalog:nil];
    }
}

- (void)refreshApplicationCatalog:(id)sender {
    if (self.applicationScanInProgress) return;
    self.applicationScanInProgress = YES;
    [self rebuildExtraApplicationMenu];

    ApplicationCatalog *catalog = self.applicationCatalog;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<ProtectedApplication *> *applications = [catalog scanApplications];
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.installedApplications = applications;
            self.applicationScanInProgress = NO;
            [self reconcileSelectedApplication];
            [self rebuildExtraApplicationMenu];
        });
    });
}

- (void)reconcileSelectedApplication {
    if (!self.selectedExtraApplication) return;
    for (ProtectedApplication *application in self.installedApplications) {
        if ([application.bundleIdentifier isEqualToString:self.selectedExtraApplication.bundleIdentifier]) {
            self.selectedExtraApplication = application;
            [self.applicationStore saveApplication:application];
            return;
        }
    }
}

- (void)rebuildExtraApplicationMenu {
    if (!self.extraApplicationMenu) return;
    [self.extraApplicationMenu removeAllItems];

    NSMenuItem *fixedWeChatItem = [[NSMenuItem alloc] initWithTitle:@"微信（固定保护）"
                                                             action:nil
                                                      keyEquivalent:@""];
    fixedWeChatItem.enabled = NO;
    fixedWeChatItem.state = NSControlStateValueOn;
    NSURL *weChatURL = [NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:WeChatBundleIdentifier];
    if (weChatURL) {
        NSImage *icon = [NSWorkspace.sharedWorkspace iconForFile:weChatURL.path];
        icon.size = NSMakeSize(16, 16);
        fixedWeChatItem.image = icon;
    }
    [self.extraApplicationMenu addItem:fixedWeChatItem];

    BOOL selectionAvailable = NO;
    if (self.selectedExtraApplication) {
        for (ProtectedApplication *application in self.installedApplications) {
            if ([application.bundleIdentifier isEqualToString:self.selectedExtraApplication.bundleIdentifier]) {
                selectionAvailable = YES;
                break;
            }
        }
    }
    NSString *currentTitle = @"当前：未选择";
    if (self.selectedExtraApplication) {
        currentTitle = selectionAvailable || self.applicationScanInProgress
            ? [NSString stringWithFormat:@"当前：%@", self.selectedExtraApplication.displayName]
            : [NSString stringWithFormat:@"当前：应用不可用（%@）", self.selectedExtraApplication.displayName];
    }
    NSMenuItem *currentItem = [[NSMenuItem alloc] initWithTitle:currentTitle action:nil keyEquivalent:@""];
    currentItem.enabled = NO;
    [self.extraApplicationMenu addItem:currentItem];

    NSMenuItem *clearItem = [[NSMenuItem alloc] initWithTitle:@"取消额外保护"
                                                      action:@selector(clearExtraApplication:)
                                               keyEquivalent:@""];
    clearItem.target = self;
    clearItem.enabled = self.selectedExtraApplication != nil;
    [self.extraApplicationMenu addItem:clearItem];
    [self.extraApplicationMenu addItem:NSMenuItem.separatorItem];

    if (self.installedApplications.count == 0) {
        NSMenuItem *emptyItem = [[NSMenuItem alloc]
            initWithTitle:(self.applicationScanInProgress ? @"正在扫描应用…" : @"未找到可选择的应用")
                   action:nil
            keyEquivalent:@""];
        emptyItem.enabled = NO;
        [self.extraApplicationMenu addItem:emptyItem];
    } else {
        for (ProtectedApplication *application in self.installedApplications) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:application.displayName
                                                          action:@selector(selectExtraApplication:)
                                                   keyEquivalent:@""];
            item.target = self;
            item.representedObject = application;
            item.image = application.icon;
            item.state = [application.bundleIdentifier isEqualToString:self.selectedExtraApplication.bundleIdentifier]
                ? NSControlStateValueOn : NSControlStateValueOff;
            [self.extraApplicationMenu addItem:item];
        }
    }

    [self.extraApplicationMenu addItem:NSMenuItem.separatorItem];
    NSMenuItem *refreshItem = [[NSMenuItem alloc]
        initWithTitle:(self.applicationScanInProgress ? @"正在刷新…" : @"刷新应用列表")
               action:@selector(refreshApplicationCatalog:)
        keyEquivalent:@""];
    refreshItem.target = self;
    refreshItem.enabled = !self.applicationScanInProgress;
    [self.extraApplicationMenu addItem:refreshItem];
}

- (void)selectExtraApplication:(NSMenuItem *)sender {
    ProtectedApplication *application = sender.representedObject;
    if (![application isKindOfClass:ProtectedApplication.class]) return;
    self.selectedExtraApplication = application;
    [self.applicationStore saveApplication:application];
    [self.protectionCoordinator updateBundleIdentifiers:[self protectedBundleIdentifiers]];
    [self.windowActivityMonitor updateProtectedBundleIdentifiers:[self protectedBundleIdentifiers]];
    [self reevaluateEnergyState];
    [self rebuildExtraApplicationMenu];
}

- (void)clearExtraApplication:(id)sender {
    self.selectedExtraApplication = nil;
    [self.applicationStore clear];
    [self.protectionCoordinator updateBundleIdentifiers:[self protectedBundleIdentifiers]];
    [self.windowActivityMonitor updateProtectedBundleIdentifiers:[self protectedBundleIdentifiers]];
    [self reevaluateEnergyState];
    [self rebuildExtraApplicationMenu];
}

- (NSSet<NSString *> *)protectedBundleIdentifiers {
    NSMutableSet<NSString *> *identifiers = [NSMutableSet setWithObject:WeChatBundleIdentifier];
    if (self.selectedExtraApplication.bundleIdentifier.length > 0) {
        [identifiers addObject:self.selectedExtraApplication.bundleIdentifier];
    }
    return identifiers.copy;
}

- (void)rebuildProtectionModeMenu {
    [self.protectionModeMenu removeAllItems];
    NSArray<NSDictionary *> *options = @[
        @{@"title": @"隐藏窗口", @"value": @(ProtectionModeHideWindows)},
        @{@"title": @"隐私遮罩", @"value": @(ProtectionModePrivacyOverlay)},
    ];
    for (NSDictionary *option in options) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:option[@"title"]
                                                      action:@selector(selectProtectionMode:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = option[@"value"];
        item.state = [option[@"value"] integerValue] == self.protectionMode
            ? NSControlStateValueOn : NSControlStateValueOff;
        [self.protectionModeMenu addItem:item];
    }
}

- (void)selectProtectionMode:(NSMenuItem *)sender {
    NSNumber *value = sender.representedObject;
    if (![value isKindOfClass:NSNumber.class]) return;
    self.protectionMode = value.integerValue == ProtectionModePrivacyOverlay
        ? ProtectionModePrivacyOverlay : ProtectionModeHideWindows;
    [self.protectionModeStore saveProtectionMode:self.protectionMode];
    self.protectionCoordinator.protectionMode = self.protectionMode;
    [self.debouncer reset];
    [self rebuildProtectionModeMenu];
}

- (void)rebuildFaceJudgementModeMenu {
    if (!self.faceJudgementModeMenu) return;
    [self.faceJudgementModeMenu removeAllItems];
    NSArray<NSDictionary *> *options = @[
        @{@"title": @"第二人判断", @"value": @(FaceJudgementModeSecondPerson)},
        @{@"title": @"陌生人判断", @"value": @(FaceJudgementModeUnknownPerson)},
    ];
    for (NSDictionary *option in options) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:option[@"title"]
                                                      action:@selector(selectFaceJudgementMode:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = option[@"value"];
        item.state = [option[@"value"] integerValue] == self.faceJudgementMode
            ? NSControlStateValueOn : NSControlStateValueOff;
        [self.faceJudgementModeMenu addItem:item];
    }
    [self.faceJudgementModeMenu addItem:NSMenuItem.separatorItem];
    NSMenuItem *enroll = [[NSMenuItem alloc]
        initWithTitle:(self.ownerFaceProfile ? @"重新录入本人面容…" : @"录入本人面容…")
               action:@selector(beginOwnerFaceEnrollment:) keyEquivalent:@""];
    enroll.target = self;
    [self.faceJudgementModeMenu addItem:enroll];
    NSMenuItem *delete = [[NSMenuItem alloc] initWithTitle:@"删除本人面容"
                                                    action:@selector(deleteOwnerFaceProfile:)
                                             keyEquivalent:@""];
    delete.target = self;
    delete.enabled = self.ownerFaceProfile != nil;
    [self.faceJudgementModeMenu addItem:delete];
}

- (void)selectFaceJudgementMode:(NSMenuItem *)sender {
    FaceJudgementMode requested = [sender.representedObject integerValue] == FaceJudgementModeUnknownPerson
        ? FaceJudgementModeUnknownPerson : FaceJudgementModeSecondPerson;
    if (requested == FaceJudgementModeUnknownPerson && !self.ownerFaceProfile) {
        [self beginOwnerFaceEnrollment:nil];
        return;
    }
    if (requested == FaceJudgementModeUnknownPerson) {
        [self activateUnknownPersonModeShowingErrors:YES];
    } else {
        [self activateSecondPersonMode];
    }
}

- (NSURL *)faceEmbeddingModelURL {
    return [NSBundle.mainBundle URLForResource:@"MobileFaceEmbedding" withExtension:@"mlpackage"];
}

- (BOOL)activateUnknownPersonModeShowingErrors:(BOOL)showErrors {
    if (!self.ownerFaceProfile) return NO;
    NSURL *modelURL = [self faceEmbeddingModelURL];
    NSError *error = nil;
    OwnerAwareFaceCoordinator *coordinator = modelURL
        ? [[OwnerAwareFaceCoordinator alloc] initWithProfile:self.ownerFaceProfile
                                                   modelURL:modelURL
                                         protectionDistance:self.protectionDistance
                                                      error:&error] : nil;
    if (!coordinator) {
        [self activateSecondPersonMode];
        if (showErrors) [self showAlertWithTitle:@"无法启用陌生人判断"
                                         message:error.localizedDescription ?: @"人脸模型资源缺失"];
        return NO;
    }
    self.ownerAwareCoordinator = coordinator;
    self.faceJudgementMode = FaceJudgementModeUnknownPerson;
    [self.faceJudgementModeStore saveFaceJudgementMode:self.faceJudgementMode];
    self.cameraService.identityAnalysisEnabled = YES;
    [self.debouncer reset];
    [self rebuildFaceJudgementModeMenu];
    return YES;
}

- (void)activateSecondPersonMode {
    [self.ownerAwareCoordinator reset];
    self.ownerAwareCoordinator = nil;
    self.faceJudgementMode = FaceJudgementModeSecondPerson;
    [self.faceJudgementModeStore saveFaceJudgementMode:self.faceJudgementMode];
    self.cameraService.identityAnalysisEnabled = self.enrollmentController != nil;
    [self.debouncer reset];
    [self rebuildFaceJudgementModeMenu];
}

- (void)beginOwnerFaceEnrollment:(id)sender {
    if (self.enrollmentController) return;
    NSURL *modelURL = [self faceEmbeddingModelURL];
    NSError *error = nil;
    OwnerFaceEnrollmentWindowController *controller = modelURL
        ? [[OwnerFaceEnrollmentWindowController alloc] initWithModelURL:modelURL error:&error] : nil;
    if (!controller) {
        [self showAlertWithTitle:@"无法开始面容录入"
                         message:error.localizedDescription ?: @"人脸模型资源缺失"];
        return;
    }
    self.enrollmentController = controller;
    controller.cameraPreviewLayer = [self.cameraService makeEnrollmentPreviewLayer];
    self.cameraService.identityAnalysisEnabled = YES;
    if (!self.protectionEnabled) {
        self.protectionEnabled = YES;
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"protectionEnabled"];
        self.toggleProtectionItem.state = NSControlStateValueOn;
    }
    [self reevaluateEnergyState];
    __weak typeof(self) weakSelf = self;
    controller.completionHandler = ^(OwnerFaceProfile *profile) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        NSError *saveError = nil;
        if (![self.ownerFaceProfileStore saveProfile:profile error:&saveError]) {
            [self showAlertWithTitle:@"本人面容保存失败" message:saveError.localizedDescription];
            self.enrollmentController = nil;
            [self activateSecondPersonMode];
            [self reevaluateEnergyState];
            return;
        }
        self.ownerFaceProfile = profile;
        self.enrollmentController = nil;
        [self activateUnknownPersonModeShowingErrors:YES];
        [self reevaluateEnergyState];
    };
    controller.cancellationHandler = ^{
        __strong typeof(weakSelf) self = weakSelf;
        self.enrollmentController = nil;
        self.cameraService.identityAnalysisEnabled =
            self.faceJudgementMode == FaceJudgementModeUnknownPerson;
        [self reevaluateEnergyState];
    };
    [controller beginEnrollment];
}

- (void)deleteOwnerFaceProfile:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"删除本人面容？";
    alert.informativeText = @"只会删除这台 Mac 钥匙串中的特征模板，并自动切回第二人判断。";
    [alert addButtonWithTitle:@"删除"];
    [alert addButtonWithTitle:@"取消"];
    [NSApp activateIgnoringOtherApps:YES];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
    NSError *error = nil;
    if (![self.ownerFaceProfileStore deleteProfileAndReturnError:&error]) {
        [self showAlertWithTitle:@"删除失败" message:error.localizedDescription];
        return;
    }
    self.ownerFaceProfile = nil;
    [self activateSecondPersonMode];
}

- (void)rebuildProtectionDistanceMenu {
    [self.protectionDistanceMenu removeAllItems];
    NSArray<NSDictionary *> *options = @[
        @{@"title": @"近距离", @"value": @(ProtectionDistanceNear)},
        @{@"title": @"标准", @"value": @(ProtectionDistanceStandard)},
        @{@"title": @"远距离", @"value": @(ProtectionDistanceFar)},
    ];
    for (NSDictionary *option in options) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:option[@"title"]
                                                      action:@selector(selectProtectionDistance:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = option[@"value"];
        item.state = [option[@"value"] integerValue] == self.protectionDistance
            ? NSControlStateValueOn : NSControlStateValueOff;
        [self.protectionDistanceMenu addItem:item];
    }
}

- (void)rebuildResponseSpeedMenu {
    [self.responseSpeedMenu removeAllItems];
    NSArray<NSDictionary *> *options = @[
        @{@"title": @"快速", @"value": @(ResponseSpeedFast)},
        @{@"title": @"标准", @"value": @(ResponseSpeedStandard)},
        @{@"title": @"稳健", @"value": @(ResponseSpeedSteady)},
    ];
    for (NSDictionary *option in options) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:option[@"title"]
                                                      action:@selector(selectResponseSpeed:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = option[@"value"];
        item.state = [option[@"value"] integerValue] == self.responseSpeed
            ? NSControlStateValueOn : NSControlStateValueOff;
        [self.responseSpeedMenu addItem:item];
    }
}

- (void)selectProtectionDistance:(NSMenuItem *)sender {
    NSNumber *value = sender.representedObject;
    if (![value isKindOfClass:NSNumber.class]) return;
    self.protectionDistance = value.integerValue;
    self.riskEvaluator.protectionDistance = self.protectionDistance;
    self.ownerAwareCoordinator.protectionDistance = self.protectionDistance;
    [NSUserDefaults.standardUserDefaults setInteger:self.protectionDistance
                                             forKey:ProtectionDistanceDefaultsKey];
    [self.debouncer reset];
    [self rebuildProtectionDistanceMenu];
}

- (void)selectResponseSpeed:(NSMenuItem *)sender {
    NSNumber *value = sender.representedObject;
    if (![value isKindOfClass:NSNumber.class]) return;
    self.responseSpeed = value.integerValue;
    [NSUserDefaults.standardUserDefaults setInteger:self.responseSpeed forKey:ResponseSpeedDefaultsKey];
    self.debouncer = [[PresenceDebouncer alloc]
        initWithRequiredDuration:RequiredDurationForResponseSpeed(self.responseSpeed)];
    [self rebuildResponseSpeedMenu];
}

- (void)toggleLoginItem:(id)sender {
    NSError *error = nil;
    BOOL enabled = SMAppService.mainAppService.status == SMAppServiceStatusEnabled;
    BOOL succeeded = enabled
        ? [SMAppService.mainAppService unregisterAndReturnError:&error]
        : [SMAppService.mainAppService registerAndReturnError:&error];
    if (!succeeded) {
        [self showAlertWithTitle:@"无法修改登录项" message:error.localizedDescription];
    }
    self.loginItem.state = SMAppService.mainAppService.status == SMAppServiceStatusEnabled
        ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)openCameraSettings:(id)sender {
    NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"];
    if (url) [NSWorkspace.sharedWorkspace openURL:url];
}

- (void)quit:(id)sender {
    [NSApplication.sharedApplication terminate:nil];
}

- (void)cameraService:(CameraService *)service
       didChangeState:(CameraServiceState)state
              message:(NSString *)message {
    self.cameraState = state;
    if (state == CameraServiceStatePermissionDenied || state == CameraServiceStateUnavailable ||
        state == CameraServiceStateFailed ||
        (state == CameraServiceStateStopped && !self.energyStateCoordinator.cameraShouldRun)) {
        [self.protectionCoordinator stop];
        [self.ownerAwareCoordinator reset];
    }
    if (state == CameraServiceStateStopped && self.energyStateCoordinator.cameraShouldRun) {
        [self.cameraService start];
    }
    [self updateInterfaceForState:state message:message];
}

- (void)cameraService:(CameraService *)service
 didDetectObservations:(NSArray<FaceRiskObservation *> *)observations {
    if (!self.protectionEnabled || self.cameraState != CameraServiceStateRunning) return;
    if (self.enrollmentController || self.faceJudgementMode == FaceJudgementModeUnknownPerson) return;
    FaceRiskState riskState = [self.riskEvaluator evaluateObservations:observations];
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    BOOL didTrigger = [self.debouncer recordRiskState:riskState atTime:now];
    [self.protectionCoordinator handleRiskState:riskState
                                     didTrigger:didTrigger
                                          atTime:now
                               bundleIdentifiers:[self protectedBundleIdentifiers]];
}

- (void)cameraService:(CameraService *)service didAnalyzeFrame:(FaceAnalysisFrame *)frame {
    if (self.enrollmentController) {
        [self.enrollmentController consumeFrame:frame];
        return;
    }
    if (!self.protectionEnabled || self.cameraState != CameraServiceStateRunning ||
        self.faceJudgementMode != FaceJudgementModeUnknownPerson || !self.ownerAwareCoordinator) return;
    FaceRiskState riskState = [self.ownerAwareCoordinator evaluateFrame:frame];
    BOOL didTrigger = [self.debouncer recordRiskState:riskState atTime:frame.timestamp];
    [self.protectionCoordinator handleRiskState:riskState didTrigger:didTrigger
                                          atTime:frame.timestamp
                               bundleIdentifiers:[self protectedBundleIdentifiers]];
}

- (void)updateInterfaceForState:(CameraServiceState)state message:(NSString *)message {
    NSString *symbolName = @"eye.slash";
    NSString *statusText = @"保护已暂停";
    switch (state) {
        case CameraServiceStateStopped:
            statusText = self.protectionEnabled ? @"保护准备中" : @"保护已暂停";
            break;
        case CameraServiceStateRequestingPermission:
            symbolName = @"camera.badge.ellipsis";
            statusText = @"等待摄像头权限";
            break;
        case CameraServiceStateRunning:
            symbolName = @"eye";
            statusText = @"保护中";
            if (self.faceJudgementMode == FaceJudgementModeUnknownPerson) statusText = @"保护中 · 陌生人判断";
            break;
        case CameraServiceStatePermissionDenied:
            symbolName = @"exclamationmark.triangle";
            statusText = @"未获得摄像头权限";
            break;
        case CameraServiceStateUnavailable:
        case CameraServiceStateFailed:
            symbolName = @"exclamationmark.triangle";
            statusText = [NSString stringWithFormat:@"保护未生效：%@", message ?: @"未知错误"];
            break;
    }
    if (self.energyStateCoordinator && self.energyStateCoordinator.state == EnergyStateNoVisibleWindows) {
        symbolName = @"leaf";
        statusText = self.energyStateCoordinator.statusText;
    } else if (self.energyStateCoordinator && self.energyStateCoordinator.state == EnergyStateSystemPaused) {
        symbolName = @"lock";
        statusText = self.energyStateCoordinator.statusText;
    } else if (self.energyStateCoordinator && self.energyStateCoordinator.state == EnergyStateDisabled) {
        symbolName = @"eye.slash";
        statusText = self.energyStateCoordinator.statusText;
    } else if (self.energyStateCoordinator && self.energyStateCoordinator.state == EnergyStateEnrollment &&
               state != CameraServiceStatePermissionDenied && state != CameraServiceStateFailed) {
        symbolName = @"camera";
        statusText = self.energyStateCoordinator.statusText;
    }
    if (self.protectionActionStatus.length > 0) {
        statusText = self.protectionActionStatus;
        symbolName = @"eye.fill";
    }
    self.stateMenuItem.title = statusText;
    self.toggleProtectionItem.title = self.protectionEnabled ? @"暂停保护" : @"开启保护";
    self.statusItem.button.image = [NSImage imageWithSystemSymbolName:symbolName
                                            accessibilityDescription:statusText];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = message ?: @"未知错误";
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"好"];
    [NSApplication.sharedApplication activateIgnoringOtherApps:YES];
    [alert runModal];
}

@end
