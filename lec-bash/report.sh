#!/bin/bash

set -euo pipefail

# https://man7.org/linux/man-pages/man1/flock.1.html
lock="/run/lock/$(basename "$0").lock"
if [[ ${FLOCKER:-} != "$lock" ]]; then
	FLOCKER="$lock" exec flock --exclusive --nonblock --conflict-exit-code 99 "$lock" "$0" "$@"
fi

src_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

function main() {
	local log_file=${1:-access.log}
	local n=${TOP:-10}

	local since=1565817878

	printf "Top %d IPs:\n" "$n"
	get_ips "$since" < "$log_file" | stats | head -n "$n"
	printf "\n"

	printf "Top %d URLs:\n" "$n"
	get_urls "$since" < "$log_file" | stats | head -n "$n"
	printf "\n"

	printf "Errors stats:\n"
	get_errors "$since" < "$log_file" | stats
	printf "\n"

	printf "HTTP codes:\n"
	get_codes "$since" < "$log_file" | stats
}

function get_ips() {
	# shellcheck disable=SC2016
	TZ=UTC awk \
		-f "$src_dir/common.awk" \
		-v timestamp="$1" \
		-f <(echo '
			after($0, timestamp) {
				print $1
			}
		')
}

function get_urls() {
	# shellcheck disable=SC2016
	TZ=UTC awk -F'"' \
		-f "$src_dir/common.awk" \
		-v timestamp="$1" \
		-f <(echo '
			after($0, timestamp) {
				n = split($2, req_info, " ")
				if (n == 0) { print "<empty>"; next }
				if (n != 3) { print "<invalid>"; next }

				url = req_info[2]
				split(url, url_parts, /[?]/)
				print url_parts[1]
			}
		')
}

function get_errors() {
	# shellcheck disable=SC2016
	TZ=UTC awk -F'"' \
		-f "$src_dir/common.awk" \
		-v timestamp="$1" \
		-f <(echo '
			after($0, timestamp) {
				split($3, resp_info, " ")
				code = resp_info[1]
				if (code >= 400 && code < 500) { print "4xx" }
				if (code >= 500 && code < 600) { print "5xx" }
			}
		')
}

function get_codes() {
	# shellcheck disable=SC2016
	TZ=UTC awk -F'"' \
		-f "$src_dir/common.awk" \
		-v timestamp="$1" \
		-f <(echo '
			after($0, timestamp) {
				split($3, resp_info, " ")
				code = resp_info[1]
				print code
			}
		')
}

function stats() {
	sort |
		uniq --count |
		sort --key 1 --numeric-sort --reverse
}

main "$@"
