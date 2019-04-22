#!/bin/sh

set -e

js="build/client-unminified.js"
min="src/client/generated/client.js"

elm make --optimize --output=$js $@

npx uglifyjs $js --compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe" | npx uglifyjs --mangle --output=$min

echo "Initial size: $(cat $js | wc -c) bytes  ($js)"
echo "Minified size:$(cat $min | wc -c) bytes  ($min)"
echo "Gzipped size: $(cat $min | gzip -c | wc -c) bytes"
