#
#  Simple.inc
#  (C) Copyright 2017-2021
#  John Ryland
#
# Description:
#
#  Simple boilerplate of a makefile where what you need to provide is TARGET,
#  SOURCES and CFLAGS. Included file dependancies are automatically calculated
#  I have a more complex version of this which handles sub-directories and
#  sub-projects, but this is the most basic version which is reasonably
#  self-explainetary.
#
# Example usage:
#
#  TARGET = MyApp
#  SOURCES = myapp.cpp classA.cpp classB.cpp
#  CFLAGS = -I.
#  -include Simple.inc
#

OBJECTS = $(patsubst %.cpp, build/.objs/%.o, $(SOURCES))
DEPENDS = $(patsubst build/.objs/%.o, build/.deps/%.cpp.d, $(OBJECTS))

all: $(TARGET)

clean:
		rm -rf build

$(TARGET): $(OBJECTS) $(DEPENDS)
		c++ $(LFLAGS) $(OBJECTS) -o $@


.PHONY: all clean

build/.deps/%.cpp.d: %.cpp
		@mkdir -p `dirname $@`
		c++ $(CFLAGS) -MT $(patsubst %.cpp, build/.objs/%.o, $<) -MD -E $< -MF $@ > /dev/null

build/.objs/%.o: %.cpp build/.deps/%.cpp.d
		@mkdir -p `dirname $@`
		c++ $(CFLAGS) -c $< -o $@

-include $(DEPENDS)

