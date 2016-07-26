TARGET = iphone:9.0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = appstash
appstash_FILES = main.mm

include $(THEOS_MAKE_PATH)/tool.mk
SUBPROJECTS += appstash_helper
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"
	install.exec "killall -9 installd"
