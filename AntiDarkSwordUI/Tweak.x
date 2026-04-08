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
// PREFERENCE LOADING
// =========================================================
static void loadLocalPrefs() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
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
// IN-APP SETTINGS UI (Triggered via 3-Finger Double Tap)
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

- (void)togglePref:(NSString *)key currentVal:(BOOL)currentVal {
    [[NSUserDefaults standardUserDefaults] setBool:!currentVal forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    loadLocalPrefs();
}

- (void)showMenu {
    UIViewController *topVC = [self topViewController];
    if (!topVC) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"AntiDarkSword" 
                                                                   message:@"App-Specific Mitigations\n(Restart app to fully apply changes)" 
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    // Helper block to create toggles
    void (^addToggle)(NSString *, NSString *, BOOL) = ^(NSString *title, NSString *key, BOOL currentState) {
        NSString *fullTitle = [NSString stringWithFormat:@"%@ %@", currentState ? @"🟢" : @"🔴", title];
        UIAlertAction *action = [UIAlertAction actionWithTitle:fullTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self togglePref:key currentVal:currentState];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self showMenu]; // Re-open menu to show updated state
            });
        }];
        [alert addAction:action];
    };

    addToggle(@"Spoof User Agent", @"ads_spoofUA", shouldSpoofUA);
    addToggle(@"Disable iOS 16+ JIT", @"ads_disableJIT", applyDisableJIT);
    addToggle(@"Disable iOS 15 JIT", @"ads_disableJIT15", applyDisableJIT15);
    addToggle(@"Disable JavaScript ⚠︎", @"ads_disableJS", applyDisableJS);
    addToggle(@"Disable WebGL & WebRTC", @"ads_disableRTC", applyDisableRTC);
    addToggle(@"Disable Media Auto-Play", @"ads_disableMedia", applyDisableMedia);
    addToggle(@"Disable Local File Access", @"ads_disableFileAccess", applyDisableFileAccess);

    UIAlertAction *close = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:close];

    // iPad support for ActionSheets
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = topVC.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(topVC.view.bounds.size.width / 2.0, topVC.view.bounds.size.height / 2.0, 1.0, 1.0);
        alert.popoverPresentationController.permittedArrowDirections = 0;
    }

    [topVC presentViewController:alert animated:YES completion:nil];
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