#
# Makefile
# Copyright 2019
# by John Ryland
#

#
# This is a more function based approach similar to cmake
# The motivation here is that of wanting to specify multiple targets
# in a given project as well as listing tests, libraries etc.
#
# It also has some extended vim integrations with a project tree and
# using cscopes in addition to ctags. There is SVN integration to show
# the status of files. It can build release and debug versions of targets
# and can run doxygen to generate docs
#

# Allow variables to be expanded again on a second pass
.SECONDEXPANSION:

BASENAME      = $(shell basename $(PWD))
PLATFORM      = $(shell uname -s)
ARCH          = $(shell uname -m)
COMPILER      = $(shell c++ --version | tr [a-z] [A-Z] | grep -o 'CLANG\|GCC' | head -n 1)
COMPILER_VER  = $(shell c++ --version | grep -o "[0-9]*\.[0-9]*" | head -n 1)
PROJECT_FILE  = $(BASENAME).pro

CXX           = g++
CXX_FLAGS     = -Wall -Wextra -std=c++17 -I. $(patsubst %, -I%, $(INCLUDE_PATHS))
DEBUG_FLAGS   = -O0 -g --coverage
# DEBUG_FLAGS   = -O0 -g -pg
RELEASE_FLAGS = -O3 -DNDEBUG
TEST_FLAGS    = -DUNIT_TEST
SHARED_CXX_FLAGS = -fpic
SHARED_LD_FLAGS  = -fpic -shared
STATIC_CXX_FLAGS = -fno-pic -static -DSTATIC
STATIC_LD_FLAGS  = -fno-pic
TEST_LD_FLAGS    = --coverage

#
# TODO: Refactor the  dgb/rel  and shared/static permutations in to call functions with args to expand these
#

define AddCode
  $(1)_dbg_shared_OBJECTS = $(patsubst %.cpp, build/.objs/dbg/shared/%.o, $(2))
  $(1)_dbg_static_OBJECTS = $(patsubst %.cpp, build/.objs/dbg/static/%.o, $(2))
  $(1)_rel_shared_OBJECTS = $(patsubst %.cpp, build/.objs/rel/shared/%.o, $(2))
  $(1)_rel_static_OBJECTS = $(patsubst %.cpp, build/.objs/rel/static/%.o, $(2))
  # OBJECTS += $$($(1)_dbg_shared_OBJECTS) $$($(1)_dbg_static_OBJECTS) $$($(1)_rel_shared_OBJECTS) $$($(1)_rel_static_OBJECTS)
  dbg_shared_OBJECTS += $$($(1)_dbg_shared_OBJECTS)
  dbg_static_OBJECTS += $$($(1)_dbg_static_OBJECTS)
  rel_shared_OBJECTS += $$($(1)_rel_shared_OBJECTS)
  rel_static_OBJECTS += $$($(1)_rel_static_OBJECTS)
  SOURCES += $(2)
endef

# Libs
define AddLibraryInternal
  $(eval $(call AddCode,$(1),$(2)))
  dbg_shared_LIBS += build/lib/lib$(1)_d.so
  dbg_static_LIBS += build/lib/lib$(1)_d.a
  rel_shared_LIBS += build/lib/lib$(1).so
  rel_static_LIBS += build/lib/lib$(1).a
  LIBS += build/lib/lib$(1)_d.so build/lib/lib$(1)_d.a build/lib/lib$(1).so build/lib/lib$(1).a
  TARGETS += $(1)
	$(1)_SOURCES = $(2)
  build/lib/lib$(1)_d.so: $$($(1)_dbg_shared_OBJECTS)
		$$(MAKE_TARGET_DIR)
		$$(CXX) $$(CXX_FLAGS) $$(DEBUG_FLAGS) $$(SHARED_LD_FLAGS) $$^ -o $$@
  build/lib/lib$(1)_d.a: $$($(1)_dbg_static_OBJECTS)
		$$(MAKE_TARGET_DIR)
		# $$(CXX) $$(CXX_FLAGS) $$(DEBUG_FLAGS) $$(STATIC_LD_FLAGS) $$^ -o $$@
		ar rcs $$@ $$^
  build/lib/lib$(1).so: $$($(1)_rel_shared_OBJECTS)
		$$(MAKE_TARGET_DIR)
		$$(CXX) $$(CXX_FLAGS) $$(RELEASE_FLAGS) $$(SHARED_LD_FLAGS) $$^ -o $$@
		strip -S $$@
  build/lib/lib$(1).a: $$($(1)_rel_static_OBJECTS)
		$$(MAKE_TARGET_DIR)
		# $$(CXX) $$(CXX_FLAGS) $$(RELEASE_FLAGS) $$(STATIC_LD_FLAGS) $$^ -o $$@
		ar rcs $$@ $$^
		strip -S $$@
endef
# AddLibrary function which can be called to add a library target to a project
AddLibrary = $(eval $(call AddLibraryInternal,$(1),$(2)))

# Plugins
define AddPluginInternal
  $(eval $(call AddCode,$(1),$(2)))
  dbg_shared_PLUGINS += build/plugins/$(1)_d.so
  dbg_static_PLUGINS += build/plugins/$(1)_d.a
  rel_shared_PLUGINS += build/plugins/$(1).so
  rel_static_PLUGINS += build/plugins/$(1).a
  PLUGINS += build/plugins/$(1)_d.so build/plugins/$(1)_d.a build/plugins/$(1).so build/plugins/$(1).a
  TARGETS += $(1)
  $(1)_SOURCES = $(2)
  build/plugins/$(1)_d.so: $$($(1)_dbg_shared_OBJECTS) $$$$(dbg_shared_LIBS)
		$$(MAKE_TARGET_DIR)
		$$(CXX) $$(CXX_FLAGS) $$(DEBUG_FLAGS) $$(SHARED_LD_FLAGS) $$^ -o $$@
  build/plugins/$(1)_d.a: $$($(1)_dbg_static_OBJECTS) $$$$(dbg_static_LIBS)
		$$(MAKE_TARGET_DIR)
		# $$(CXX) $$(CXX_FLAGS) $$(DEBUG_FLAGS) $$(STATIC_LD_FLAGS) $$^ -o $$@
		ar rcs $$@ $$^
  build/plugins/$(1).so: $$($(1)_rel_shared_OBJECTS) $$$$(rel_shared_LIBS)
		$$(MAKE_TARGET_DIR)
		$$(CXX) $$(CXX_FLAGS) $$(RELEASE_FLAGS) $$(SHARED_LD_FLAGS) $$^ -o $$@
		strip -S $$@
  build/plugins/$(1).a: $$($(1)_rel_static_OBJECTS) $$$$(rel_static_LIBS)
		$$(MAKE_TARGET_DIR)
		# $$(CXX) $$(CXX_FLAGS) $$(RELEASE_FLAGS) $$(STATIC_LD_FLAGS) $$^ -o $$@
		ar rcs $$@ $$^
		strip -S $$@
endef
# AddPlugin function which can be called to add a plugin target to a project
AddPlugin = $(eval $(call AddPluginInternal,$(1),$(2)))

# Exes
define AddExecutableInternal
  $(eval $(call AddCode,$(1),$(2)))
  dbg_shared_EXES += build/bin/$(1)_d
  dbg_static_EXES += build/bin/$(1)_static_d
  rel_shared_EXES += build/bin/$(1)
  rel_static_EXES += build/bin/$(1)_static
  EXES += build/bin/$(1)_d build/bin/$(1)_static_d build/bin/$(1) build/bin/$(1)_static
  TARGETS += $(1)
  $(1)_SOURCES = $(2)
  build/bin/$(1)_d: $$($(1)_dbg_shared_OBJECTS) $$$$(dbg_shared_LIBS)
		$$(MAKE_TARGET_DIR)
		$$(CXX) $$(CXX_FLAGS) $$(DEBUG_FLAGS) $$^ -o $$@
  build/bin/$(1)_static_d: $$($(1)_dbg_static_OBJECTS) $$$$(dbg_static_LIBS) $$$$(dbg_static_PLUGINS)
		$$(MAKE_TARGET_DIR)
		$$(CXX) $$(CXX_FLAGS) $$(DEBUG_FLAGS) $$(STATIC_LD_FLAGS) $$^ -o $$@
  build/bin/$(1): $$($(1)_rel_shared_OBJECTS) $$$$(rel_shared_LIBS)
		$$(MAKE_TARGET_DIR)
		$$(CXX) $$(CXX_FLAGS) $$(RELEASE_FLAGS) $$^ -o $$@
		strip -S $$@
  build/bin/$(1)_static: $$($(1)_rel_static_OBJECTS) $$$$(rel_static_LIBS) $$$$(rel_static_PLUGINS)
		$$(MAKE_TARGET_DIR)
		$$(CXX) $$(CXX_FLAGS) $$(RELEASE_FLAGS) $$(STATIC_LD_FLAGS) $$^ -o $$@
		strip -S $$@
endef
# AddExecutable function which can be called to add an executable target to a project
AddExecutable = $(eval $(call AddExecutableInternal,$(1),$(2)))

# Test Code
define AddTestCode
  $(1)_dbg_tests_OBJECTS  = $(patsubst %.cpp, build/.objs/dbg/tests/%.o, $(2))
  $(1)_rel_tests_OBJECTS  = $(patsubst %.cpp, build/.objs/rel/tests/%.o, $(2))
  dbg_tests_OBJECTS  += $$($(1)_dbg_tests_OBJECTS)
  rel_tests_OBJECTS  += $$($(1)_rel_tests_OBJECTS)
  SOURCES += $(2)
endef

# Tests
define AddTestInternal
  $(eval $(call AddTestCode,$(1),$(2)))

  # Debug
  TESTS += build/tests/$(1)_d.log
  build/tests/$(1)_d: $$($(1)_dbg_tests_OBJECTS) $$$$(dbg_static_LIBS)
		$$(MAKE_TARGET_DIR)
		$$(CXX) $$(CXX_FLAGS) $$(DEBUG_FLAGS) $$(STATIC_LD_FLAGS) $$(TEST_LD_FLAGS) $$^ -o $$@
  build/tests/$(1)_d.log: build/tests/$(1)_d
		# build/tests/$(1)_d | tee $$@
		build/tests/$(1)_d > $$@

  # Release
  TESTS += build/tests/$(1).log
  build/tests/$(1): $$($(1)_rel_tests_OBJECTS) $$$$(rel_static_LIBS)
		$$(MAKE_TARGET_DIR)
		$$(CXX) $$(CXX_FLAGS) $$(RELEASE_FLAGS) $$(STATIC_LD_FLAGS) $$(TEST_LD_FLAGS) $$^ -o $$@
  build/tests/$(1).log: build/tests/$(1)
		# build/tests/$(1) | tee $$@
		build/tests/$(1) > $$@

endef
# AddTest function which can be called to add a test to a project
AddTest = $(eval $(call AddTestInternal,$(1),$(2)))


# Targets
all: $$(TESTS) $$(PLUGINS) $$(LIBS) $$(EXES) .tags Docs/html/index.html lldb-nvim.json
	@cat build/tests/*.log | grep "FAIL"
	@grep -n "TO""DO:" Makefile $(SOURCES) *.h
	@echo "Successful Build"

clean:
	rm -rf build

# ctags
.tags:
	# $$(TESTS) $$(PLUGINS) $$(LIBS) $$(EXES)
	@echo "Rebuilding tags"
	@cscope -q -R -b $(SOURCES) *.h *.hpp
	@ctags -f $@ --tag-relative=yes --sort=yes --c++-kinds=+p --fields=+iaS --extras=+q $(SOURCES) *.h *.hpp

# Docs
Docs/html/index.html: Docs/Doxyfile $$(SOURCES) Docs
	doxygen Docs/Doxyfile 2>&1 | sed 's|${PWD}/\(.*\)|\1|' > build/doxygen.log


# Project
-include $(PROJECT_FILE)

MAKE_TARGET_DIR = @mkdir -p `dirname $@`


# TODO: It should be possible to combine the depends generation and compilation steps (gcc can output both, -MMD)

dbg_shared_DEPENDS = $(patsubst build/.objs/dbg/shared/%.o, build/.deps/dbg/shared/%.cpp.d, $(dbg_shared_OBJECTS))
dbg_static_DEPENDS = $(patsubst build/.objs/dbg/static/%.o, build/.deps/dbg/static/%.cpp.d, $(dbg_static_OBJECTS))
dbg_tests_DEPENDS = $(patsubst build/.objs/dbg/tests/%.o, build/.deps/dbg/tests/%.cpp.d, $(dbg_tests_OBJECTS))

rel_shared_DEPENDS = $(patsubst build/.objs/rel/shared/%.o, build/.deps/rel/shared/%.cpp.d, $(rel_shared_OBJECTS))
rel_static_DEPENDS = $(patsubst build/.objs/rel/static/%.o, build/.deps/rel/static/%.cpp.d, $(rel_static_OBJECTS))
rel_tests_DEPENDS = $(patsubst build/.objs/rel/tests/%.o, build/.deps/rel/tests/%.cpp.d, $(rel_tests_OBJECTS))



$(dbg_shared_DEPENDS): build/.deps/dbg/shared/%.cpp.d: %.cpp
	$(MAKE_TARGET_DIR)
	$(CXX) $(CXX_FLAGS) -MT $(patsubst %.cpp, build/.objs/dbg/shared/%.o, $<) -MQ dependancies -MQ .tags -MQ project -MM $< -MF $@ > /dev/null

$(dbg_static_DEPENDS): build/.deps/dbg/static/%.cpp.d: %.cpp
	$(MAKE_TARGET_DIR)
	$(CXX) $(CXX_FLAGS) -MT $(patsubst %.cpp, build/.objs/dbg/static/%.o, $<) -MM $< -MF $@ > /dev/null

$(dbg_tests_DEPENDS): build/.deps/dbg/tests/%.cpp.d: %.cpp
	$(MAKE_TARGET_DIR)
	$(CXX) $(CXX_FLAGS) -MT $(patsubst %.cpp, build/.objs/dbg/tests/%.o, $<) -MM $< -MF $@ > /dev/null


$(rel_shared_DEPENDS): build/.deps/rel/shared/%.cpp.d: %.cpp
	$(MAKE_TARGET_DIR)
	$(CXX) $(CXX_FLAGS) -MT $(patsubst %.cpp, build/.objs/rel/shared/%.o, $<) -MM $< -MF $@ > /dev/null

$(rel_static_DEPENDS): build/.deps/rel/static/%.cpp.d: %.cpp
	$(MAKE_TARGET_DIR)
	$(CXX) $(CXX_FLAGS) -MT $(patsubst %.cpp, build/.objs/rel/static/%.o, $<) -MM $< -MF $@ > /dev/null

$(rel_tests_DEPENDS): build/.deps/rel/tests/%.cpp.d: %.cpp
	$(MAKE_TARGET_DIR)
	$(CXX) $(CXX_FLAGS) -MT $(patsubst %.cpp, build/.objs/rel/tests/%.o, $<) -MM $< -MF $@ > /dev/null


$(dbg_shared_OBJECTS): build/.objs/dbg/shared/%.o: %.cpp build/.deps/dbg/shared/%.cpp.d
	$(MAKE_TARGET_DIR)
	# $(CXX) $(CXX_FLAGS) $(DEBUG_FLAGS) $(SHARED_CXX_FLAGS) -c $< -o $@  -MT $@ -MD -MF $@.d
	$(CXX) $(CXX_FLAGS) $(DEBUG_FLAGS) $(SHARED_CXX_FLAGS) -c $< -o $@

$(dbg_static_OBJECTS): build/.objs/dbg/static/%.o: %.cpp build/.deps/dbg/static/%.cpp.d
	$(MAKE_TARGET_DIR)
	$(CXX) $(CXX_FLAGS) $(DEBUG_FLAGS) $(STATIC_CXX_FLAGS) -c $< -o $@

$(dbg_tests_OBJECTS): build/.objs/dbg/tests/%.o: %.cpp build/.deps/dbg/tests/%.cpp.d
	$(MAKE_TARGET_DIR)
	$(CXX) $(CXX_FLAGS) $(DEBUG_FLAGS) $(TEST_FLAGS) $(STATIC_CXX_FLAGS) -c $< -o $@


$(rel_shared_OBJECTS): build/.objs/rel/shared/%.o: %.cpp build/.deps/rel/shared/%.cpp.d
	$(MAKE_TARGET_DIR)
	$(CXX) $(CXX_FLAGS) $(RELEASE_FLAGS) $(SHARED_CXX_FLAGS) -c $< -o $@

$(rel_static_OBJECTS): build/.objs/rel/static/%.o: %.cpp build/.deps/rel/static/%.cpp.d
	$(MAKE_TARGET_DIR)
	$(CXX) $(CXX_FLAGS) $(RELEASE_FLAGS) $(STATIC_CXX_FLAGS) -c $< -o $@

$(rel_tests_OBJECTS): build/.objs/rel/tests/%.o: %.cpp build/.deps/rel/tests/%.cpp.d
	$(MAKE_TARGET_DIR)
	$(CXX) $(CXX_FLAGS) $(RELEASE_FLAGS) $(TEST_FLAGS) $(STATIC_CXX_FLAGS) -c $< -o $@


.PHONY: all clean project dependancies paths system_paths debug vim_project_support

-include $(dbg_shared_DEPENDS)
-include $(dbg_static_DEPENDS)
-include $(dbg_tests_DEPENDS)

-include $(rel_shared_DEPENDS)
-include $(rel_static_DEPENDS)
-include $(rel_tests_DEPENDS)

debug:
		@echo "BASENAME     = $(BASENAME)"
		@echo "PROJECT_FILE = $(PROJECT_FILE)"
		@echo "PLATFORM     = $(PLATFORM)"
		@echo "ARCH         = $(ARCH)"
		@echo "COMPILER     = $(COMPILER)"
		@echo "VERSION      = $(COMPILER_VER)"

define item_svn_status
  $(eval TMP := $(word 1,$(subst _, ,$(filter %$(abspath $F),$(SVN_ST)))))$(if $(TMP),$(TMP), )
endef

define generate_versioned_tree_items
	@printf '$(2)'
	$(eval ITEMS := $(3))
	$(eval LAST := $(if $(ITEMS),$(word $(words $(ITEMS)), $(ITEMS)),))
	@printf '$(foreach F, $(ITEMS),\n$(1) $(if $(filter $F,$(LAST)),┗━,┣━)$(call item_svn_status) $(notdir $F)\t\t\t\t\t\t\t $(abspath $F))\n'

endef

# $(foreach F, $(ITEMS),$(call show_target_tree,$(1),$(if $(filter $(F),$(LAST)),b┗━,a┣━),$(F),$(if $(filter $(F),$(LAST)), ,┃)))
define show_target_tree
	$(eval LAST2 := $(4))
	$(eval TOK1 := $(if $(filter $(3),$(LAST2)),┗━,┣━))
	$(eval TOK2 := $(if $(filter $(3),$(LAST2)),\ ,┃))
	$(eval TOK3 := $(if $(filter $(3),$(LAST2)),,┃  ┃\n))
	@printf '$(1) $(TOK1) $(3)'
	$(eval DEPS := $($(3)_SOURCES))
	$(call generate_versioned_tree_items,$(1) $(TOK2)\ , ,$(filter %.cpp,$(DEPS)))
	@printf '$(TOK3)'
endef

define generate_tree_items
	@printf '$(2)'
	$(eval ITEMS := $(3))
	@printf '\n┃  ┃ \n'
	$(eval LAST1 := $(if $(ITEMS),$(word $(words $(ITEMS)), $(ITEMS)),))
	$(foreach F, $(ITEMS),$(call show_target_tree,$(1), ,$(F),$(LAST1)))
endef

# $(call generate_versioned_tree_items,┃     ┃ ,┃     ┗━ Includes, $(filter   %.h,$(DEPS)))
# $(eval DEPS := $(shell make -n build/$(LAST) | grep " .*\.cpp " | sed 's/.* \(.*\)\.cpp .*/\1.cpp /g' | tr -d '\n'))
# $(eval DEPS := $($(LAST)_SOURCES))
# @printf '$(foreach F, $(ITEMS), \n $(F)  )\n'
# @printf '$(eval $(foreach F, $(ITEMS), \n $(F)))\n'
# @printf '$(foreach F, $(ITEMS),\n$(1) ┣━ $F ┃     ┣━ Sources $(I2))\n'
# @printf '$(foreach F, $(ITEMS),\n$(1) ┣━ $F $(eval $(call generate_versioned_tree_items,┃     ┃ ,┃     ┣━ Sources, $(I2))))\n'
# @printf '$(foreach F, $(ITEMS), $(F) $($(LAST)_SOURCES) )\n'
# @printf '$(foreach F, $(ITEMS),\n$(1) $(if $(filter $F,$(LAST)),┗━,┣━) $F $(eval $(call generate_versioned_tree_items,┃     ┃ ,┃     ┣━ Sources, $(I2))))\n'
# @printf '$(foreach F, $(ITEMS),\n$(1) $(if $(filter $F,$(LAST)),┗━,┣━) $F $(call generate_versioned_tree_items,┃     ┃ ,┃     ┣━ Sources, $(filter %.cpp,$(DEPS))))\n'

vim_project_support:
	@echo 'true'

project:
	@printf '$(PROJECT)\n┃\n'
	$(eval SVN_ST := $(shell svn st `svn info --show-item wc-root` | tr ' ' '_'))
	$(call generate_tree_items,┃ ,┣━ Targets, $(filter  %,$(TARGETS)))
	$(call generate_versioned_tree_items,┃ ,┃\n┣━ Sources,  $(filter %.cpp,$^))
	$(call generate_versioned_tree_items,┃ ,┃\n┣━ Includes, $(filter   %.h,$^))
	$(call generate_versioned_tree_items,┃ ,┃\n┣━ Docs,     $(filter  %.md,$(DOCS)))
	$(call generate_versioned_tree_items,  ,┃\n┗━ Project,  $(filter-out %.d,$(MAKEFILE_LIST)))

# Output the user search paths (for vim/editor integration)
paths:
	@echo $(INCLUDE_PATHS)

# Output the searched system paths the compiler will use (for vim/editor integration)
system_paths:
	@echo | $(CXX) -Wp,-v -x c++ - -fsyntax-only 2>&1 | grep "^ " | grep -v "(" | tr -d "\n"

dependancies:
	@echo $(patsubst %,\'%\',$^)

# TODO: doesn't work with multiple calls to AddApplication, can only be one target, perhaps need a DEBUG_TARGET in .pro file?
lldb-nvim.json: $(PROJECT_FILE)
	@echo ' {' > $@
	@echo '   "variables": { "target": "'$(dbg_shared_EXES)'" },' >> $@
	@echo '   "modes": { "code": {}, "debug": { ' >> $@
	@echo '      "setup": [ "target create {target}", [ "bp", "set" ] ], "teardown": [ [ "bp", "save" ], "target delete" ] ' >> $@
	@echo '   } },' >> $@
	@echo '   "breakpoints": { "@ll": [ ] }' >> $@
	@echo ' }' >> $@

