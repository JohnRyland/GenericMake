
# GenericMake
### Simple generic Makefile based build/project system

Copyright (c) 2021-2022, John Ryland
All rights reserved.


## Introduction

This is a very light and simple build system which builds on top of standard make.
It has some similarities to qmake in that most of the project specific details of
what and how to build the project are inside a .pro project file. The syntax is also
similar, with VAR=valuei pairs. Because it is still just essentially a makefile though,
anything you can do in make you can put in to the .pro file too.


## How to use

There are two ways you can use this and integrate it in to your project. The
first is to simply copy the file 'Generic.mak' in to you project and rename it
to Makefile. This will fix the version of GenericMake used by the project until
it is manually updated by copying a new version over the top.

The second way is to copy the 'Bootstrap.mak' file in to your project as 'Makefile'.
It contains a small amount of bootstrap code which will clone this repo (if it needs to)
and then it includes the cloned Generic.mak file. This means that if you run 'make purge'
and then run 'make' again, you will be on the latest version. The purge target will
wipe away the clone and running make will fetch the latest copy.


