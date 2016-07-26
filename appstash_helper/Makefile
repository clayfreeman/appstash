TARGET = iphone:9.3

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = appstash_helper
appstash_helper_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
	install.exec "killall -9 installd"
