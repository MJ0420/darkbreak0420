#ifndef GPSJOYSTICK_GPSMODEL_H
#define GPSJOYSTICK_GPSMODEL_H
#include <stdint.h>

typedef struct {
    int active;
    double latitude;
    double longitude;
    double speed_kmh;
    double axis_east;
    double axis_north;
} GPSModel;

void gps_model_init(GPSModel *m);
int gps_valid_coordinate(double latitude, double longitude);
int gps_model_teleport(GPSModel *m, double latitude, double longitude);
void gps_model_set_speed(GPSModel *m, double kmh);
void gps_model_set_joystick(GPSModel *m, double east, double north);
void gps_model_step(GPSModel *m, double seconds);
void gps_model_pause(GPSModel *m);
void gps_model_restore(GPSModel *m);
uint64_t gps_model_encode(const GPSModel *m);
void gps_model_decode(GPSModel *m, uint64_t code);
#endif
