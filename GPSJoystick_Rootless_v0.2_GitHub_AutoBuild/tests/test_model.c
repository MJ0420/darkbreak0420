#include "../src/GPSModel.h"
#include <math.h>
#include <stdio.h>
#include <assert.h>

int main(void) {
    GPSModel m; gps_model_init(&m);
    assert(!m.active && m.speed_kmh==5);
    // Draft input is UI-only and must not activate model.
    double draft_lat=3.156590, draft_lng=101.717790;
    assert(!m.active);
    assert(!gps_model_teleport(&m, 91, 50));
    assert(!m.active);
    assert(gps_model_teleport(&m,draft_lat,draft_lng));
    assert(m.active && fabs(m.latitude-draft_lat)<1e-9);
    gps_model_set_speed(&m, 100);
    assert(m.speed_kmh==50);
    gps_model_set_speed(&m, 5);
    gps_model_set_joystick(&m, 0,1);
    double before=m.latitude;
    gps_model_step(&m,0.2);
    assert(m.latitude > before);
    double moved=m.latitude;
    gps_model_pause(&m);
    gps_model_step(&m,0.2);
    assert(m.latitude==moved);
    uint64_t code=gps_model_encode(&m);
    GPSModel other; gps_model_init(&other); gps_model_decode(&other,code);
    assert(other.active);
    assert(fabs(other.latitude-m.latitude)<1e-6);
    assert(fabs(other.longitude-m.longitude)<1e-6);
    // Confirming another target resets joystick and moves origin.
    gps_model_set_joystick(&m,1,0);
    assert(gps_model_teleport(&m,2.0,100.0));
    assert(m.axis_east==0 && m.axis_north==0);
    gps_model_step(&m,0.2);
    assert(m.latitude==2.0 && m.longitude==100.0);
    gps_model_restore(&m);
    assert(!m.active && gps_model_encode(&m)==0);
    gps_model_decode(&other,0);
    assert(!other.active);
    assert(!gps_valid_coordinate(NAN,0));
    puts("PASS: 15 assertions/groups - draft/confirm/movement/pause/teleport/restore/encoding");
    return 0;
}
