# Cross-compiles the Windows DLLs from Linux with MinGW-w64.
#
#   cmake -S . -B build-linux \
#       -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-mingw-w64.cmake \
#       -DCMAKE_BUILD_TYPE=Release
#
# Distro GCC packages (x86_64-w64-mingw32-g++) and llvm-mingw
# (x86_64-w64-mingw32-clang++) are both supported. "scripts/build-linux.sh"
# runs this and the packaging/verification steps for you.

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

set(TF2VRBB_MINGW_TRIPLE "x86_64-w64-mingw32" CACHE STRING "MinGW-w64 target triple")

find_program(TF2VRBB_MINGW_CXX NAMES
    "${TF2VRBB_MINGW_TRIPLE}-g++"
    "${TF2VRBB_MINGW_TRIPLE}-g++-posix"
    "${TF2VRBB_MINGW_TRIPLE}-g++-win32"
    "${TF2VRBB_MINGW_TRIPLE}-clang++")
find_program(TF2VRBB_MINGW_CC NAMES
    "${TF2VRBB_MINGW_TRIPLE}-gcc"
    "${TF2VRBB_MINGW_TRIPLE}-gcc-posix"
    "${TF2VRBB_MINGW_TRIPLE}-gcc-win32"
    "${TF2VRBB_MINGW_TRIPLE}-clang")

if(NOT TF2VRBB_MINGW_CXX OR NOT TF2VRBB_MINGW_CC)
    message(FATAL_ERROR
        "No MinGW-w64 compiler for ${TF2VRBB_MINGW_TRIPLE} was found.\n"
        "Install it first, for example:\n"
        "  Debian/Ubuntu: sudo apt install g++-mingw-w64-x86-64\n"
        "  Arch:          sudo pacman -S mingw-w64-gcc\n"
        "  Fedora:        sudo dnf install mingw64-gcc-c++\n"
        "or point TF2VRBB_MINGW_TRIPLE at another installed toolchain.")
endif()

set(CMAKE_C_COMPILER "${TF2VRBB_MINGW_CC}" CACHE FILEPATH "")
set(CMAKE_CXX_COMPILER "${TF2VRBB_MINGW_CXX}" CACHE FILEPATH "")

# Programs used while configuring (git, python) come from the host; libraries
# and headers come from the target toolchain.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
