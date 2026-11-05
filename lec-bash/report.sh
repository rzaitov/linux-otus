#!/bin/bash

set -euo pipefail

# https://man7.org/linux/man-pages/man1/flock.1.html
lock="/run/lock/$(basename "$0").lock"
if [[ ${FLOCKER:-} != "$lock" ]]; then
	FLOCKER="$lock" exec flock --exclusive --nonblock --conflict-exit-code 99 "$lock" "$0" "$@"
fi

function main() {
	local log_file=${1:-access.log}
	local n=${TOP:-10}

	printf "Top %d IPs:\n" "$n"
	get_ips < "$log_file" | stats | head -n "$n"
	printf "\n"

	printf "Top %d URLs:\n" "$n"
	get_urls < "$log_file" | stats | head -n "$n"
	printf "\n"

	printf "Errors stats:\n"
	get_errors < "$log_file" | stats
	printf "\n"

	printf "HTTP codes:\n"
	get_codes < "$log_file" | stats
}

function get_ips() {
	awk '{print $1}'
}

function get_urls() {
	awk -F'"' '{
		n = split($2, req_info, " ")
		if (n == 0) { print "<empty>"; next }
		if (n != 3) { print "<invalid>"; next }

		url = req_info[2]
		split(url, url_parts, /[?]/)
		print url_parts[1]
  }'
}

function get_errors() {
	awk -F'"' '{
		split($3, resp_info, " ")
		code = resp_info[1]
		if (code >= 400 && code < 500) { print "4xx" }
		if (code >= 500 && code < 600) { print "5xx" }
  }'
}

function get_codes() {
	awk -F'"' '{
		split($3, resp_info, " ")
		code = resp_info[1]
		print code
	}'
}

function stats() {
	sort |
		uniq --count |
		sort --key 1 --numeric-sort --reverse
}

main "$@"
