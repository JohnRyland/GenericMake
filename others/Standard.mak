#
# Generic Makefile rules that can be included in any Makefile
# Written by John Ryland
# (C) Copyright 2015
#
# Example usage:
#
#     # Example Makefile
#     TARGET        = app_name
#     SOURCES       = main.cpp \
#                     tests.cpp \
#                     file.c
#
#     # Some optional values that can be omitted
#     CONFIG        = [release|profile|debug]  [application|library]  [dynamic|static]  [qt]
#     CFLAGS        = -Os
#     DEFINES       = DEBUG OS_LINUX
#     INCLUDE_PATHS = ./include
#     LIBRARY_PATHS = ./lib
#     LIBRARIES     = utils
#     OBJECTS_DIR   = .obj
#     TARGET_DIR    = ./bin
#     VERSION_MAJOR = 1
#     VERSION_MINOR = 0
#
#     # The important part, including the generic set of Makefile rules
#     include ../Makefile.mak
#


#
# Linking config options
#
LINKING += $(findstring dynamic,$(CONFIG))
LINKING += $(findstring static,$(CONFIG))
LINKING := $(LINKING: =)


#
# Optimization config options
#
OPTIMIZATION += $(findstring release,$(CONFIG))
OPTIMIZATION += $(findstring profile,$(CONFIG))
OPTIMIZATION += $(findstring debug,$(CONFIG))
OPTIMIZATION := $(OPTIMIZATION: =)


#
# Template config options
#
TEMPLATE += $(findstring application,$(CONFIG))
TEMPLATE += $(findstring library,$(CONFIG))
TEMPLATE := $(TEMPLATE: =)


#
# Framework config options (currently only Qt)
#
FRAMEWORK += $(findstring qt,$(CONFIG))
FRAMEWORK := $(FRAMEWORK: =)



#
# Setup defaults
#
ifeq ($(HOST_PLATFORM: =),)
  HOST_PLATFORM=$(shell uname)
endif
ifeq ($(TARGET_PLATFORM: =),)
  TARGET_PLATFORM=$(shell uname)
endif
ifeq ($(TARGET_DIR: =),)
  TARGET_DIR=.
endif
ifeq ($(OBJECTS_DIR: =),)
  OBJECTS_DIR=.obj
endif
ifeq ($(LINKING: =),)
  LINKING=dynamic
endif
ifeq ($(OPTIMIZATION: =),)
  OPTIMIZATION=debug
endif
ifeq ($(TEMPLATE: =), )
  TEMPLATE=application
endif
TARGET_SUFFIX=
ifeq ($(OPTIMIZATION: =),profile)
  TARGET_SUFFIX=_p
endif
ifeq ($(OPTIMIZATION: =),debug)
  TARGET_SUFFIX=_d
endif
ifeq ($(VERSION_MAJOR: =),)
  VERSION_MAJOR=1
endif
ifeq ($(VERSION_MINOR: =),)
  VERSION_MINOR=0
endif

#
# Framework settings
#
ifeq ($(FRAMEWORK),qt)
  DEFINES += QT_WEBKITWIDGETS_LIB QT_QUICK_LIB QT_OPENGL_LIB QT_PRINTSUPPORT_LIB \
			 QT_WEBKIT_LIB QT_QML_LIB QT_LOCATION_LIB QT_WIDGETS_LIB QT_NETWORK_LIB \
			 QT_POSITIONING_LIB QT_SENSORS_LIB QT_GUI_LIB QT_CORE_LIB QT_QML_DEBUG \
			 QT_DECLARATIVE_DEBUG _REENTRANT

  # macOS
  ifeq ($(TARGET_PLATFORM),Darwin)
    QT_TARGET = macx-g++

    INCLUDE_PATHS += /usr/local/Cellar/libpng/1.6.34/include
    LIBRARIES += png z
    FRAMEWORK_DIRS = $(patsubst %,Qt%,$(QT)) $(FRAMEWORKS)
    CFLAGS_PLATFORM = $(patsubst %,-I/Library/Frameworks/%.framework/Headers,$(FRAMEWORK_DIRS))
    LFLAGS_PLATFORM = -F/Library/Frameworks \
                      -F$(QTDIR)/lib \
                      $(patsubst %,-framework %,$(FRAMEWORK_DIRS)) 
  endif
  # end macOS
  
  # Linux
  ifeq ($(TARGET_PLATFORM),Linux)
    QT_TARGET = linux-g++-64

    LIBRARY_PATHS += $(QT_LIBS_DIR)
    LIBRARIES += png z GL pthread
    ifeq ($(QT_MAJOR_VERSION),4)
      LIBRARIES += $(patsubst %,Qt%,$(QT))
    else
      LIBRARIES += $(patsubst %,Qt5%,$(QT))
    endif
  endif
  # end Linux

  QMAKESPEC = $(QTDIR)/mkspecs/$(QT_TARGET)
  INCLUDE_PATHS += $(QMAKESPEC) $(QT_INCLUDE_DIR) $(QT_INCLUDE_DIR)/QtWebKitWidgets \
				   $(QT_INCLUDE_DIR)/QtQuick $(QT_INCLUDE_DIR)/QtOpenGL $(QT_INCLUDE_DIR)/QtPrintSupport \
				   $(QT_INCLUDE_DIR)/QtWebKit $(QT_INCLUDE_DIR)/QtQml $(QT_INCLUDE_DIR)/QtLocation \
				   $(QT_INCLUDE_DIR)/QtWidgets $(QT_INCLUDE_DIR)/QtNetwork $(QT_INCLUDE_DIR)/QtPositioning \
				   $(QT_INCLUDE_DIR)/QtSensors $(QT_INCLUDE_DIR)/QtGui $(QT_INCLUDE_DIR)/QtCore \
				   $(QT_INCLUDE_DIR)/QtQmlModels

  # Add the files we generate using moc to the sources
  OBJECTS_PATH = $(OBJECTS_DIR)/$(OPTIMIZATION)/$(LINKING)

  MOC_SOURCES      += $(patsubst %.h,.gen/moc/tmp/%.cpp,$(HEADERS))
  RESOURCE_SOURCES += $(patsubst %.qrc,.gen/rc/tmp/%.cpp,$(RESOURCES))
  FORM_HEADERS     += $(patsubst $(FORMS_PATH)/%.ui,.gen/ui_%.h,$(FORMS))

  SOURCES += $(MOC_SOURCES)
  SOURCES += $(RESOURCE_SOURCES)
endif


#
# Security settings
#
ifeq ($(TARGET_PLATFORM),Darwin)
	#
	# Prevent dylib injection - this disallows using DYLD_INSERT_LIBRARIES with the application
	# (debugging application may require this, so this is only applied to release builds)
	#
	LFLAGS_release := $(LFLAGS_release) -Wl,-sectcreate,__RESTRICT,__restrict,/dev/null
endif


#
# Flags
#
CFLAGS_debug       := -DDEBUG  -g  -O0 $(CFLAGS_debug)
CFLAGS_profile     := -DNDEBUG -pg -O5 $(CFLAGS_profile)
CFLAGS_release     := -DNDEBUG     -O5 $(CFLAGS_release)
CFLAGS_static      := -DSTATIC -static $(CFLAGS_static)
CFLAGS_dynamic     := -DDYNAMIC  -fPIC $(CFLAGS_dynamic)
override CFLAGS    := $(patsubst %,-I%,$(INCLUDE_PATHS)) \
                      $(patsubst %,-D%,$(DEFINES)) \
                      $(CFLAGS_PLATFORM) \
                      $(CFLAGS_$(OPTIMIZATION)) \
                      $(CFLAGS_$(LINKING)) \
                      $(CFLAGS)
override CXXFLAGS  := $(CFLAGS) -std=c++11 $(CXXFLAGS)

LFLAGS_debug       := -g  $(LFLAGS_debug)
LFLAGS_profile     := -pg $(LFLAGS_profile)
LFLAGS_release     :=     $(LFLAGS_release)
LFLAGS_static      := -static $(LFLAGS_static)
LFLAGS_dynamic     := -fPIC   $(LFLAGS_dynamic)
override LFLAGS    := $(patsubst %,-L%,$(LIBRARY_PATHS)) \
                      $(patsubst %,-l%,$(LIBRARIES)) \
                      $(LFLAGS_PLATFORM) \
                      $(LFLAGS_$(OPTIMIZATION)) \
                      $(LFLAGS_$(LINKING)) \
                      $(LFLAGS)


#
# Commands
#
CC     = $(TOOLCHAIN_PREFIX)gcc
CXX    = $(TOOLCHAIN_PREFIX)g++
LINK   = $(TOOLCHAIN_PREFIX)g++
MKDIR  = mkdir -p
RM     = rm -f
MOC    = $(QTDIR)/bin/moc
UIC    = $(QTDIR)/bin/uic
RCC    = $(QTDIR)/bin/rcc
LINT   := $(dir $(lastword $(MAKEFILE_LIST)))Build/cpplint.py
TIDY   = clang-tidy


#
# Targets
#
OBJECTS_PATH       =  $(OBJECTS_DIR)/$(OPTIMIZATION)/$(LINKING)/tmp
COMPILED_OBJS      =  $(patsubst   %.c,$(OBJECTS_PATH)/%.o,$(filter   %.c,$(SOURCES)))
COMPILED_OBJS      += $(patsubst %.cpp,$(OBJECTS_PATH)/%.o,$(filter %.cpp,$(SOURCES)))
COMPILED_OBJS      += $(patsubst  %.mm,$(OBJECTS_PATH)/%.o,$(filter  %.mm,$(SOURCES)))
OBJECTS            += $(COMPILED_OBJS)
DEPENDS            =  $(OBJECTS_PATH)/.depend
LIBRARY            =  $(TARGET_DIR)/lib$(TARGET)$(TARGET_SUFFIX)
LIBRARY_static     =  $(LIBRARY).a
LIBRARY_dynamic    =  $(LIBRARY).so
TARGET_library     =  $(LIBRARY_$(LINKING))
TARGET_application =  $(TARGET_DIR)/$(TARGET)$(TARGET_SUFFIX)
TARGET_BINARY      =  $(TARGET_$(TEMPLATE))
MACOS_TARGET       =  $(TARGET).app/Contents/MacOS/$(TARGET)

ifeq ($(TARGET_PLATFORM),Darwin)
ALL_TARGET         =  $(MACOS_TARGET)
else
ALL_TARGET         =  $(TARGET_BINARY)
endif

#
# Rules
#
all: $(FORM_HEADERS) $(MOC_SOURCES) $(RESOURCE_SOURCES) $(DEPENDS) $(ALL_TARGET)

$(MACOS_TARGET): $(TARGET_BINARY)
	@$(MKDIR) $(dir $@)
	cp "$<" "$@"
	# TODO: This should be generated from project variables
	cp Info.plist "$(TARGET).app/Contents"
	# TODO: This stuff should be in the project file
	mkdir -p "$(TARGET).app/Contents/Resources/images"
	cp ../Resources/images/icon*  "$(TARGET).app/Contents/Resources/images/"
	cp .gen/WickedDocs.icns       "$(TARGET).app/Contents/Resources/"
	cp -Ra ../Resources/templates "$(TARGET).app/Contents/Resources/"
	# mkdir -p "$(TARGET).app/Contents/3rdParty"
	# cp -Ra ../3rdParty/pdf.js     "$(TARGET).app/Contents/3rdParty/"

$(TARGET_application): $(OBJECTS)
	@$(MKDIR) $(dir $@)
	$(LINK) $(LFLAGS_$(LINKING)) -o $@ $^ $(CXXFLAGS) $(LFLAGS)

$(LIBRARY_static): $(OBJECTS)
	@$(MKDIR) $(dir $@)
	ar rcs $@ $^ $(LFLAGS)

$(LIBRARY_dynamic): $(OBJECTS)
	@$(MKDIR) $(dir $@)
	$(LINK) $(LFLAGS_$(LINKING)) -shared -Wl,-soname,$(@).$(VERSION_MAJOR) -o $@.$(VERSION_MAJOR).$(VERSION_MINOR) $^ $(CXXFLAGS) $(LFLAGS)
	ln -s $@.$(VERSION_MAJOR).$(VERSION_MINOR) $@.$(VERSION_MAJOR)
	ln -s $@.$(VERSION_MAJOR) $@

# To work out dependancies, a simple non-gcc specific way is just depend on everything in the include dir:
# DEPENDS = $(patsubst %,$(INCLUDE_PATH)/%,$(HEADERS))
# But not every source depends on everything in the include dir, and it may not properly capture other dependancies.
# This solution is better, but GCC specific
$(DEPENDS): $(FORM_HEADERS) $(MOC_SOURCES) $(RESOURCE_SOURCES) # $(SOURCES) $(FORM_HEADERS)
	@echo Updating dependancies...
	@$(MKDIR) $(dir $@)
	@$(CC)  $(CFLAGS)   -MM $(filter   %.c,$(SOURCES)) | sed 's,^\(.*\.o\),$(OBJECTS_PATH)\/..\/\1,' >  $@
	@$(CXX) $(CXXFLAGS) -MM $(filter %.cpp,$(SOURCES)) | sed 's,^\(.*\.o\),$(OBJECTS_PATH)\/..\/\1,' >> $@
	@# $(foreach RES,$(RESOURCES),{ echo -n "$(patsubst %.qrc,$(OBJECTS_PATH)/rc/%.cpp,$(RES)): " ; $(RCC) --list $(RES) | tr '\n' ' ' ; } ' >> $@)
	@# $(foreach HEADER,$(HEADERS), $(shell echo $(OBJECTS_PATH)/moc/moc_$(basename $(notdir $(HEADER))).cpp: $(HEADER) >> $@))

debug:
	$(MAKE) OPTIMIZATION=debug

release:
	$(MAKE) OPTIMIZATION=release

profile:
	$(MAKE) OPTIMIZATION=profile

lint:
	$(LINT) --linelength=120 --filter=-whitespace $(SOURCES)

tidy:
	$(TIDY) -checks='c*,l*,m*' $(SOURCES) -- $(CXXFLAGS)

project:
	@echo > /dev/null

dependancies:
	@echo > /dev/null

$(OBJECTS_PATH)/%.o: %.c
	@$(MKDIR) $(dir $@)
	$(CC) -c -o $@ $< $(CFLAGS)

$(OBJECTS_PATH)/%.o: %.cpp
	@$(MKDIR) $(dir $@)
	$(CXX) -c -o $@ $< $(CXXFLAGS)

$(OBJECTS_PATH)/%.o: %.mm
	@$(MKDIR) $(dir $@)
	$(CXX) -c -o $@ $< $(CXXFLAGS)

# Qt rules
.gen/moc/tmp/%.cpp: %.h
	@$(MKDIR) $(dir $@)
	$(MOC) $(patsubst %,-D%,$(DEFINES)) $(patsubst %,-I%,$(INCLUDE_PATHS)) $< -o $@

.gen/ui_%.h: $(FORMS_PATH)/%.ui
	@$(MKDIR) $(dir $@)
	$(UIC) $< -o $@

.gen/rc/tmp/%.cpp: %.qrc
	@$(MKDIR) $(dir $@)
	$(RCC) -name $< $< -o $@


FAKE_TARGETS = debug release profile clean verify help all info project dependancies null
MAKE_TARGETS = $(MAKE) -rpn null | sed -n -e '/^$$/ { n ; /^[^ .\#][^ ]*:/ { s/:.*$$// ; p ; } ; }'
REAL_TARGETS = $(MAKE_TARGETS) | sort | uniq | grep -E -v $(shell echo $(FAKE_TARGETS) | sed 's/ /\\|/g')

null:

verify: test-report.txt
	@echo ""
	@echo " Test Results:"
	@echo "   PASS count: "`grep -c "PASS" test-report.txt`
	@echo "   FAIL count: "`grep -c "FAIL" test-report.txt`
	@echo ""

help:
	@echo ""
	@echo " Usage:"
	@echo "   $(MAKE) [target]"
	@echo ""
	@echo " Targets:"
	@echo "   "`$(MAKE_TARGETS)`
	@echo ""

info:
	@echo ""
	@echo " Info:"
	@echo "   $(LINKING) linking"
	@echo "   $(OPTIMIZATION) optimization"
	@echo "   $(TEMPLATE) template"
	@echo "   $(FRAMEWORK) framework"
	@echo "   target: $(TARGET_BINARY)"
	@echo ""
	@echo " Make targets:"
	@echo "   "`$(MAKE_TARGETS)`
	@echo " Real targets:"
	@echo "   "`$(REAL_TARGETS)`
	@echo " Fake targets:"
	@echo "   $(FAKE_TARGETS)"
	@echo ""

clean:
	@echo $(RM) `$(REAL_TARGETS)` $(DEPENDS) $(COMPILED_OBJS) core
	@$(RM) `$(REAL_TARGETS)` $(DEPENDS) $(COMPILED_OBJS) core

.PHONY: $(FAKE_TARGETS)


#
# Dependancies
#
-include $(DEPENDS)


