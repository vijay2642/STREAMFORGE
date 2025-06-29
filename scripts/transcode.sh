#!/bin/bash

# Compatibility wrapper: delegate to the updated transcode-fixed.sh
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/transcode-fixed.sh" "$@" 