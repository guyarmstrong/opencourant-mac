#!/bin/bash
# Make exec/ self-contained: copy every non-system dylib the programs use
# (Homebrew GCC runtime, Boost, METIS, LAPACK ...) next to them, point the
# programs at those copies (@executable_path) and ad-hoc sign everything, so
# exec/ runs on a Mac without Homebrew.
set -euo pipefail
cd "$(dirname "$0")/../../exec"

is_system() { case "$1" in /usr/lib/*|/System/*) return 0;; *) return 1;; esac; }

# Non-system dependencies of one Mach-O file (install names as written).
deps() { otool -L "$1" | tail -n +2 | awk '{print $1}' | while read -r d; do is_system "$d" || echo "$d"; done; }

# Where each bundled library came from (relative names in it are resolved there).
mkdir -p .src

# Resolve install name $1, needed by bundled file $2, to a file on this machine.
resolve() {
  local b; b=$(basename "$1")
  case "$1" in
    @rpath/*|@loader_path/*|@executable_path/*)
      if [ -f "./$b" ]; then echo "./$b"; return; fi
      if [ -f ".src/$2" ] && [ -f "$(cat ".src/$2")/$b" ]; then echo "$(cat ".src/$2")/$b"; return; fi
      for d in "${HOMEBREW_PREFIX:-/opt/homebrew}/lib" "${OC_MAC_DEPS:-/nonexistent}/lib"; do
        if [ -f "$d/$b" ]; then echo "$d/$b"; return; fi
      done ;;
    *) [ -f "$1" ] && echo "$1" ;;
  esac
}

# Copy dependencies until nothing new turns up.
changed=1
while [ $changed = 1 ]; do
  changed=0
  for f in *; do
    [ -f "$f" ] || continue
    file "$f" | grep -q Mach-O || continue
    for d in $(deps "$f"); do
      b=$(basename "$d")
      if [ ! -f "$b" ]; then
        src=$(resolve "$d" "$f") || true
        [ -n "$src" ] || { echo "bundle_deps: cannot find $d (needed by $f)"; exit 1; }
        cp -L "$src" "$b"
        dirname "$(cd "$(dirname "$src")" && pwd -P)/$(basename "$src")" > ".src/$b"
        chmod u+w "$b"
        echo "bundled $b  <- $src"
        changed=1
      fi
    done
  done
done

# Rewrite install names: everything looks next to the executable.
for f in *; do
  [ -f "$f" ] || continue
  file "$f" | grep -q Mach-O || continue
  case "$f" in *.dylib) install_name_tool -id "@executable_path/$f" "$f" 2>/dev/null;; esac
  for d in $(deps "$f"); do
    install_name_tool -change "$d" "@executable_path/$(basename "$d")" "$f" 2>/dev/null
  done
done

# install_name_tool invalidates signatures: ad-hoc sign again.
for f in *; do
  [ -f "$f" ] || continue
  file "$f" | grep -q Mach-O || continue
  codesign --force --sign - "$f" 2>/dev/null
done

rm -rf .src
echo "== bundled:"
for f in *; do
  file "$f" | grep -q Mach-O || continue
  echo "-- $f"; otool -L "$f" | tail -n +2 | grep -v "^\s*/usr/lib\|^\s*/System" || true
done
