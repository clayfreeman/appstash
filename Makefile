TARGET = iphone:9.0

THEOS_PACKAGE_DIR_NAME = deb
include $(THEOS)/makefiles/common.mk

TOOL_NAME = appstash
appstash_CFLAGS = -fobjc-arc
appstash_FILES = main.mm

include $(THEOS_MAKE_PATH)/tool.mk
SUBPROJECTS += appstash_helper
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard || exit 0"
	install.exec "killall -9 installd    || exit 0"
