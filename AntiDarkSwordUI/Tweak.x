#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <JavaScriptCore/JavaScriptCore.h>

// =========================================================
// PRIVATE WEBKIT INTERFACES
// =========================================================
@interface WKWebpagePreferences (Private)
@property (nonatomic, assign) BOOL lockdownModeEnabled;
@end

@interface _WKProcessPoolConfiguration : NSObject
@property (nonatomic, assign) BOOL JITEnabled;
@end

@interface WKProcessPool (Private)
@property (nonatomic, readonly) _WKProcessPoolConfiguration *_configuration;
@end

// =========================================================
// GLOBAL STATE VARIABLES (Loaded from local app storage)
// =========================================================
static BOOL applyDisableJIT = NO;
static BOOL applyDisableJIT15 = NO;
static BOOL applyDisableJS = NO;
static BOOL applyDisableMedia = NO;
static BOOL applyDisableRTC = NO;
static BOOL applyDisableFileAccess = NO;
static BOOL shouldSpoofUA = NO;
static NSString *customUAString = @"";

// =========================================================
// PREFERENCE LOADING & SMART DEFAULTS
// =========================================================
static void loadLocalPrefs() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 1. FIRST RUN INITIALIZATION (Smart Defaults & iOS Detection)
    if (![defaults boolForKey:@"ads_initialized"]) {
        // Detect iOS major version
        BOOL isIOS16OrGreater = [[NSProcessInfo processInfo] operatingSystemVersion].majorVersion >= 16;
        
        // Set Defaults: UA Spoofing ON (18.1), Correct JIT ON, everything else OFF
        [defaults setBool:YES forKey:@"ads_spoofUA"];
        [defaults setObject:@"Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1" forKey:@"ads_customUAString"];
        
        [defaults setBool:isIOS16OrGreater forKey:@"ads_disableJIT"];
        [defaults setBool:!isIOS16OrGreater forKey:@"ads_disableJIT15"];
        
        [defaults setBool:YES forKey:@"ads_initialized"];
        [defaults synchronize];
    }
    
    // 2. LOAD STATE INTO MEMORY
    applyDisableJIT = [defaults boolForKey:@"ads_disableJIT"];
    applyDisableJIT15 = [defaults boolForKey:@"ads_disableJIT15"];
    applyDisableJS = [defaults boolForKey:@"ads_disableJS"];
    applyDisableMedia = [defaults boolForKey:@"ads_disableMedia"];
    applyDisableRTC = [defaults boolForKey:@"ads_disableRTC"];
    applyDisableFileAccess = [defaults boolForKey:@"ads_disableFileAccess"];
    shouldSpoofUA = [defaults boolForKey:@"ads_spoofUA"];
    
    NSString *savedUA = [defaults stringForKey:@"ads_customUAString"];
    customUAString = (savedUA && savedUA.length > 0) ? savedUA : @"Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1";
}

%ctor {
    loadLocalPrefs();
}

// =========================================================
// IN-APP SETTINGS UI (Native Table View)
// =========================================================
@interface ADSMenuViewController : UITableViewController
@property (nonatomic, strong) NSArray *menuItems;
@end

@implementation ADSMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"AntiDarkSword";
    
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
    
    // Add a Done button to close the menu
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(closeMenu)];
    
    self.menuItems = @[
        @{@"title": @"Spoof User Agent", @"key": @"ads_spoofUA"},
        @{@"title": @"Disable iOS 16+ JIT", @"key": @"ads_disableJIT"},
        @{@"title": @"Disable iOS 15 JIT", @"key": @"ads_disableJIT15"},
        @{@"title": @"Disable JavaScript ⚠︎", @"key": @"ads_disableJS"},
        @{@"title": @"Disable WebGL & WebRTC", @"key": @"ads_disableRTC"},
        @{@"title": @"Disable Media Auto-Play", @"key": @"ads_disableMedia"},
        @{@"title": @"Disable Local File Access", @"key": @"ads_disableFileAccess"}
    ];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
}

- (void)closeMenu {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.menuItems.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"Changes require an app restart to fully apply to the WebKit engine.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    NSDictionary *item = self.menuItems[indexPath.row];
    
    cell.textLabel.text = item[@"title"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    // Create the visual switch
    UISwitch *toggle = [[UISwitch alloc] init];
    toggle.on = [[NSUserDefaults standardUserDefaults] boolForKey:item[@"key"]];
    toggle.tag = indexPath.row;
    [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    
    cell.accessoryView = toggle;
    return cell;
}

// Handle switch toggles without closing the menu
- (void)switchChanged:(UISwitch *)sender {
    NSDictionary *item = self.menuItems[sender.tag];
    NSString *key = item[@"key"];
    BOOL isOn = sender.isOn;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:isOn forKey:key];
    
    // JS -> JIT Link Logic
    if ([key isEqualToString:@"ads_disableJS"] && isOn) {
        BOOL isIOS16OrGreater = [[NSProcessInfo processInfo] operatingSystemVersion].majorVersion >= 16;
        if (isIOS16OrGreater) {
            [defaults setBool:YES forKey:@"ads_disableJIT"];
        } else {
            [defaults setBool:YES forKey:@"ads_disableJIT15"];
        }
        // Reload table to visually update the JIT switch on screen
        [self.tableView reloadData];
    }
    
    [defaults synchronize];
    loadLocalPrefs(); // Reload into tweak engine immediately
}
@end

// =========================================================
// MENU MANAGER
// =========================================================
@interface ADSMenuManager : NSObject
+ (instancetype)sharedManager;
- (void)showMenu;
@end

@implementation ADSMenuManager
+ (instancetype)sharedManager {
    static ADSMenuManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (UIViewController *)topViewController {
    UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    return topController;
}

- (void)showMenu {
    UIViewController *topVC = [self topViewController];
    if (!topVC) return;
    
    // Wrap the TableView in a Navigation Controller so it has a top bar for the Done button
    ADSMenuViewController *menuVC = [[ADSMenuViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:menuVC];
    
    // Present as a native sliding sheet
    if (@available(iOS 15.0, *)) {
        navController.modalPresentationStyle = UIModalPresentationPageSheet;
        if ([navController.sheetPresentationController respondsToSelector:@selector(setDetents:)]) {
            navController.sheetPresentationController.detents = @[[UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent]];
        }
    } else {
        navController.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    
    [topVC presentViewController:navController animated:YES completion:nil];
}
@end

// Inject Gesture Recognizer into the App's Main Window
%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:[ADSMenuManager sharedManager] action:@selector(showMenu)];
        tap.numberOfTapsRequired = 2;
        tap.numberOfTouchesRequired = 3;
        [self addGestureRecognizer:tap];
    });
}
%end


// =========================================================
// WEBKIT EXPLOIT MITIGATIONS & ANTI-FINGERPRINTING
// =========================================================
%hook WKWebViewConfiguration

- (void)setUserContentController:(WKUserContentController *)userContentController {
    %orig;
    if (shouldSpoofUA) {
        NSString *jsSource = [NSString stringWithFormat:@"\
            Object.defineProperty(navigator, 'userAgent', { get: () => '%@' });\n\
            Object.defineProperty(navigator, 'appVersion', { get: () => '%@' });\n\
        ", customUAString, customUAString];
        
        WKUserScript *antiFingerprintScript = [[WKUserScript alloc] initWithSource:jsSource 
                                                                     injectionTime:WKUserScriptInjectionTimeAtDocumentStart 
                                                                  forMainFrameOnly:NO];
        [userContentController addUserScript:antiFingerprintScript];
    }
}

- (void)setApplicationNameForUserAgent:(NSString *)applicationNameForUserAgent {
    if (shouldSpoofUA) return %orig(@"");
    %orig;
}
%end

%hook WKWebView

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    
    if (applyDisableJS) {
        if ([configuration respondsToSelector:@selector(defaultWebpagePreferences)]) configuration.defaultWebpagePreferences.allowsContentJavaScript = NO;
        if ([configuration.preferences respondsToSelector:@selector(setJavaScriptEnabled:)]) configuration.preferences.javaScriptEnabled = NO;
    }

    if (applyDisableJIT) {
        if ([configuration respondsToSelector:@selector(defaultWebpagePreferences)]) {
            if ([configuration.defaultWebpagePreferences respondsToSelector:@selector(setLockdownModeEnabled:)]) {
                [(id)configuration.defaultWebpagePreferences setLockdownModeEnabled:YES];
            }
        }
    }
    
    if (applyDisableJIT15 || applyDisableJIT) {
        if ([configuration respondsToSelector:@selector(processPool)]) {
            if ([configuration.processPool respondsToSelector:@selector(_configuration)]) {
                id poolConfig = [(id)configuration.processPool _configuration];
                if ([poolConfig respondsToSelector:@selector(setJITEnabled:)]) [(id)poolConfig setJITEnabled:NO];
            }
        }
    }
    
    if (applyDisableMedia) {
        if ([configuration respondsToSelector:@selector(setAllowsInlineMediaPlayback:)]) configuration.allowsInlineMediaPlayback = NO;
        if ([configuration respondsToSelector:@selector(setMediaTypesRequiringUserActionForPlayback:)]) configuration.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeAll;
    }
    
    if ([configuration.preferences respondsToSelector:@selector(setValue:forKey:)]) {
        @try {
            if (applyDisableFileAccess) {
                [configuration.preferences setValue:@NO forKey:@"allowFileAccessFromFileURLs"];
                [configuration.preferences setValue:@NO forKey:@"allowUniversalAccessFromFileURLs"];
            }
            if (applyDisableRTC) {
                [configuration.preferences setValue:@NO forKey:@"webGLEnabled"];
                [configuration.preferences setValue:@NO forKey:@"mediaStreamEnabled"]; 
                [configuration.preferences setValue:@NO forKey:@"peerConnectionEnabled"];
            }
        } @catch (NSException *e) {}
    }
    
    WKWebView *webView = %orig(frame, configuration);
    if (shouldSpoofUA && [webView respondsToSelector:@selector(setCustomUserAgent:)]) {
        webView.customUserAgent = customUAString;
    }
    return webView;
}

- (WKNavigation *)loadRequest:(NSURLRequest *)request {
    if (shouldSpoofUA && [request respondsToSelector:@selector(valueForHTTPHeaderField:)]) {
        NSString *existingUA = [request valueForHTTPHeaderField:@"User-Agent"];
        if (existingUA && ![existingUA isEqualToString:customUAString]) {
            NSMutableURLRequest *mutableReq = [request mutableCopy];
            [mutableReq setValue:customUAString forHTTPHeaderField:@"User-Agent"];
            return %orig(mutableReq);
        }
    }
    return %orig;
}

- (void)evaluateJavaScript:(NSString *)javaScriptString completionHandler:(void (^)(id, NSError *))completionHandler {
    if (applyDisableJS) {
        if (completionHandler) {
            NSError *err = [NSError errorWithDomain:@"AntiDarkSword" code:1 userInfo:@{NSLocalizedDescriptionKey: @"JS execution blocked"}];
            completionHandler(nil, err);
        }
        return;
    }
    %orig;
}

- (void)setCustomUserAgent:(NSString *)customUserAgent {
    if (shouldSpoofUA) %orig(customUAString);
    else %orig;
}
%end

%hook WKWebpagePreferences
- (void)setAllowsContentJavaScript:(BOOL)allowed {
    if (applyDisableJS && allowed) return %orig(NO);
    %orig;
}
%end

%hook WKPreferences
- (void)setJavaScriptEnabled:(BOOL)enabled {
    if (applyDisableJS && enabled) return %orig(NO);
    %orig;
}
%end

%hookf(JSValueRef, JSEvaluateScript, JSContextRef ctx, JSStringRef script, JSObjectRef thisObject, JSStringRef sourceURL, int startingLineNumber, JSValueRef *exception) {
    if (applyDisableJS) return NULL;
    return %orig(ctx, script, thisObject, sourceURL, startingLineNumber, exception);
}
