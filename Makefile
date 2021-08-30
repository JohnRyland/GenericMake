######################################################################
##  Copyright

#  Universal Simple Makefile
#  (C) Copyright 2017-2021
#  John Ryland


######################################################################
##  Description

#  Simple boilerplate of a Makefile where you don't
#  need to provide anything, it will generate a project
#  file for you which you can customize if you like.
#  The project file will be initially populated with
#  any source files in the current directory. Header
#  file dependancies are then automatically calculated.


######################################################################
##  Cross-platform settings

ifneq (,$(findstring Windows,$(OS)))
  UNAME      := Windows
  ARCH       := $(PROCESSOR_ARCHITECTURE)
  TARGET_EXT := .exe
  DEL        := del /q
  RMDIR      := rmdir /s /q
  SEPERATOR  := $(subst /,\,/)
  MKDIR       = if not exist $(subst /,\,$(1)) mkdir $(subst /,\,$(1))
  GREP        = 
  NULL       := nul
else
  UNAME      := $(shell uname -s)
  ARCH       := $(shell uname -m)
  TARGET_EXT :=
  DEL        := rm 
  RMDIR      := rm -rf
  SEPERATOR  := /
  MKDIR       = mkdir -p $(1)
  GREP        = grep $(1) $(2) || true
  NULL       := /dev/null
endif


######################################################################
##  Compiler, tools and options

CC           = cc
CXX          = c++
LINK         = c++
STRIP        = strip
LINKER       = c++
C_FLAGS      = $(CFLAGS) $(DEFINES) $(INCLUDES)
CXX_FLAGS    = $(CXXFLAGS) $(C_FLAGS)
LINK_FLAGS   = $(LFLAGS)
STRIP_FLAGS  = -S
OBJECTS      = $(SOURCES:%=$(TEMP_DIR)/.objs/%.o)
DEPENDS      = $(OBJECTS:$(TEMP_DIR)/.objs/%.o=$(TEMP_DIR)/.deps/%.d)
BASENAME     = $(notdir $(patsubst %/,%,$(abspath ./)))
PLATFORM     = $(UNAME)
COMPILER     = $(shell $(CXX) --version | tr [a-z] [A-Z] | grep -o -i 'CLANG\|GCC' | head -n 1)
COMPILER_VER = $(shell $(CXX) --version | grep -o "[0-9]*\.[0-9]" | head -n 1)
MAKEFILE_DIR = $(notdir $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST))))))
PROJECT_FILE = $(BASENAME).pro


######################################################################
##  Project

-include $(PROJECT_FILE)


######################################################################
##  Output destinations

TARGET_DIR   = bin
TEMP_DIR     = build
TARGET_BIN   = $(TARGET_DIR)/$(TARGET)$(TARGET_EXT)


######################################################################
##  Build rules

.PHONY: all clean purge debug

all: $(PROJECT_FILE) $(TARGET_BIN) $(ADDITIONAL_DEPS)
	@$(call GREP,"TODO" $(SOURCES) $(wildcard *.h))

clean:
	$(DEL) $(wildcard $(subst /,$(SEPERATOR),$(OBJECTS) $(DEPENDS) $(TARGET_BIN)))

purge:
	$(RMDIR) $(TEMP_DIR) $(TARGET_DIR)

debug:
	@echo BASENAME     = $(BASENAME)
	@echo MAKEFILE_DIR = $(MAKEFILE_DIR)
	@echo PROJECT_FILE = $(PROJECT_FILE)
	@echo PLATFORM     = $(PLATFORM)
	@echo ARCH         = $(ARCH)
	@echo COMPILER     = $(COMPILER)
	@echo VERSION      = $(COMPILER_VER)

$(PROJECT_FILE):
	@echo TARGET       = $(BASENAME)> $@
	@echo SOURCES      = $(wildcard *.c *.cpp)>> $@
	@echo CFLAGS       = -Wall>> $@
	@echo CXXFLAGS     = -std=c++11>> $@
	@echo LFLAGS       = >> $@


######################################################################
##  Implicit rules

.SUFFIXES: .cpp .c

$(TEMP_DIR)/.deps/%.cpp.d: %.cpp
	$(call MKDIR,$(dir $@))
	$(CXX) $(CXX_FLAGS) -MT $(patsubst %.cpp, $(TEMP_DIR)/.objs/%.cpp.o, $<) -MD -E $< -MF $@ > $(NULL)

$(TEMP_DIR)/.deps/%.c.d: %.c
	$(call MKDIR,$(dir $@))
	$(CC) $(C_FLAGS) -MT $(patsubst %.c, $(TEMP_DIR)/.objs/%.c.o, $<) -MD -E $< -MF $@ > $(NULL)

$(TEMP_DIR)/.objs/%.cpp.o: %.cpp $(TEMP_DIR)/.deps/%.cpp.d
	$(call MKDIR,$(dir $@))
	$(CXX) $(CXX_FLAGS) -c $< -o $@

$(TEMP_DIR)/.objs/%.c.o: %.c $(TEMP_DIR)/.deps/%.c.d
	$(call MKDIR,$(dir $@))
	$(CC) $(C_FLAGS) -c $< -o $@


######################################################################
##  Compile target

$(TARGET_BIN): $(OBJECTS) $(DEPENDS)
	$(call MKDIR,$(dir $@))
	$(LINKER) $(LINK_FLAGS) $(OBJECTS) -o $@
	$(STRIP) -S $@

-include $(DEPENDS)

