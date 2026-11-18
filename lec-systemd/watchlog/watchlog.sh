#!/bin/bash

set -euo pipefail

function main() {
	local word=${1:?"keyword is a mandatory argument"}
	local log_file=${2:?"log file is a mandatory argument"}

	if grep -F -- "$word" "$log_file"; then
		printf '[%s]: keyword %s found\n' "$(date)" "$word"
	fi
}

main "$@"
