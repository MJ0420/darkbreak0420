ARCHS = arm64
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk
SUBPROJECTS = overlay
include $(THEOS_MAKE_PATH)/aggregate.mk
