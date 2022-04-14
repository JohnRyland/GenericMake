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

CC            = cc
CXX           = c++
LINK          = c++
STRIP         = strip
LINKER        = c++
CTAGS         = ctags
DOCGEN        = pandoc -f markdown_mmd
C_FLAGS       = $(BUILD_TYPE_FLAGS) $(CFLAGS) $(DEFINES:%=-D%) $(INCLUDES:%=-I%)
CXX_FLAGS     = $(CXXFLAGS) $(C_FLAGS)
LINK_FLAGS    = $(LFLAGS) $(LIBRARIES:%=-l%)
STRIP_FLAGS   = -S
OUTPUT_DIR    = $(TEMP_DIR)/$(BUILD_TYPE)
CODE          = $(filter %.c %.cpp %.S,$(SOURCES))
OBJECTS       = $(CODE:%=$(OUTPUT_DIR)/objs/%.o)
SUBDIRS       = $(patsubst %/Makefile,%/subdir_target,$(SOURCES))
DEPENDS       = $(OBJECTS:$(OUTPUT_DIR)/objs/%.o=$(OUTPUT_DIR)/deps/%.d)
PDFS          = $(patsubst %.md,docs/%.pdf,$(DOCS))
CURRENT_DIR   = $(patsubst %/,%,$(abspath ./))
BASENAME      = $(notdir $(CURRENT_DIR))
PLATFORM      = $(UNAME)
COMPILER      = $(shell $(CXX) --version | tr [a-z] [A-Z] | grep -o -i 'CLANG\|GCC' | head -n 1)
COMPILER_VER  = $(shell $(CXX) --version | grep -o "[0-9]*\.[0-9]" | head -n 1)
MAKEFILE      = $(abspath $(firstword $(MAKEFILE_LIST)))
MAKEFILE_DIR  = $(notdir $(patsubst %/,%,$(dir $(MAKEFILE))))
PROJECT_FILE  = $(BASENAME).pro


######################################################################
##  Build type options (overridden for different build types)

BUILD_TYPE        = release
BUILD_TYPE_FLAGS  = -DNDEBUG
BUILD_TYPE_SUFFIX =

all: release


######################################################################
##  Project

-include $(PROJECT_FILE)

# Allow variables to be expanded again on a second pass
.SECONDEXPANSION:


######################################################################
##  Output destinations

TARGET_DIR   = bin
TEMP_DIR     = .build
MODULES_DIR  = .modules
TARGET_BIN   = $(TARGET_DIR)/$(TARGET)$(BUILD_TYPE_SUFFIX)$(TARGET_EXT)
TAGS         = $(TEMP_DIR)/tags
TEST_REPORT  = $(TEMP_DIR)/test-report.txt
TEST_XML_DIR = $(TEMP_DIR)/Testing


######################################################################
##  Package/Module management

# Rules for getting git modules
$(MODULES_DIR)/%/.git:
	@echo "Fetching module: $(@:$(MODULES_DIR)/%/.git=%)"
	@git clone $(filter %$(@:$(MODULES_DIR)/%/.git=%.git),$(MODULES)) $(@:%/.git=%) 2> /dev/null

# Rules for downloading .tar.gz modules
.cache/%.tar.gz:
	@echo "Downloading module: $(@:.cache/%.tar.gz=%)"
	@curl -L $(filter %$(@:.cache/%=%),$(MODULES)) --create-dirs -o $@ 2> /dev/null

# Rules for extracting .tar.gz modules
$(MODULES_DIR)/%/.extracted.tar.gz: .cache/%.tar.gz
	@echo "Extracting module: $(@:$(MODULES_DIR)/%/.extracted.tar.gz=%)"
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
LOG = echo -n $(call INDENT)$(subst ",,  --$(1)-------------------------------------------$(call POST_INDENT))\r


######################################################################
##  Build rules

compiling:
	@$(call LOG, Compiling $(BUILD_TYPE) build -----------)

strip: $(TARGET_BIN)
	@$(call LOG, Stripping -------------------------)
	@$(if $(wildcard $(TARGET_BIN)),$(STRIP) -S $(TARGET_BIN),)

run: $(TARGET_BIN)
	@$(call LOG, Running ---------------------------)
	@$(TARGET_BIN) --debug && echo PASSED

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

build: $(PROJECT_FILE) $(SUBDIRS) $(TAGS) modules $(MODULE_DEPS) docs $(PDFS) compiling $(TARGET_BIN) $(ADDITIONAL_DEPS) todos

build_and_run: build run done

release: build strip done

debug:
	@$(MAKE) -f $(MAKEFILE) BUILD_TYPE=debug BUILD_TYPE_FLAGS=-g BUILD_TYPE_SUFFIX=_d build_and_run

profile:
	@$(MAKE) -f $(MAKEFILE) BUILD_TYPE=profile BUILD_TYPE_FLAGS="-g -DNDEBUG" BUILD_TYPE_SUFFIX=_p build_and_run

test:
	@$(MAKE) -f $(MAKEFILE) BUILD_TYPE=test BUILD_TYPE_FLAGS="-g -DENABLE_UNIT_TESTS" BUILD_TYPE_SUFFIX=_t build verify done

$(PROJECT_FILE):
	@echo PROJECT      = $(BASENAME)> $@
	@echo TARGET       = $(BASENAME)>> $@
	@echo SOURCES      = $(wildcard *.c *.cpp)>> $@
	@echo DOCS         = $(wildcard *.md *.txt *.html)>> $@
	@echo DEFINES      = >> $@
	@echo INCLUDES     = >> $@
	@echo LIBRARIES    = m>> $@
	@echo CFLAGS       = -Wall>> $@
	@echo CXXFLAGS     = -std=c++11>> $@
	@echo LFLAGS       = >> $@

$(TAGS): $(patsubst %, ./%, $(CODE) $(wildcard *.h) $(foreach incdir,$(INCLUDES),$(wildcard incidr/*.h)))
	@$(call LOG, Updating tags ---------------------)
	@$(if $^,$(CTAGS) --tag-relative=yes --c++-kinds=+pl --fields=+iaS --extra=+q --language-force=C++ -f $@ $^ 2> $(NULL),)


######################################################################
##  Implicit rules

.SUFFIXES: .cpp .c

$(OUTPUT_DIR)/deps/%.cpp.d: %.cpp
	@$(call MKDIR,$(dir $@))
	@$(CXX) $(CXX_FLAGS) -MT $(patsubst %.cpp, $(OUTPUT_DIR)/objs/%.cpp.o, $<) -MQ dependancies -MQ $(TAGS) -MQ project -MD -E $< -MF $@ > $(NULL)

$(OUTPUT_DIR)/deps/%.c.d: %.c
	@$(call MKDIR,$(dir $@))
	@$(CC) $(C_FLAGS) -MT $(patsubst %.c, $(OUTPUT_DIR)/objs/%.c.o, $<) -MQ dependancies -MQ $(TAGS) -MQ project -MD -E $< -MF $@ > $(NULL)

$(OUTPUT_DIR)/objs/%.cpp.o: %.cpp $(OUTPUT_DIR)/deps/%.cpp.d
	@$(call MKDIR,$(dir $@))
	$(CXX) $(CXX_FLAGS) -c $< -o $@

$(OUTPUT_DIR)/objs/%.c.o: %.c $(OUTPUT_DIR)/deps/%.c.d
	@$(call MKDIR,$(dir $@))
	$(CC) $(C_FLAGS) -c $< -o $@

docs/%.pdf: %.md $(DOC_TEMPLATE)
	@$(call MKDIR,$(dir $@))
	$(DOCGEN) $(if $(DOC_TEMPLATE),--template $(DOC_TEMPLATE),) $< -o $@

%/subdir_target:
	@# $(call LOG, Start building sub-directory ------)
	@echo $(call INDENT) --  $(patsubst %/subdir_target,%,$@)  --
	@$(MAKE) -C $(patsubst %/subdir_target,%,$@) BUILD_TYPE=$(BUILD_TYPE) BUILD_TYPE_FLAGS="$(BUILD_TYPE_FLAGS)" BUILD_TYPE_SUFFIX=$(BUILD_TYPE_SUFFIX) build
	@# $(call LOG, End building sub-directory --------)


######################################################################
##  Compile target

$(TARGET_BIN): $(MODULE_DEPS) $(OBJECTS) $(DEPENDS)
	@$(call MKDIR,$(dir $@))
	@$(call LOG, Linking ---------------------------)
	@$(if $(strip $(OBJECTS)),$(LINKER) $(LINK_FLAGS) $(OBJECTS) -o $@,)
	@$(call LOG, Finished compiling $(BUILD_TYPE) build --)

-include $(DEPENDS)


######################################################################
##  Run unit tests

$(TEST_XML_DIR)/%.xml: ${TARGET_BIN}
	@mkdir -p $(dir $@)
	@echo Running $(patsubst $(TEST_XML_DIR)/%.xml,%,$@) unit test
	@$< --filter=$(patsubst $(TEST_XML_DIR)/%.xml,%,$@) --output=$@
	@$(call LOG,------------------------------------)

$(TEST_REPORT): $(TARGET_BIN)
	@make $(patsubst %,$(TEST_XML_DIR)/%.xml,$(shell $< --list-tests)) > $@


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

define generate_tree_items
	@printf '$(2)'
	$(eval ITEMS := $(3))
	$(eval LAST := $(if $(ITEMS),$(word $(words $(ITEMS)), $(ITEMS)),))
  @printf '$(foreach F, $(ITEMS),\n$(1) $(if $(filter $F,$(LAST)),┗━,┣━) $(notdir $F) \t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t $(abspath $F))\n'
endef

project:
	@printf '$(PROJECT)\n┃\n'
	$(call generate_tree_items,┃ ,┣━ Targets,    $(filter %,$(TARGET)))
	$(call generate_tree_items,┃ ,┃\n┣━ Sources, $(filter %.c,$^) $(filter %.cpp,$^))
	$(call generate_tree_items,┃ ,┃\n┣━ Headers, $(filter-out /%,$(filter %.h,$^) $(filter %.hpp,$^)))
	$(call generate_tree_items,┃ ,┃\n┣━ Docs,    $(filter %.md,$(DOCS)) $(filter %.txt,$(DOCS)) $(filter %.html,$(DOCS)))
	$(call generate_tree_items,  ,┃\n┗━ Project, $(wildcard $(filter-out %.d,$(MAKEFILE_LIST))))

vim_project_support:
	@printf '$(if $(PROJECT),true,false)\n'

# Output the user search paths (for vim/editor integration)
paths:
	@echo $(INCLUDES)

# Output the searched system paths the compiler will use (for vim/editor integration)
system_paths:
	@echo | $(CXX) -Wp,-v -x c++ - -fsyntax-only 2>&1 | grep "^ " | grep -v "(" | tr -d "\n"

dependancies:
	@echo $(patsubst %,\'%\',$^)

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

FAKE_TARGETS = debug release profile test clean purge verify help all info project paths system_paths dependancies null compiling todos build strip run done build_and_run modules docs
MAKE_TARGETS = $(MAKE) -f $(MAKEFILE) -rpn null | sed -n -e '/^$$/ { n ; /^[^ .\#][^ ]*:/ { s/:.*$$// ; p ; } ; }' | grep -v "$(TEMP_DIR)/"
REAL_TARGETS = $(MAKE_TARGETS) | sort | uniq | grep -E -v $(shell echo $(FAKE_TARGETS) | sed 's/ /\\|/g')

null:

verify: $(TEST_REPORT)
	@echo ""
	@echo " Test Results:"
	@echo "   PASS count: "`grep -c "PASS" $<`
	@echo "   FAIL count: "`grep -c "FAIL" $<`
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
	@echo "   BASENAME     = $(BASENAME)"
	@echo "   MAKEFILE_DIR = $(MAKEFILE_DIR)"
	@echo "   PROJECT_FILE = $(PROJECT_FILE)"
	@echo "   PLATFORM     = $(PLATFORM)"
	@echo "   ARCH         = $(ARCH)"
	@echo "   COMPILER     = $(COMPILER)"
	@echo "   VERSION      = $(COMPILER_VER)"
	@echo ""
	@echo " Make targets:"
	@echo "   "`$(MAKE_TARGETS)`
	@echo " Real targets:"
	@echo "   "`$(REAL_TARGETS)`
	@echo " Fake targets:"
	@echo "   $(FAKE_TARGETS)"
	@echo ""

clean:
	$(DEL) $(wildcard $(subst /,$(SEPERATOR),$(TAGS) $(OBJECTS) $(PDFS) $(DEPENDS) $(TARGET_BIN)))

.PHONY: $(FAKE_TARGETS)

