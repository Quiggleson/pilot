#!/usr/bin/env bash
# Checks that /pilot is served by this Worker and that the portfolio still owns everything else.
#   scripts/smoke.sh                        both production hostnames
#   scripts/smoke.sh http://localhost:8787  a local `wrangler dev`; portfolio checks are skipped
set -uo pipefail

APP=pilot

origins=("$@")
if [ ${#origins[@]} -eq 0 ]; then
  origins=(https://quiggleson.com https://www.quiggleson.com)
fi

failures=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; failures=$((failures + 1)); }

headers() { curl -sS -o /dev/null -D - --max-time 15 "$1" | tr -d '\r'; }
status() { printf '%s\n' "$1" | head -1 | awk '{print $2}'; }
header() { printf '%s\n' "$1" | grep -i "^$2:" | head -1 | cut -d' ' -f2-; }

for origin in "${origins[@]}"; do
  echo "$origin"

  h=$(headers "$origin/$APP")
  code=$(status "$h")
  loc=$(header "$h" location)
  if [[ $code == 30[1278] && $loc == */$APP/ ]]; then
    pass "/$APP redirects to /$APP/"
  else
    fail "/$APP -> $code ${loc:-(no location)}"
  fi

  h=$(headers "$origin/$APP/")
  code=$(status "$h")
  type=$(header "$h" content-type)
  opennext=$(header "$h" x-opennext)
  if [[ $code == 200 && $type == text/html* && -z $opennext ]]; then
    pass "/$APP/ is the app, not the portfolio"
  else
    fail "/$APP/ -> $code, ${type:-(no type)}, x-opennext=${opennext:-(none)}"
  fi

  manifest=$(curl -sS --max-time 15 "$origin/$APP/manifest.webmanifest")
  if printf '%s' "$manifest" | grep -Eq "\"scope\" *: *\"/$APP/\""; then
    pass "manifest scope is /$APP/"
  else
    fail "manifest missing or scope wrong: $(printf '%s' "$manifest" | head -c 120)"
  fi

  h=$(headers "$origin/$APP/sw.js")
  code=$(status "$h")
  type=$(header "$h" content-type)
  if [[ $code == 200 && $type == *javascript* ]]; then
    pass "/$APP/sw.js is served"
  else
    fail "/$APP/sw.js -> $code, ${type:-(no type)}"
  fi

  if [[ $origin =~ ://(localhost|127\.0\.0\.1) ]]; then
    continue
  fi

  for path in / "/${APP}x"; do
    opennext=$(header "$(headers "$origin$path")" x-opennext)
    if [[ $opennext == 1 ]]; then
      pass "$path is still the portfolio"
    else
      fail "$path is not served by the portfolio (x-opennext=${opennext:-none})"
    fi
  done
done

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
