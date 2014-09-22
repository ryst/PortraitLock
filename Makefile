include theos/makefiles/common.mk

TWEAK_NAME = PortraitLock
PortraitLock_FILES = Tweak.xm
PortraitLock_FRAMEWORKS = MediaPlayer

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"

SUBPROJECTS += portraitlockprefs
SUBPROJECTS += portraitlockfs
include $(THEOS_MAKE_PATH)/aggregate.mk
