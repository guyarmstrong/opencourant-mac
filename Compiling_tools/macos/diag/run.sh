#!/bin/bash
# Diagnostic only: full runs side by side from one starter's output, each keeping
# its last frame, to see how much repeat runs and settings change the result.
# usage: run.sh name:threads[:ftz] ...
set -uo pipefail
W=$GITHUB_WORKSPACE
X=$W/pkg/exec
export RAD_CFG_PATH=$W/pkg/hm_cfg_files KMP_STACKSIZE=400m
mkdir -p s results
cp Compiling_tools/macos/test/model.k s/
( cd s; "$X/starter_macosa64_gf_sp" -i model.k -np 1 </dev/null >stdout.txt 2>&1 )
one() {
  local name=$1 nt=$2 ftz=${3:-}; local d=r_$name t0=$(date +%s); mkdir "$d"; cp s/model_000*.r* "$d/"
  ( cd "$d"; if [ -n "$ftz" ]; then export DYLD_INSERT_LIBRARIES=$W/ftz.dylib; fi
    "$X/engine_macosa64_gf_sp" -i model_0001.rad -nt "$nt" </dev/null >stdout.txt 2>stderr.txt )
  echo "$name: nt=$nt ftz=${ftz:-no} $(( $(date +%s)-t0 )) s; $(grep -c 'NORMAL TERMINATION' "$d/model_0001.out") normal; $(cat "$d/stderr.txt" | tr '\n' ' ')"
  cp "$d/model_0001.out" "results/$name.out"
  cp "$(ls "$d"/modelA0* | sort | tail -1)" "results/$name.lastframe"
}
if [ "$PARALLEL" = 1 ]; then for r in "$@"; do IFS=: read -r a b c <<<"$r"; one "$a" "$b" "$c" & done; wait
else for r in "$@"; do IFS=: read -r a b c <<<"$r"; one "$a" "$b" "$c"; done; fi
exit 0
