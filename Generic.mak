######################################################################
##  Copyright

#  Universal Simple Makefile
#  (C) Copyright 2017-2022
#  John Ryland
#  
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#  
#  1. Redistributions of source code must retain the above copyright notice, this
#     list of conditions and the following disclaimer. 
#  2. Redistributions in binary form must reproduce the above copyright notice,
#     this list of conditions and the following disclaimer in the documentation
#     and/or other materials provided with the distribution.
#  
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
#  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
#  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


######################################################################
##  Description

#  Simple boilerplate of a Makefile where you don't need to provide anything,
#  it will generate a project file for you which you can customize if you like.
#
#  The project file will be initially populated with any source files in the
#  current directory. Header file dependancies are calculated automatically.
#
#  This is getting less simple now. It did avoid recursive make, however
#  it now does some recursion, mainly to gather lists of sources, but mostly
#  building from the top level make. The recursion can make it complicated
#  to understand what is happening.


######################################################################
##  Cross-platform settings

# Possible detections:
#  Windows:
#   uname -s => Windows_NT                  - From cmd.exe  (uname from scoop)
#   uname -s => MINGW64_NT-10.0-19044       - From git-bash.exe  (uname from msys)
#   uname -m => x86_64                      - From either
#   echo %OS% => Windows_NT                 - From either
#   echo %PROCESSOR_ARCHITECTURE% => AMD64  - Might depend
#  macOS:
#   $(UNAME) => Mac        - From make.exe
#   uname -s => Darwin     - From sh

UNAME = $(shell uname -s)

# Detect the platform
ifeq ($(OS),Windows_NT)
  PLATFORM   := Windows
  # TODO: detect if we have uname or not
else
  PLATFORM   := $(UNAME)
endif

# The version of make being used even when launched from cmd.exe is not acting 
# as though the host is windows, so not sure if need to keep this logic to
# branch on OS containing Windows when we need to change MKDIR, NULL etc.
# - Seems to depend on which make is called. There is mingw's make, and there
#   is another in scoop\shims\make.exe
# May need to test both
# - actually there are 4 combos to try. with the mingw make + mingw uname,
#   with scoop make + mingw uname, etc
#ifeq ($(UNAME),Windows_NT)
ifeq ($(UNAME),NoMingwToolsInstalled)
  ARCH       := $(PROCESSOR_ARCHITECTURE)
  DEL        := del /q
  RMDIR      := rmdir /s /q
  MKDIR       = IF NOT EXIST $(subst /,\,$(1)) mkdir $(subst /,\,$(1))
  GREP        = 
  NULL       := nul
  WHICH       = $(shell where $(1) 2> nul)
else
  ARCH       ?= $(shell uname -m)
  DEL        := rm 
  RMDIR      := rm -rf
  MKDIR       = mkdir -p $(1)
  GREP        = grep $(1) $(2) || true
  WHICH       = $(shell which $(1))
  NULL       := /dev/null
endif

# PLATFORM and ARCH are the host values
# TARGET_PLATFORM and TARGET_ARCH are the target's values

# Assume not cross-building as the default
TARGET_PLATFORM  = $(PLATFORM)
TARGET_ARCH      = $(ARCH)
TARGET_EXT      :=

ifeq ($(PLATFORM),Darwin)
  OPEN       := open $(1)
endif
ifeq ($(PLATFORM),Linux)
  OPEN       := xdg-open $(1)
endif
ifeq ($(PLATFORM),Windows)
  TARGET_EXT := .exe
  OPEN       := cmd /c start $(1)
  CC          = gcc
endif


######################################################################
##  Compiler, tools and options

CC           ?= gcc
CXX          ?= g++
STRIP        ?= strip
LINKER       ?= g++
CTAGS        ?= ctags
PANDOC       ?= pandoc
PANDOC_FLAGS  = -f markdown --template $(PANDOC_TEMPLATE) --resource-path=$(GENMAKE_DIR)pandoc
PANDOC_TEMPLATE = $(GENMAKE_DIR)pandoc/template.tex
DOXYGEN       = doxygen
GCOVR         = gcovr

ALL_INCLUDES  ?= $(sort $(shell $(MAKE) -s MAKE_FLAGS=-s FULL_SOURCES_IN= DEPENDS1= DEPENDS= DIRECT_SRCS= ALL_INCLUDES= $(PASS_THRU_ARGS) includes exported_includes))
ALL_INCLUDES_ := $(ALL_INCLUDES)
C_FLAGS       = $(CFLAGS) $(BUILD_TYPE_FLAGS) $(DEFINES:%=-D%) $(ALL_INCLUDES_:%=-I%)

CXX_FLAGS     = $(CXXFLAGS) $(C_FLAGS)
LINK_FLAGS    = $(LFLAGS) $(BUILD_TYPE_FLAGS)
LINK_LIBS     = $(LIBRARIES:%=-l%) $(LIBS)
STRIP_FLAGS   = -S
# MAKE_FLAGS    ?= -s

######################################################################
##  Project directories and files

# $(info Updating $(PROJECT_FILE) deps)

# adding FOR_FILE=path/filename.ext will build the target relative to the path. So if filename.ext is inside
# of an sub-project, and the target is 'debug', then it will build and run just the sub-project.

# BASE_DIR is set for sub-project builds and is the relative path to the sub-project
# output directories are prefixed with the sub-project paths to avoid collisions and for distinct intermediate targets
BASE_DIR     ?= $(if $(FOR_FILE),$(patsubst $(CURRENT_DIR)/%,%/,$(abspath $(dir $(FOR_FILE)))))
CUR_DIR       = $(realpath .)
OBJS_DIR      = $(OUTPUT_DIR)/objs
DEPS_DIR      = $(OUTPUT_DIR)/deps
DOCS_DIR      = $(OUTPUT_DIR)/docs

FULL_SOURCES_IN ?= $(shell $(MAKE) $(MAKE_FLAGS) ALL_SOURCES= DEPENDS= "ALL_INCLUDES=$(ALL_INCLUDES_)" FULL_SOURCES_IN= $(PASS_THRU_ARGS) sources exported_sources)
FULL_SOURCES_ABS_IN := $(sort $(abspath $(FULL_SOURCES_IN)))
ALL_SOURCES   ?= $(sort $(shell $(MAKE) $(MAKE_FLAGS) DEPENDS= DEPENDS1= ALL_SOURCES= FULL_SOURCES_IN= "ALL_INCLUDES=$(ALL_INCLUDES_)" $(PASS_THRU_ARGS) direct_sources exported_sources))
FULL_SOURCES   := $(FULL_SOURCES_ABS_IN)
ALL_SOURCES_CP := $(ALL_SOURCES)
ABS_SOURCES   = $(sort $(abspath $(ALL_SOURCES_CP)))
REL_SOURCES   = $(ABS_SOURCES:$(CUR_DIR)/%=%)
DIRECT_SRCS   ?= $(SOURCES:%=$(BASE_DIR)%)

CODE          = $(filter %.c %.cpp %.S,$(REL_SOURCES))
OBJECTS       = $(CODE:%=$(OBJS_DIR)/%.o)
DEPENDS       ?= $(OBJECTS:$(OBJS_DIR)/%.o=$(DEPS_DIR)/%.d)

CODE1          = $(filter %.c %.cpp %.S,$(DIRECT_SRCS))
OBJECTS1       = $(CODE1:%=$(OBJS_DIR)/%.o)
DEPENDS1      ?= $(OBJECTS1:$(OBJS_DIR)/%.o=$(DEPS_DIR)/%.d)

# ALL includes .pro and Makefile files, full is recursive and includes .pro and Makefiles
FULL_CODE     = $(filter %.h %.hpp %.c %.cpp %.S,$(sort $(FULL_SOURCES:$(CUR_DIR)/%=%)))

SUBDIRS       = $(patsubst %/Makefile,%/subdir_target,$(filter %/Makefile,$(SOURCES:%=$(BASE_DIR)%)))
SUBPROJECTS   = $(patsubst %.pro,%.subproject_target,$(filter %.pro,$(SOURCES:%=$(BASE_DIR)%)))
PDFS          = $(patsubst %.md,$(DOCS_DIR)/%.pdf,$(DOCS))
CURRENT_DIR   = $(patsubst %/,%,$(abspath ./))
BASENAME      = $(notdir $(CURRENT_DIR))
COMPILER      = $(shell $(CXX) --version | tr [a-z] [A-Z] | grep -o -i 'CLANG\|GCC\|MINGW' | head -n 1)
COMPILER_VER  = $(shell $(CXX) --version | grep -o "[0-9]*\.[0-9]" | head -n 1)
MAKEFILE      = $(abspath $(firstword $(MAKEFILE_LIST)))
MAKEFILE_DIR  = $(notdir $(patsubst %/,%,$(dir $(MAKEFILE))))
GENMAKE_DIR  := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SUB_BASENAME  = $(BASE_DIR)$(notdir $(BASE_DIR:%/=%))
SUB_PROJECT_FILE = $(if $(wildcard $(SUB_BASENAME).pro),$(SUB_BASENAME).pro,$(firstword $(wildcard $(BASE_DIR)*.pro) $(SUB_BASENAME).pro))
PROJECT_FILE ?= $(if $(FOR_FILE),$(SUB_PROJECT_FILE),$(if $(wildcard $(BASENAME).pro),$(BASENAME).pro,$(firstword $(wildcard *.pro) $(BASENAME).pro)))

VERSION       = 0.0.0
PACKAGE_NAME  = $(PROJECT)-$(VERSION)-$(TARGET_PLATFORM)-$(TARGET_ARCH)-$(BUILD_TYPE).zip
OUTPUT_FILE   = $(OUTPUT_DIR)/$(OUTPUT)


######################################################################
##  Build type options (overridden for different build types, defaults to release)

BUILD_TYPE        = release
BUILD_TYPE_FLAGS  = -DNDEBUG
BUILD_TYPE_SUFFIX =
PASS_THRU_ARGS2   = UNAME=$(UNAME) ARCH=$(ARCH) BUILD_TYPE=$(BUILD_TYPE) BUILD_TYPE_FLAGS="$(BUILD_TYPE_FLAGS)" BUILD_TYPE_SUFFIX=$(BUILD_TYPE_SUFFIX)
PASS_THRU_ARGS    = PROJECT_FILE=$(PROJECT_FILE) BASE_DIR=$(BASE_DIR) $(PASS_THRU_ARGS2)

all: release


######################################################################
##  Output destinations

TARGET_DIR   = bin
TEMP_DIR     = .build
OUTPUT_DIR  := $(TEMP_DIR)/$(PLATFORM)-$(BUILD_TYPE)
MODULES_DIR  = .modules
TARGET_BIN   = $(TARGET_DIR)/$(TARGET)$(BUILD_TYPE_SUFFIX)$(TARGET_EXT)
TAGS         = $(TEMP_DIR)/tags
TEST_REPORT  = $(OUTPUT_DIR)/Testing/$(BASE_DIR)test-report.txt
TEST_XML_DIR = $(OUTPUT_DIR)/Testing/$(BASE_DIR)/xml
# E is variable used for preserving leading whitespace when calling $(info)
E:=


######################################################################
##  Project

-include $(PROJECT_FILE)

# Allow variables to be expanded again on a second pass
.SECONDEXPANSION:


######################################################################
##  Package/Module management

# Rules for getting git modules
$(MODULES_DIR)/%/.git:
	@$(info Fetching module: $(@:$(MODULES_DIR)/%/.git=%))
	@git clone $(filter %$(@:$(MODULES_DIR)/%/.git=%.git),$(MODULES)) $(@:%/.git=%) 2> /dev/null

# Rules for downloading .tar.gz modules
.cache/%.tar.gz:
	@$(info Downloading module: $(@:.cache/%.tar.gz=%))
	@curl -L $(filter %$(@:.cache/%=%),$(MODULES)) --create-dirs -o $@ 2> /dev/null

# Rules for extracting .tar.gz modules
$(MODULES_DIR)/%/.extracted.tar.gz: .cache/%.tar.gz
	@$(info Extracting module: $(@:$(MODULES_DIR)/%/.extracted.tar.gz=%))
	@mkdir -p $(MODULES_DIR) ; cd $(MODULES_DIR) ; tar zxf $(@:$(MODULES_DIR)/%/.extracted.tar.gz=../.cache/%.tar.gz)
	@touch $@

# Fetches module dependencies (including build system) if not already retrieved. Avoids using
# git submodules (can be a pain to keep updated), modules should be orthogonal to the versioning
# system, so there shouldn't be a requirement to use git for either the module or parent project.
GIT_MODULES=$(filter %.git,$(patsubst %.git,$(MODULES_DIR)/%/.git,$(notdir $(MODULES))))                     # Dependencies on git modules
TGZ_MODULES=$(filter %.tar.gz,$(patsubst %.tar.gz,$(MODULES_DIR)/%/.extracted.tar.gz,$(notdir $(MODULES))))  # Dependencies on .tar.gz modules

MODULE_DEPS=$(GIT_MODULES) $(TGZ_MODULES)


######################################################################
##  Output/logging

INDENT = $(if $(filter-out 0,$(MAKELEVEL)),$(word $(MAKELEVEL), ">>" ">>>>" ">>>>>>" ">>>>>>>>" ">>>>>>>>>>" ">>>>>>>>>>>>"),"")
POST_INDENT = $(if $(filter-out 0,$(MAKELEVEL)),$(word $(MAKELEVEL), "----------" "--------" "------" "----" "--"),"------------")
LOG = $(info $(subst ",,$(call INDENT) --$(1)-------------------------------------------$(call POST_INDENT)))


######################################################################
##  Build rules

compiling:
	@$(call LOG, Compiling $(BUILD_TYPE) build -----------)

run: $(TARGET_BIN)
	@$(call LOG, Running ---------------------------)
	$(if $(wildcard $(TARGET_BIN)),cd $(OUTPUT_DIR) && $(abspath $(TARGET_BIN)) --debug && echo PASSED)

todos:
	@$(call LOG, Finding todos ---------------------)
	@$(call grep,"todo" $(sources) $(wildcard *.h))

done:
	@$(call LOG, Done ------------------------------)

purge:
	@$(call LOG, Purging ---------------------------)
	$(RMDIR) $(TEMP_DIR) $(TARGET_DIR) $(MODULES_DIR)

modules:
	@$(call LOG, Modules ---------------------------)

docs:
	@$(call LOG, Documentation ---------------------)

pdfs: $(PDFS)

build: $(PROJECT_FILE) $(SUBDIRS) $(TAGS) externals documentation compile $(SUBPROJECTS) todos

doxygen: $(DOCS_DIR)/html/index.html

compile: compiling $(TARGET_BIN) $(ADDITIONAL_DEPS)
	@$(call LOG, Finished compiling ----------------)

externals: modules $(MODULE_DEPS)
	@$(call LOG, Finished getting modules ----------)

documentation: docs # pdfs doxygen
	@$(call LOG, Finished creating documentation ---)

strip: $(OUTPUT_DIR)/$(TARGET_BIN)_stripped
	@$(call LOG, Stripped --------------------------)

coverage: $(OUTPUT_DIR)/coverage/index.html
	@$(call LOG, Finished creating coverage report -)

package: $(PACKAGE_NAME)
	@$(call LOG, Finished creating package ---------)

$(OUTPUT_FILE): run

open: $(OUTPUT_FILE)
	$(call OPEN, $<)

build_and_run: build run $(if $(OUTPUT),open) done

release:
	@$(MAKE) $(MAKE_FLAGS) -f $(MAKEFILE) UNAME=$(UNAME) ARCH=$(ARCH) BUILD_TYPE=release BUILD_TYPE_FLAGS="-O3 -DNDEBUG" BUILD_TYPE_SUFFIX="" build strip done

debug:
	@$(MAKE) $(MAKE_FLAGS) -f $(MAKEFILE) UNAME=$(UNAME) ARCH=$(ARCH) BUILD_TYPE=debug BUILD_TYPE_FLAGS="-O0 -g -DENABLE_DEBUG" BUILD_TYPE_SUFFIX=_d build_and_run

profile:
	@$(MAKE) $(MAKE_FLAGS) -f $(MAKEFILE) UNAME=$(UNAME) ARCH=$(ARCH) BUILD_TYPE=profile BUILD_TYPE_FLAGS="-O3 -g -DNDEBUG -DENABLE_BENCHMARKS" BUILD_TYPE_SUFFIX=_p build_and_run

test:
	@$(MAKE) $(MAKE_FLAGS) -f $(MAKEFILE) UNAME=$(UNAME) ARCH=$(ARCH) BUILD_TYPE=test BUILD_TYPE_FLAGS="-O0 -g --coverage -DENABLE_UNIT_TESTS" BUILD_TYPE_SUFFIX=_t build verify coverage done

$(PROJECT_FILE):
	@$(info Generating project file as $@)
	@echo 'PROJECT   = $(BASENAME)' > $@
	@echo 'TARGET    = $(BASENAME)' >> $@
	@echo 'SOURCES   = $(wildcard *.c *.cpp *.S)' >> $@
	@echo 'DOCS      = $(wildcard *.md *.txt *.html)' >> $@
	@echo 'DEFINES   = ' >> $@
	@echo 'INCLUDES  = ' >> $@
	@echo 'LIBRARIES = m' >> $@
	@echo 'CFLAGS    = -Wall' >> $@
	@echo 'CXXFLAGS  = -std=c++11' >> $@
	@echo 'LFLAGS    = ' >> $@

$(TAGS): $(FULL_CODE)
	@$(call LOG, Updating tags ---------------------)
	@$(call MKDIR,$(dir $@))
	@$(if $(call WHICH,$(CTAGS)),$(if $^,$(CTAGS) --tag-relative=yes --c++-kinds=+pl --fields=+iaS --extra=+q --language-force=C++ -f $@ $^ 2> $(NULL),),)


######################################################################
##  Implicit rules

.SUFFIXES: # delete the default suffixes
.SUFFIXES: .cpp .c .S .d .o

$(DEPS_DIR)/%.cpp.d: %.cpp $(MODULE_DEPS)
	@$(call MKDIR,$(dir $@))
	@$(CXX) $(CXX_FLAGS) -MT $(patsubst %.cpp, $(OBJS_DIR)/%.cpp.o, $<) -MQ dependancies -MQ $(TAGS) -MQ direct_sources -MQ project -MMD -E $< -MF $@ > $(NULL)

$(DEPS_DIR)/%.c.d: %.c $(MODULE_DEPS)
	@$(call MKDIR,$(dir $@))
	@$(CC) $(C_FLAGS) -MT $(patsubst %.c, $(OBJS_DIR)/%.c.o, $<) -MQ dependancies -MQ $(TAGS) -MQ direct_sources -MQ project -MMD -E $< -MF $@ > $(NULL)

$(DEPS_DIR)/%.S.d: %.S $(MODULE_DEPS)
	@$(call MKDIR,$(dir $@))
	@$(CC) $(C_FLAGS) -MT $(patsubst %.S, $(OBJS_DIR)/%.S.o, $<) -MQ dependancies -MQ $(TAGS) -MQ direct_sources -MQ project -MMD -E $< -MF $@ > $(NULL)

$(OBJS_DIR)/%.cpp.o: %.cpp $(DEPS_DIR)/%.cpp.d
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXX_FLAGS) -c $< -o $@

$(OBJS_DIR)/%.c.o: %.c $(DEPS_DIR)/%.c.d
	@$(call MKDIR,$(dir $@))
	$(CC) $(C_FLAGS) -c $< -o $@

$(OBJS_DIR)/%.S.o: %.S $(DEPS_DIR)/%.S.d
	@$(call MKDIR,$(dir $@))
	$(CC) $(C_FLAGS) -c $< -o $@


######################################################################
##  Compile target

$(TARGET_BIN): $(MODULE_DEPS) $(OBJECTS) $(DEPENDS) # $(OBJECTS)
	@$(call MKDIR,$(dir $@))
	@$(call LOG, Linking ---------------------------)
	$(if $(strip $(OBJECTS)),$(LINKER) $(LINK_FLAGS) $(OBJECTS) $(LINK_LIBS) -o $@,)
	$(if $(strip $(OBJECTS)),rm -f $(OBJECTS:%.o=%.gcda),)
	@$(call LOG, Finished compiling $(BUILD_TYPE) build --)

$(OUTPUT_DIR)/$(TARGET_BIN)_stripped: $(TARGET_BIN)
	@$(call MKDIR,$(dir $@))
	@$(call LOG, Stripping -------------------------)
	$(if $(strip $(OBJECTS)),$(STRIP) $(STRIP_FLAGS) $< -o $@,$(if $(TARGET),touch $@,))
	$(if $(strip $(OBJECTS)),cp $@ $<,)


######################################################################
##  Sub-directories (recursive make)

%/subdir_target:
	@$(call LOG, $< $(patsubst %/subdir_target,%,$@) -----------)
	@$(MAKE) $(MAKE_FLAGS) -C $(patsubst %/subdir_target,%,$@) $(PASS_THRU_ARGS) $(BUILD_TYPE)

%.subproject_target: %.pro
	@$(call LOG, $< ---------------)
	@$(MAKE) $(MAKE_FLAGS) PROJECT_FILE=$< BASE_DIR="$(dir $<)" $(PASS_THRU_ARGS2) $(BUILD_TYPE)


######################################################################
##  Coverage

$(OUTPUT_DIR)/coverage/index.html: $(TEST_REPORT)
	@$(call MKDIR,$(dir $@))
	@$(call LOG, Generating coverage report --------)
	$(if $(strip $(OBJECTS)),$(if $(call WHICH,$(GCOVR)),$(GCOVR) --html-details --object-directory $(OBJS_DIR) -o $@),touch $@)
	cat $(GENMAKE_DIR)gcovr/index.css >> $(OUTPUT_DIR)/coverage/index.css


######################################################################
##  Package

$(PACKAGE_NAME): $(PDFS) $(TARGET_BIN)
	@$(call LOG, Creating package ------------------)
	$(if $(call WHICH,zip),zip -j $(PACKAGE_NAME) $^)


######################################################################
##  PDFs

$(DOCS_DIR)/logo.pdf: $(LOGO)
	@$(call MKDIR,$(dir $@))
	$(if $(LOGO),$(if $(call WHICH,rsvg-convert),rsvg-convert -f pdf $< -o $@))
	@touch $@

$(DOCS_DIR)/%.meta:
	@$(call MKDIR,$(dir $@))
	@echo 'title:        $(PROJECT)' >> $@
	@echo 'subtitle:     $(BRIEF)' >> $@
	@echo 'background:   $(GENMAKE_DIR)pandoc/background.pdf' >> $@
	@echo 'logo:         $(if $(LOGO),$(DOCS_DIR)/logo.pdf)' >> $@
	@echo 'author:       $(shell git config user.name)' >> $@

$(DOCS_DIR)/%.pdf: %.md $(PANDOC_TEMPLATE) $(DOCS_DIR)/logo.pdf $(DOCS_DIR)/%.meta
	@$(call MKDIR,$(dir $@))
	$(if $(call WHICH,$(PANDOC)),$(PANDOC) $(PANDOC_FLAGS) $< --resource-path=./:./$(dir $<) -o $@ --metadata-file=$(@:%.pdf=%.meta))
	#$(if $(call WHICH,$(PANDOC)),$(PANDOC) $(PANDOC_FLAGS) $< --resource-path=./:./$(dir $<) -o $(@:%.pdf=%.tex) --metadata-file=$(@:%.pdf=%.meta))
	#$(GENMAKE_DIR)/fixsvg.sh ./.build/tmp $(@:%.pdf=%.tex)
	#$(if $(call WHICH,pdflatex),pdflatex -interaction=batchmode -output-directory $(dir $@) $(@:%.pdf=%.tex) -o $@)


######################################################################
##  Doxygen

$(DOCS_DIR)/Doxyfile: $(PROJECT_FILE) $(FULL_CODE) $(DOCS)
	@$(call MKDIR,$(dir $@))
	@echo 'PROJECT_NAME           = $(PROJECT)' > $@
	@echo 'PROJECT_BRIEF          = $(BRIEF)' >> $@
	@echo 'PROJECT_LOGO           = $(LOGO)' >> $@
	@echo 'OUTPUT_DIRECTORY       = $(DOCS_DIR)' >> $@
	@echo 'INPUT                  = $(FULL_CODE) $(DOCS)' >> $@
	@echo 'USE_MDFILE_AS_MAINPAGE = $(firstword $(DOCS))' >> $@
	@echo 'LAYOUT_FILE            = $(GENMAKE_DIR)doxygen/layout.xml' >> $@
	@echo 'HTML_HEADER            = $(GENMAKE_DIR)doxygen/header.html' >> $@
	@echo 'HTML_FOOTER            = $(GENMAKE_DIR)doxygen/footer.html' >> $@
	@echo 'HTML_EXTRA_STYLESHEET  = $(GENMAKE_DIR)doxygen/style.css' >> $@
	@echo 'PLANTUML_JAR_PATH      = $(if $(call WHICH,plantuml),$(shell cat `which plantuml` | grep '/plantuml.jar' | sed 's/.* \(.*plantuml.jar\).*/\1/g'))' >> $@
	@echo 'HAVE_DOT               = $(if $(call WHICH,dot),YES,NO)' >> $@
	@echo 'DOT_PATH               = $(dir $(call WHICH,dot))' >> $@
	@cat $(GENMAKE_DIR)/doxygen/doxyfile.ini >> $@

$(DOCS_DIR)/html/index.html: $(DOCS_DIR)/Doxyfile $(FULL_CODE) $(DOCS)
	@$(call LOG, Doxygen ---------------------------)
	@# $(if $(call WHICH,$(DOXYGEN)),$(DOXYGEN) $< 2>&1 | sed 's|${PWD}/\(.*\)|\1|' > $(DOCS_DIR)/doxygen.log)
	@$(if $(call WHICH,$(DOXYGEN)),$(DOXYGEN) $< 2>&1 > $(DOCS_DIR)/doxygen.log)


######################################################################
##  Run unit tests

$(TEST_XML_DIR)/%.xml: ${TARGET_BIN}
	@mkdir -p $(dir $@)
	@$(info Running $(patsubst $(TEST_XML_DIR)/%.xml,%,$@) unit test)
	@$< --filter=$(patsubst $(TEST_XML_DIR)/%.xml,%,$@) --output=$@
	@$(call LOG,------------------------------------)

$(TEST_REPORT): $(TARGET_BIN)
	@mkdir -p $(dir $@)
	@$(if $(wildcard $<), $< --help > /dev/null,)  # For code coverage reasons we invoke the help
	$(if $(wildcard $<), @$(MAKE) $(patsubst %,$(TEST_XML_DIR)/%.xml,$(shell $< --list-tests)) > $@,touch $@)


######################################################################
##  Editor integrations

# 'editor integrations' are make targets that my vim settings use. These
# can be found here:
#
#   https://github.com/JohnRyland/VimSettings.git
#
# It detects if the makefile contains these special targets by running
#
#   make vim_project_support
#
# The targets then help to tell vim where to search for includes,
# other files in the project, debugging options etc. Possibly other
# editors might be able to be configured to do something similar.

define generate_tree_items2
	@$(if $(2), $(info $(2)))
	@$(info $(3))
	$(eval ITEMS := $(4))
	$(eval LAST := $(if $(ITEMS),$(word $(words $(ITEMS)), $(ITEMS)),))
	@$(info $(foreach F, $(ITEMS),$(info $(1) $(if $(filter $F,$(LAST)),┗━,┣━) $(notdir $F) \t $(abspath $F))))
endef

define generate_tree_items
	@printf '$(2)'
	$(eval ITEMS := $(3))
	$(eval LAST := $(if $(ITEMS),$(word $(words $(ITEMS)), $(ITEMS)),))
	@printf '$(foreach F, $(ITEMS),\n$(1) $(if $(filter $F,$(LAST)),┗━,┣━) $(notdir $F) \t $(abspath $F))\n' | expand -t 50
endef

project:
	@printf '$(PROJECT)\n┃\n'
	$(call generate_tree_items,┃ ,┣━ Targets,    $(filter %,$(TARGET)))
	$(call generate_tree_items,┃ ,┃\n┣━ Sources, $(filter %.c %.cpp %.S,$(FULL_SOURCES)))
	$(call generate_tree_items,┃ ,┃\n┣━ Headers, $(filter %.h %.hpp,$(FULL_SOURCES)))
	$(call generate_tree_items,┃ ,┃\n┣━ Subprojects, $(filter %.pro,$(FULL_SOURCES)))
	$(call generate_tree_items,┃ ,┃\n┣━ Docs,    $(filter %.md,$(DOCS)) $(filter %.txt,$(DOCS)) $(filter %.html,$(DOCS)))
	$(call generate_tree_items,  ,┃\n┗━ Project, $(wildcard $(filter-out %.d,$(MAKEFILE_LIST))))

vim_project_support:
	@printf '$(if $(PROJECT),true,false)\n'

# Output the user search paths (for vim/editor integration)
paths:
	@$(info $(INCLUDES))
	@:

# Output the searched system paths the compiler will use (for vim/editor integration)
system_paths:
	@echo | $(CXX) -Wp,-v -x c++ - -fsyntax-only 2>&1 | grep "^ " | grep -v "(" | tr -d "\n"

dependancies:
	@$(info $(patsubst %,'%',$^))
	@:

lldb-nvim.json: $(PROJECT_FILE)
	@echo ' {' > $@
	@echo '   "variables": { "target": "'$(TARGET_BIN)'" },' >> $@
	@echo '   "modes": { "code": {}, "debug": { ' >> $@
	@echo '      "setup": [ "target create {target}", [ "bp", "set" ] ], "teardown": [ [ "bp", "save" ], "target delete" ] ' >> $@
	@echo '   } },' >> $@
	@echo '   "breakpoints": { "@ll": [ ] }' >> $@
	@echo ' }' >> $@


######################################################################
##  Target management

FAKE_TARGETS = debug release profile test clean purge verify help all info project paths system_paths dependancies null compiling todos build strip run done build_and_run modules docs pdfs doxygen package
MAKE_TARGETS = $(MAKE) -f $(MAKEFILE) -rpn null | sed -n -e '/^$$/ { n ; /^[^ .\#][^ ]*:/ { s/:.*$$// ; p ; } ; }' | grep -v "$(TEMP_DIR)/"
REAL_TARGETS = $(MAKE_TARGETS) | sort | uniq | grep -E -v $(shell echo $(FAKE_TARGETS) | sed 's/ /\\|/g')

null:

verify: $(TEST_REPORT)
	@$(info $E)
	@$(info $E Test Results:)
	@$(info $E   PASS count: $(shell grep -c "PASS" $<))
	@$(info $E   FAIL count: $(shell grep -c "FAIL" $<))
	@$(info $E)
	@:

help:
	@$(info $E)
	@$(info $E Usage:)
	@$(info $E   $(MAKE) [target])
	@$(info $E)
	@$(info $E Targets:)
	@$(foreach target,$(shell $(MAKE_TARGETS)),$(info $E   $(target)))
	@$(info $E)
	@:

info:
	@$(info $E)
	@$(info $E Info:)
	@$(info $E   BASENAME        = $(BASENAME))
	@$(info $E   MAKEFILE_DIR    = $(MAKEFILE_DIR))
	@$(info $E   PROJECT_FILE    = $(PROJECT_FILE))
	@$(info $E   PLATFORM        = $(PLATFORM))
	@$(info $E   ARCH            = $(ARCH))
	@$(info $E   TARGET_PLATFORM = $(TARGET_PLATFORM))
	@$(info $E   TARGET_ARCH     = $(TARGET_ARCH))
	@$(info $E   COMPILER        = $(COMPILER))
	@$(info $E   VERSION         = $(COMPILER_VER))
	@$(info $E)
	@$(info $E Make targets:)
	@$(info $E   $(shell $(MAKE_TARGETS)))
	@$(info $E)
	@$(info $E Real targets:)
	@$(info $E   $(shell $(REAL_TARGETS)))
	@$(info $E)
	@$(info $E Fake targets:)
	@$(info $E   $(FAKE_TARGETS))
	@$(info $E)
	@:


clean:
	$(DEL) $(wildcard $(TAGS) $(OBJECTS) $(PDFS) $(DEPENDS) $(TARGET_BIN))

.PHONY: $(FAKE_TARGETS)


######################################################################
##  Modules and Sub-project Target helpers

MODULE_DIRS=$(dir $(MODULE_DEPS))
MODULE_PROS=$(wildcard $(MODULE_DIRS:%/=%/*.pro))
SUBPROJECT_SOURCE_TARGETS=$(SUBPROJECTS:%.subproject_target=%.subproject_sources)
SUBPROJECT_INCLUDE_TARGETS=$(SUBPROJECTS:%.subproject_target=%.subproject_includes)
MODULE_EXPORT_INCLUDE_TARGETS=$(MODULE_PROS:%.pro=%.subproject_exported_includes)
MODULE_EXPORT_SOURCE_TARGETS=$(MODULE_PROS:%.pro=%.subproject_exported_sources)

direct_includes:
	@printf '$(INCLUDES:%=$(BASE_DIR)%) $(INCLUDEPATH:%=$(BASE_DIR)%) '
direct_sources:
	@printf ' $(sort $(abspath $(filter-out /%,$(filter %.S %.c %.cpp %.h %.hpp,$^)) $(filter %.S %.c %.cpp %.h %.hpp %.pro,$(SOURCES:%=$(BASE_DIR)%)) $(MODULE_PROS:%=$(BASE_DIR)%))) '
direct_exported_includes:
	@printf '$(EXPORTED_INCLUDES:%=$(BASE_DIR)%) '
direct_exported_sources:
	@printf '$(EXPORTED_SOURCES:%=$(BASE_DIR)%) '

PASS_ARGS=$(MAKE_FLAGS) $(PASS_THRU_ARGS2) DEPENDS= ALL_SOURCES= FULL_SOURCES_IN= "ALL_INCLUDES=$(ALL_INCLUDES_)"

%.subproject_includes: %.pro
	@$(MAKE) $(PASS_ARGS) PROJECT_FILE=$< BASE_DIR="$(dir $<)" includes
%.subproject_sources: %.pro
	@$(MAKE) $(PASS_ARGS) PROJECT_FILE=$< BASE_DIR="$(dir $<)" sources
%.subproject_exported_includes: %.pro
	@$(MAKE) $(PASS_ARGS) PROJECT_FILE=$< BASE_DIR="$(dir $<)" direct_exported_includes
%.subproject_exported_sources: %.pro
	@$(MAKE) $(PASS_ARGS) PROJECT_FILE=$< BASE_DIR="$(dir $<)" direct_exported_sources

# Recursively gather all the sources of all the descendant projects
sources: direct_sources $(SUBPROJECT_SOURCE_TARGETS)
includes: direct_includes $(SUBPROJECT_INCLUDE_TARGETS)

# Non-recursively get the exported include paths and sources of the directly included modules
exported_includes: direct_exported_includes $(MODULE_EXPORT_INCLUDE_TARGETS)
exported_sources: direct_exported_sources $(MODULE_EXPORT_SOURCE_TARGETS)


# For debugging purposes, keep the depends files
.PRECIOUS: $(DEPENDS) $(DEPENDS1)

# Avoid looking for rules to generate Makefile
Makefile: ;

# Avoid looking for rules to generate our source files
$(SOURCES): ;

-include $(DEPENDS) $(DEPENDS1)

