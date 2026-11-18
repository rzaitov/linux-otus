#!/bin/bash

set -euo pipefail

printf 'SOCKET=<%s>\n' "$SOCKET"
printf 'OPTIONS=<%s>\n' "$OPTIONS"
printf 'arguments=<%s>\n' "$@"
