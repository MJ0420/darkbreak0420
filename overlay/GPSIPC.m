#import "GPSIPC.h"
#import <notify.h>
static const char *kMJNotify = "com.mj.gpsjoystick.coordinate.v1";
static int kMJToken = -1;
static BOOL MJEnsure(void) {
    if (kMJToken >= 0) return YES;
    return notify_register_check(kMJNotify, &kMJToken) == NOTIFY_STATUS_OK;
}
BOOL MJGPSRead(GPSModel *outState) {
    if (!outState || !MJEnsure()) return NO;
    uint64_t code = 0;
    if (notify_get_state(kMJToken, &code) != NOTIFY_STATUS_OK) return NO;
    gps_model_init(outState);
    gps_model_decode(outState, code);
    return YES;
}
BOOL MJGPSWrite(const GPSModel *state) {
    if (!state || !MJEnsure()) return NO;
    if (notify_set_state(kMJToken, gps_model_encode(state)) != NOTIFY_STATUS_OK) return NO;
    notify_post(kMJNotify);
    return YES;
}
