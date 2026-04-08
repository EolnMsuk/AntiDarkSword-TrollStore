ARCHS = arm64 arm64e
TARGET := iphone:clang:16.5:14.0

include $(THEOS)/makefiles/common.mk

# We only compile the standalone UI dylib now
SUBPROJECTS += AntiDarkSwordUI
include $(THEOS_MAKE_PATH)/aggregate.mk