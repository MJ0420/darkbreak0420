#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
BIN="$(mktemp /tmp/gpsjoystick-test.XXXXXX)"
trap 'rm -f "$BIN"' EXIT
clang -std=c11 -Wall -Wextra -Werror -pedantic src/GPSModel.c tests/test_model.c -lm -o "$BIN"
"$BIN"
