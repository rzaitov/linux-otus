#!/bin/bash

set -euo pipefail

mnt_dst=/mnt/raid10
raid_dev=/dev/md10
raid_disks=(/dev/vdb /dev/vdc /dev/vdd /dev/vde)

function raid_stop() {
	umount "$raid_dev"
	mdadm --stop "$raid_dev"
}

function raid_create() {
	# exit early if raid device is already present
	if [[ -e $raid_dev ]]; then
		printf '%s already exists; stop it before creating a new array\n' "$raid_dev" >&2
		return 1
	fi

	# exit early if some disk is part of an existing raid array
	for disk in "${raid_disks[@]}"; do
		assert_disk_unused "$disk"
	done

	for disk in "${raid_disks[@]}"; do
		printf 'Clearing: %s\n' "$disk"
		clear_disk "$disk"
	done

	# --bitmap=internal helps to avoid interactive question on Ubuntu26.04:
	# To optimize recovery speed, it is recommended to enable write-intent bitmap, do you want to enable it now? [y/N]?
	mdadm --create "$raid_dev" \
		--bitmap=internal \
		--level=10 --raid-devices=4 \
		"${raid_disks[@]}"

	wipefs --all "$raid_dev"
	mkfs -t ext4 "$raid_dev"

	mkdir -p "$mnt_dst"
	mount "$raid_dev" "$mnt_dst"
}

function assert_disk_unused() {
	disk=$1
	disk_name=${disk##*/}
	holders="/sys/class/block/${disk_name}/holders"
	holder="$(find "$holders" -mindepth 1 -maxdepth 1 -printf '%f' -quit)"

	if [[ -n $holder ]]; then
		printf '%s is currently in use by %s\n' "$disk" "$holder" >&2
		return 1
	fi
}

function clear_disk() {
	# remove MBR header & GPT headers if any
	sgdisk --zap-all "$disk" > /dev/null
	# wipe md superblock if disk was part of raid array previously
	mdadm --zero-superblock --force "$disk" 2> /dev/null
}

function main() {
	case "${1:-create}" in
	stop) raid_stop ;;
	create) raid_create ;;
	*)
		printf 'Usage: %s {create|stop}\n' "$0" >&2
		return 1
		;;
	esac
}

main "$@"
