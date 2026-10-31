#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TOOLCHAIN="$(dirname "$(dirname "$(xcrun --find swiftc)")")"
PLUGIN="$TOOLCHAIN/lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [[ -f "$PLUGIN" ]]; then
    swift test -Xswiftc -load-plugin-library -Xswiftc "$PLUGIN" "$@"
else
    swift test "$@"
fi
