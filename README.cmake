In order to build Rivet with cmake, the following software is required:

a) cmake, version 3.2 or newer.

Compiling Rivet with cmake:
-------------------------------------------------------

1) Change the working directory to "cmake".

2) Execute the following commands (all commands must be executed from the
   "cmake" directory):

   cmake -E make_directory build
   cmake -E chdir build cmake ..
   cmake --build build --target all --clean-first
   cmake --build build --target install

3) To install mod_rivet.so/Rivet library to a custom location,
   the following commands can be used:

   cmake -E make_directory build
   cmake -E chdir build cmake \
     -DAPACHE_MODULE_DIR=/home/tcl/rivet/branches/cmake/cmake/test/modules \
     -DAPACHE_LIB_DIR=/home/tcl/rivet/branches/cmake/cmake/test/ ..
   cmake --build build --config Release --target install

4) To install mod_rivet.so/Rivet library in a system where Apache Server is not
   in a known location (i.e. under Windows), you can speficy APACHE_ROOT:

   cmake -E make_directory build
   cmake -E chdir build cmake -DAPACHE_ROOT=G:/Apache24 ..
   cmake --build build --config Release --target install

5) Compile for 64 bits under Windows (for Visual Studio 2017):

   cmake -E make_directory build_64
   cmake -E chdir build_64 cmake -DAPACHE_ROOT=G:/Apache24 -G "Visual Studio 15 2017 Win64" ..
   cmake --build build_64 --config Release --target install

   -G "..." can be set to any of the available 64-bit generators available under
   the platform.

6) Specify Tcl at a non standard location:

   cmake -E make_directory build_64
   cmake -E chdir build_64 cmake -DAPACHE_ROOT=G:/Apache24 -G "Visual Studio 15 2017 Win64" -Dwith-tcl=C:/TclApps/Tcl64/lib ..
   cmake --build build_64 --config Release --target install

   Instead of -Dwith-tcl=, -DTCL_ROOT=, -DTclStub_ROOT, and -DTCL_TCLSH= can be
   specified as an alternative.
