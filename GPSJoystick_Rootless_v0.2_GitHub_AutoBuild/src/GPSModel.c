#include "GPSModel.h"
#include <math.h>
#include <stddef.h>

#define DEG_PER_RAD (180.0 / 3.1415926535897932384626433832795)
#define EARTH_RADIUS_M 6371000.0

static double clamp(double v, double lo, double hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}
void gps_model_init(GPSModel *m) {
    if (!m) return;
    m->active = 0;
    m->latitude = 0;
    m->longitude = 0;
    m->speed_kmh = 5;
    m->axis_east = 0;
    m->axis_north = 0;
}
int gps_valid_coordinate(double lat, double lng) {
    return isfinite(lat) && isfinite(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}
int gps_model_teleport(GPSModel *m, double lat, double lng) {
    if (!m || !gps_valid_coordinate(lat, lng)) return 0;
    m->active = 1;
    m->latitude = lat;
    m->longitude = lng;
    gps_model_pause(m);
    return 1;
}
void gps_model_set_speed(GPSModel *m, double kmh) {
    if (m && isfinite(kmh)) m->speed_kmh = clamp(kmh, 5, 50);
}
void gps_model_set_joystick(GPSModel *m, double east, double north) {
    if (!m) return;
    if (!isfinite(east) || !isfinite(north) || !m->active) {
        gps_model_pause(m);
        return;
    }
    double magnitude = hypot(east, north);
    if (magnitude > 1.0) {
        east /= magnitude;
        north /= magnitude;
    }
    m->axis_east = east;
    m->axis_north = north;
}
void gps_model_pause(GPSModel *m) {
    if (m) {m->axis_east=0; m->axis_north=0;}
}
void gps_model_step(GPSModel *m, double seconds) {
    if (!m || !m->active || !isfinite(seconds) || seconds <= 0) return;
    seconds = clamp(seconds, 0, 0.5);
    if (m->axis_east == 0 && m->axis_north == 0) return;
    double distance = m->speed_kmh * (1000.0 / 3600.0) * seconds;
    double north_m = distance * m->axis_north;
    double east_m = distance * m->axis_east;
    double lat_rad = m->latitude / DEG_PER_RAD;
    double latitude = m->latitude + north_m / EARTH_RADIUS_M * DEG_PER_RAD;
    double cos_lat = cos(lat_rad);
    if (fabs(cos_lat) < 1e-7) cos_lat = cos_lat < 0 ? -1e-7 : 1e-7;
    double longitude = m->longitude + east_m / (EARTH_RADIUS_M * cos_lat) * DEG_PER_RAD;
    latitude = clamp(latitude, -90, 90);
    while (longitude > 180) longitude -= 360;
    while (longitude < -180) longitude += 360;
    m->latitude = latitude;
    m->longitude = longitude;
}
void gps_model_restore(GPSModel *m) {
    if (!m) return;
    m->active = 0;
    m->latitude = 0;
    m->longitude = 0;
    gps_model_pause(m);
}
/* Cross-process Darwin notification state. 28 bits latitude + 29 bits longitude,
   and one enabled bit. Resolution: 1e-6 degrees (about 11 cm latitude). */
uint64_t gps_model_encode(const GPSModel *m) {
    if (!m || !m->active || !gps_valid_coordinate(m->latitude, m->longitude)) return 0;
    uint64_t lat = (uint64_t)llround(m->latitude * 1000000.0 + 90000000.0);
    uint64_t lon = (uint64_t)llround(m->longitude * 1000000.0 + 180000000.0);
    return (1ULL << 63) | (lat << 29) | lon;
}
void gps_model_decode(GPSModel *m, uint64_t value) {
    if (!m) return;
    if (!(value & (1ULL << 63))) {gps_model_restore(m); return;}
    uint64_t lat = (value >> 29) & ((1ULL << 28) - 1);
    uint64_t lon = value & ((1ULL << 29) - 1);
    double latitude = ((double)lat - 90000000.0) / 1000000.0;
    double longitude = ((double)lon - 180000000.0) / 1000000.0;
    if (!gps_valid_coordinate(latitude, longitude)) {gps_model_restore(m); return;}
    m->latitude = latitude;
    m->longitude = longitude;
    m->active = 1;
    gps_model_pause(m);
}
