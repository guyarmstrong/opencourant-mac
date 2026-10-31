#!/bin/bash
# Build OpenCourant for macOS on Apple silicon (macosa64): the open reader,
# starter and engine (single precision, one engine on several threads, no MPI)
# and anim_to_vtk, into exec/.
#
# Needs Homebrew (or conda) with: gcc (gfortran), cmake, boost, metis, lapack.
#   OC_MAC_DEPS  prefix holding Boost / METIS / LAPACK / zlib  (default: brew --prefix)
#   THREADS      parallel build jobs                            (default: all cores)
#   PREC         sp | dp                                        (default: sp)
#   TOOLS_REF    OpenCourant/Tools commit for anim_to_vtk       (default: main)
set -euo pipefail
cd "$(dirname "$0")/../.."
root=$PWD
export OC_MAC_DEPS=${OC_MAC_DEPS:-$(brew --prefix)}
threads=${THREADS:-$(sysctl -n hw.ncpu)}
prec=${PREC:-sp}
# The open reader is C++ against the prefix's Boost: Apple clang / libc++.
# The starter and engine pick Homebrew GCC themselves (cmake_macosa64_gf_compilers.sh).
export CC=${READER_CC:-clang} CXX=${READER_CXX:-clang++}

echo "== macosa64 build: deps $OC_MAC_DEPS, $threads jobs, precision $prec"

# Recipes (idempotent: rewrites the macosa64 files from the linuxa64 ones).
python3 Compiling_tools/macos/make_recipes.py

# extlib: headers (H3D, md5, exprtk) and config; no macOS binaries in it.
python3 Compiling_tools/script/load_extlib.py

# md5: compiled here, checked against RFC 1321.
mkdir -p extlib/md5/macosa64 build_macos
clang -O2 -Iextlib/md5/include -c Compiling_tools/macos/md5.c -o build_macos/md5.o
ar rcs extlib/md5/macosa64/libmd5.a build_macos/md5.o
clang -O2 -Iextlib/md5/include Compiling_tools/macos/md5.c Compiling_tools/macos/md5_test.c -o build_macos/md5_test
build_macos/md5_test

# Starter (builds the open reader first, -open_reader) and engine.
(cd starter && ./build_script.sh -arch=macosa64_gf -prec=$prec -open_reader -release -no-python -nt=$threads)
(cd engine && ./build_script.sh -arch=macosa64_gf -prec=$prec -release -no-python -nt=$threads)

# anim_to_vtk: one C++ file in OpenCourant/Tools.
curl -fsSL "https://raw.githubusercontent.com/OpenCourant/Tools/${TOOLS_REF:-main}/output_converters/anim_to_vtk/src/anim_to_vtk.cpp" -o build_macos/anim_to_vtk.cpp
clang++ -O2 -DLINUX -o exec/anim_to_vtk_macosa64 build_macos/anim_to_vtk.cpp

echo "== built:"
ls -la exec/
for f in exec/*; do echo "-- $f"; otool -L "$f" 2>/dev/null | tail -n +2 || true; done
