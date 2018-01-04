#!/bin/bash
set +x
cd spec

for spec in $(find compiler std -type f -iname "*_spec.cr" | sort); do
  (cd .. && crystal-windows spec/$spec) >/dev/null 2>/dev/null && echo "require \"$spec\"" ||
    (../bin/crystal build --no-codegen --target x86_64--windows-msvc $spec >/dev/null 2>/dev/null && echo "# require \"$spec\" (failed to run)" || echo "# require \"$spec\" (failed to compile)")
done
