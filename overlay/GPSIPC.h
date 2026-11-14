#import <Foundation/Foundation.h>
#import "../src/GPSModel.h"

#ifdef __cplusplus
extern "C" {
#endif

BOOL MJGPSRead(GPSModel *outState);
BOOL MJGPSWrite(const GPSModel *state);

#ifdef __cplusplus
}
#endif
