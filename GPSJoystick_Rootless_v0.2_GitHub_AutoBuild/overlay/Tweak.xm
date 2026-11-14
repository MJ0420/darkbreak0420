#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "GPSIPC.h"
#import "Controller.h"

// Experimental isolated engine. Not a locationd replacement; scoped to Apple Maps
// so users can validate behavior before widening injection to other apps.
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
    GPSModel state;
    if (MJGPSRead(&state) && state.active) {
        return [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(state.latitude,state.longitude)
                                             altitude:0
                                   horizontalAccuracy:5
                                     verticalAccuracy:5
                                               course:-1
                                                speed:-1
                                            timestamp:[NSDate date]];
    }
    return %orig;
}
%end

%ctor {
    @autoreleasepool {
        NSString *bundle = [NSBundle mainBundle].bundleIdentifier;
        if ([bundle isEqualToString:@"com.apple.springboard"]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[GPSOverlayController shared] start];
            });
        }
    }
}
