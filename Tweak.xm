#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>
#import "GPSIPC.h"
#import "Controller.h"

// v0.3 test shim: opt in only app processes. Do NOT hook locationd or other daemons.
// This is application-side CoreLocation simulation, not a locationd-level modification.
static BOOL MJAllowedApplication(void) {
    NSBundle *b = [NSBundle mainBundle];
    NSString *identifier = b.bundleIdentifier;
    if (!identifier.length) return NO;
    if ([identifier isEqualToString:@"com.apple.springboard"]) return NO;
    if ([identifier isEqualToString:@"com.apple.Maps"]) return YES;
    // Avoid all other system components and apps during initial cross-app testing.
    if ([identifier hasPrefix:@"com.apple."]) return NO;
    NSString *path = b.bundlePath;
    // Do not inject into most system daemons or executables lacking an .app bundle.
    return [path.pathExtension.lowercaseString isEqualToString:@"app"];
}

static CLLocation *MJCurrentFakeLocation(void) {
    GPSModel state;
    if (!MJGPSRead(&state) || !state.active) return nil;
    return [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(state.latitude, state.longitude)
                                         altitude:0
                               horizontalAccuracy:5
                                 verticalAccuracy:5
                                           course:-1
                                            speed:-1
                                        timestamp:[NSDate date]];
}

@interface MJLocationTicker : NSObject
@property(nonatomic, weak) CLLocationManager *manager;
@property(nonatomic, strong) NSTimer *timer;
- (void)sendUpdate:(NSTimer *)timer;
@end

@implementation MJLocationTicker
- (void)sendUpdate:(NSTimer *)timer {
    (void)timer;
    CLLocationManager *manager = self.manager;
    if (!manager) { [self.timer invalidate]; self.timer = nil; return; }
    CLLocation *location = MJCurrentFakeLocation();
    if (!location) return;
    id<CLLocationManagerDelegate> delegate = manager.delegate;
    SEL callback = @selector(locationManager:didUpdateLocations:);
    if (delegate && [delegate respondsToSelector:callback]) {
        [delegate locationManager:manager didUpdateLocations:@[location]];
    }
}
@end

static const void *MJLocationTickerKey = &MJLocationTickerKey;
static void MJStartTicker(CLLocationManager *manager) {
    // The manager may have been created on another thread. Attach timer on main.
    __weak CLLocationManager *weakManager = manager;
    dispatch_async(dispatch_get_main_queue(), ^{
        CLLocationManager *m = weakManager;
        if (!m || objc_getAssociatedObject(m, MJLocationTickerKey)) return;
        MJLocationTicker *ticker = [MJLocationTicker new];
        ticker.manager = m;
        NSTimer *timer = [NSTimer timerWithTimeInterval:0.3
                                                target:ticker
                                              selector:@selector(sendUpdate:)
                                              userInfo:nil
                                               repeats:YES];
        ticker.timer = timer;
        objc_setAssociatedObject(m, MJLocationTickerKey, ticker, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        [ticker sendUpdate:nil];
    });
}
static void MJStopTicker(CLLocationManager *manager) {
    __weak CLLocationManager *weakManager = manager;
    dispatch_async(dispatch_get_main_queue(), ^{
        CLLocationManager *m = weakManager;
        if (!m) return;
        MJLocationTicker *ticker = objc_getAssociatedObject(m, MJLocationTickerKey);
        [ticker.timer invalidate];
        ticker.timer = nil;
        objc_setAssociatedObject(m, MJLocationTickerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    });
}

%group MJAppLocationHooks
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    GPSModel state;
    if (MJGPSRead(&state) && state.active) {
        return CLLocationCoordinate2DMake(state.latitude, state.longitude);
    }
    return %orig;
}
%end

%hook CLLocationManager
- (CLLocation *)location {
    CLLocation *loc = MJCurrentFakeLocation();
    if (loc) return loc;
    return %orig;
}
- (void)startUpdatingLocation {
    %orig;
    MJStartTicker(self);
}
- (void)stopUpdatingLocation {
    MJStopTicker(self);
    %orig;
}
- (void)requestLocation {
    %orig;
    __weak CLLocationManager *weakManager = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CLLocationManager *manager = weakManager;
        if (!manager) return;
        CLLocation *location = MJCurrentFakeLocation();
        if (!location) return;
        id<CLLocationManagerDelegate> delegate = manager.delegate;
        if (delegate && [delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            [delegate locationManager:manager didUpdateLocations:@[location]];
        }
    });
}
%end
%end

%ctor {
    @autoreleasepool {
        NSString *bundle = [NSBundle mainBundle].bundleIdentifier;
        if ([bundle isEqualToString:@"com.apple.springboard"]) {
            dispatch_async(dispatch_get_main_queue(), ^{ [[GPSOverlayController shared] start]; });
        } else if (MJAllowedApplication()) {
            %init(MJAppLocationHooks);
        }
    }
}
