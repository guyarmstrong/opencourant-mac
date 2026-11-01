#!/bin/bash
# Diagnostic only: where do the Intel starter and engine spend their time?
# Uses the programs already built by the macos branch's CI; nothing recompiled.
set -uo pipefail
W=$GITHUB_WORKSPACE
X=$W/pkg/exec
export RAD_CFG_PATH=$W/pkg/hm_cfg_files KMP_STACKSIZE=400m
S=$W/results; mkdir -p "$S"
FTZ=$W/ftz.dylib

prof() { # pid seconds_from_now name
  ( sleep "$2"; kill -0 "$1" 2>/dev/null && sudo sample "$1" 10 -mayDie -file "$S/$3.txt" >/dev/null 2>&1 ) &
}

echo "== starter: plain and flush-to-zero side by side"
mkdir -p s_plain s_ftz
cp Compiling_tools/macos/test/model.k s_plain/
cp Compiling_tools/macos/test/model.k s_ftz/
t0=$(date +%s)
( cd s_ftz; DYLD_INSERT_LIBRARIES=$FTZ "$X/starter_macosa64_gf_sp" -i model.k -np 1 </dev/null >stdout.txt 2>stderr.txt; echo "starter flush-to-zero: $(( $(date +%s)-t0 )) s, exit $?"; cat stderr.txt ) &
ftzpid=$!
cd s_plain; "$X/starter_macosa64_gf_sp" -i model.k -np 1 </dev/null >stdout.txt 2>&1 &
pid=$!; cd "$W"
prof "$pid" 15 starter_t15; prof "$pid" 60 starter_t60; prof "$pid" 300 starter_t300; prof "$pid" 900 starter_t900
wait "$pid"; echo "starter plain: $(( $(date +%s)-t0 )) s"
wait "$ftzpid"
ls -la s_plain s_ftz | grep -E 'rst|rad|out' || true
grep -c . s_plain/model_0000.out s_ftz/model_0000.out
cmp s_plain/model_0000_0001.rst s_ftz/model_0000_0001.rst && echo "restart files identical"

engine() { # name threads seconds [env assignments...]
  local name=$1 nt=$2 secs=$3; shift 3
  local d=e_$name; rm -rf "$d"; mkdir "$d"; cp s_plain/model_000*.r* "$d/"
  ( cd "$d"; exec env "$@" "$X/engine_macosa64_gf_sp" -i model_0001.rad -nt "$nt" </dev/null >stdout.txt 2>&1 ) &
  local pid=$!
  prof "$pid" $((secs/2)) "engine_$name"
  sleep "$secs"
  ps -o %cpu=,rss= -p "$pid" | sed "s/^/$name cpu% rss: /"
  kill -9 "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  local c=$(grep -E '^ +[0-9]+ +[0-9.E+-]+ +[0-9.E+-]+ +[A-Z]+' "$d/model_0001.out" | tail -1 | awk '{print $1}')
  echo "engine $name: nt=$nt ${secs}s -> cycle ${c:-0} ($(( ${c:-0}/secs )) cycles/s)"
  cp "$d/model_0001.out" "$S/engine_$name.out" 2>/dev/null
}

echo "== engine, same model, ${ENGINE_SECS} s each (Apple silicon, 3 threads: 188 cycles/s over the whole run)"
engine nt1 1 "$ENGINE_SECS" A=1
engine nt2 2 "$ENGINE_SECS" A=1
engine nt3 3 "$ENGINE_SECS" A=1
engine nt4 4 "$ENGINE_SECS" A=1
engine nt3_passive 3 "$ENGINE_SECS" OMP_WAIT_POLICY=passive
engine nt3_active 3 "$ENGINE_SECS" OMP_WAIT_POLICY=active
engine nt1_ftz 1 "$ENGINE_SECS" DYLD_INSERT_LIBRARIES=$FTZ
engine nt3_ftz 3 "$ENGINE_SECS" DYLD_INSERT_LIBRARIES=$FTZ
cat e_nt3_ftz/stdout.txt | grep '\[ftz\]' | head -3

echo "== profiles"
for f in "$S"/starter_t*.txt "$S"/engine_nt3.txt "$S"/engine_nt1.txt; do
  [ -f "$f" ] || continue
  echo "---- $(basename "$f")"
  awk '/Sort by top of stack/{p=1} p' "$f" | head -22
  awk '/^Call graph/{p=1} /^Total number in stack/{p=0} p' "$f" | cut -c1-120 | head -45
done
exit 0
