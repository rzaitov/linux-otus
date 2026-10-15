#!/bin/bash

set -euo pipefail

imgs="$HOME/.local/share/libvirt/images/otus-linux"
vm=ubuntu26.04
disk_names=(vdb vdc vdd vde vdf)

function create_disk_imgs() {
	mkdir -p "$imgs"

	for dn in "${disk_names[@]}"; do
		qemu-img create -f qcow2 "${imgs}/${dn}.qcow2" 1G
	done
}

function attach_disk_imgs() {
	for dn in "${disk_names[@]}"; do
		if ! virsh domblklist "$vm" --inactive | grep -qw "$dn"; then
			virsh attach-disk "$vm" "${imgs}/${dn}.qcow2" "$dn" --subdriver qcow2 --persistent
		fi
	done
}

function main() {
	case "${1-}" in
		create)
			create_disk_imgs
			;;
		attach)
			attach_disk_imgs
			;;
		*)
			printf 'Usage: %s {create|attach}\n' "$0" >&2
			return 1
			;;
	esac
}

main "$@"
