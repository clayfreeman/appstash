TARGET = iphone:9.3

include $(THEOS)/makefiles/common.mk

TOOL_NAME = appstash
appstash_FILES = main.mm

include $(THEOS_MAKE_PATH)/tool.mk
SUBPROJECTS += appstash_helper
include $(THEOS_MAKE_PATH)/aggregate.mk
