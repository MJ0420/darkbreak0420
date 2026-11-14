ARCHS = arm64
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = GPSJoystick
GPSJoystick_FILES = Tweak.xm Controller.m GPSIPC.m ../src/GPSModel.c
GPSJoystick_CFLAGS = -fobjc-arc -I../src -Wall -Wextra -Wno-deprecated-declarations
GPSJoystick_FRAMEWORKS = UIKit Foundation MapKit CoreLocation
GPSJoystick_LIBRARIES = c
include $(THEOS_MAKE_PATH)/tweak.mk
