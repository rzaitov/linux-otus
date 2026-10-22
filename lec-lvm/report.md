# Работа с LVM

После выбора LVM при установке Ubuntu26.04, проверяем что мы получили:
```bash
$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0                        11:0    1 1024M  1 rom
vda                       253:0    0   25G  0 disk
├─vda1                    253:1    0    1M  0 part
├─vda2                    253:2    0    2G  0 part /boot
└─vda3                    253:3    0   23G  0 part
  └─ubuntu--vg-ubuntu--lv 252:0    0 11.5G  0 lvm  /

fdisk -l /dev/vda
Disk /dev/vda: 25 GiB, 26843545600 bytes, 52428800 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: F772BB35-B707-40F3-B565-E6F9426249F9

Device       Start      End  Sectors Size Type
/dev/vda1     2048     4095     2048   1M BIOS boot
/dev/vda2     4096  4198399  4194304   2G Linux filesystem
/dev/vda3  4198400 52426751 48228352  23G Linux filesystem

$ pvdisplay
  --- Physical volume ---
  PV Name               /dev/vda3
  VG Name               ubuntu-vg
  PV Size               <23.00 GiB / not usable 0
  Allocatable           yes
  PE Size               4.00 MiB
  Total PE              5887
  Free PE               2944
  Allocated PE          2943
  PV UUID               DxcieM-WaZx-crvk-SLOg-bTV3-mjuY-cavcrn

$ lvdisplay
  --- Logical volume ---
  LV Path                /dev/ubuntu-vg/ubuntu-lv
  LV Name                ubuntu-lv
  VG Name                ubuntu-vg
  LV UUID                ROKkUp-uCbh-p7pC-1jx7-KqIu-zk1d-z2y8MQ
  LV Write Access        read/write
  LV Creation host, time ubuntu-server, 2026-10-20 13:15:49 +0000
  LV Status              available
  # open                 1
  LV Size                <11.50 GiB
  Current LE             2943
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     16384
  Block device           252:0
```

Видим, что диск в виртуальной машины ~23GiB, что установщик алоцировал ~11.5GiB
под логический раздел ubuntu-lv.

Мне не очень нравится идея копировать корневую файловую систему на работающей системе, как это сделано в методичке, поэтому буду делать это из другой ОС (LiveOS) к которой я подключу этот диск как `/dev/vdx`.

На своей хостовой машине найду нужный диск:
```bash
$ virsh domblklist ubuntu-lvm --inactive --details
 Type   Device   Target   Source
-------------------------------------------------------------------------------------
 file   disk     vda      /home/rzaitov/.local/share/libvirt/images/ubuntu-lvm.init
```

Запустим LiveOS к которой подключим этот диск a также еще один диск который на
который мы временно скопируем данные:
```bash
$ virsh start ubuntu26.04
    
$ virsh attach-disk ubuntu26.04 /home/rzaitov/.local/share/libvirt/images/ubuntu-lvm.init vdx \
      --targetbus virtio \
      --driver qemu \
      --subdriver qcow2 \
      --live

$ qemu-img create -f qcow2 "/home/rzaitov/.local/share/libvirt/images/vdt.qcow2" 15G
Formatting '/home/rzaitov/.local/share/libvirt/images/vdt.qcow2', fmt=qcow2 cluster_size=65536 extended_l2=off compression_type=zlib size=16106127360 lazy_refcounts=off refcount_bits=16

$ virsh attach-disk ubuntu26.04 /home/rzaitov/.local/share/libvirt/images/vdt.qcow2 vdt \
      --targetbus virtio \
      --driver qemu \
      --subdriver qcow2 \
      --live
```

Внутри LiveOS:
```bash
$ vgchange --refresh
$ lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE   MOUNTPOINTS
...
vdh                       253:112  0   15G  0 disk
vdi                       253:128  0   25G  0 disk
├─vdi1                    253:129  0    1M  0 part
├─vdi2                    253:130  0    2G  0 part
└─vdi3                    253:131  0   23G  0 part
  └─ubuntu--vg-ubuntu--lv 252:0    0 11.5G  0 lvm
```

На нашем временном диске подготовим файловую систему:
```bash
$ mkfs -t ext4 /dev/vdh
mke2fs 1.47.2 (1-Jan-2025)
Discarding device blocks: done
Creating filesystem with 3932160 4k blocks and 983040 inodes
Filesystem UUID: 387fe4c8-948c-4efb-b771-e30da5c93617
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632, 2654208

Allocating group tables: done
Writing inode tables: done
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done
```

Создадим точки монтирования для бекапа данных:
```bash
$ mkdir -p /mnt/src /mnt/bak
$ mount -o ro /dev/ubuntu-vg/ubuntu-lv /mnt/src/
$ mount /dev/vdh /mnt/bak
$ ll /mnt/src/
total 92
drwxr-xr-x  20 root root  4096 Oct 20 13:15 ./
drwxr-xr-x  10 root root  4096 Oct 22 12:28 ../
lrwxrwxrwx   1 root root     7 Apr 20  2026 bin@ -> usr/bin
drwxr-xr-x   2 root root  4096 Oct 20 13:15 boot/
dr-xr-xr-x   2 root root  4096 Apr 20  2026 cdrom/
drwxr-xr-x   5 root root  4096 Apr 20  2026 dev/
drwxr-xr-x 110 root root  4096 Oct 20 13:23 etc/
drwxr-xr-x   3 root root  4096 Oct 20 13:18 home/
lrwxrwxrwx   1 root root     7 Apr 20  2026 lib@ -> usr/lib
lrwxrwxrwx   1 root root     9 Apr 20  2026 lib64@ -> usr/lib64
drwx------   2 root root 16384 Oct 20 13:15 lost+found/
drwxr-xr-x   2 root root  4096 Apr 20  2026 media/
drwxr-xr-x   2 root root  4096 Apr 20  2026 mnt/
drwxr-xr-x   2 root root  4096 Apr 20  2026 opt/
drwxr-xr-x   2 root root  4096 Apr 20  2026 proc/
drwx------   3 root root  4096 Oct 21 19:54 root/
drwxr-xr-x  18 root root  4096 Apr 20  2026 run/
lrwxrwxrwx   1 root root     8 Apr 20  2026 sbin@ -> usr/sbin
drwxr-xr-x   2 root root  4096 Oct 20 13:23 snap/
drwxr-xr-x   2 root root  4096 Apr 20  2026 srv/
drwxr-xr-x   2 root root  4096 Apr 20  2026 sys/
drwxrwxrwt   3 root root  4096 Oct 20 13:22 tmp/
drwxr-xr-x  12 root root  4096 Apr 20  2026 usr/
drwxr-xr-x  13 root root  4096 Oct 20 13:23 var/
```

Далее копируем данные. `-x` очень важный флаг, т.к. он предотвращает выход за
пределы файловой системы. Это означает, что если какая-то директория внутри `/`
была дополнительно подмонтирована, то эти точки монтирования не будут
копироваться. На работающей системе (как в методичке) это позволяло например не
копировать virtual file system, т.е. папки `/var`, `/dev`, `/proc` и `/run`
```bash
$ rsync -axHAX --numeric-ids --info=progress2 /mnt/src/ /mnt/bak/
```

Уменьшаем logical volume:
```bash
$ umount /mnt/src/

$ lvremove /dev/ubuntu-vg/ubuntu-lv
Do you really want to remove and DISCARD active logical volume ubuntu-vg/ubuntu-lv? [y/n]: y
  Logical volume "ubuntu-lv" successfully removed.

$ lvcreate -L 8GiB -n ubuntu-lv ubuntu-vg
WARNING: ext4 signature detected on /dev/ubuntu-vg/ubuntu-lv at offset 1080. Wipe it? [y/n]: y
  Wiping ext4 signature on /dev/ubuntu-vg/ubuntu-lv.
  Logical volume "ubuntu-lv" created.
```

Создадим заново файловую систему и скопируем обратно данные:
```bash
$ mkfs -t ext4 /dev/ubuntu-vg/ubuntu-lv
mke2fs 1.47.2 (1-Jan-2025)
Discarding device blocks: done
Creating filesystem with 2097152 4k blocks and 524288 inodes
Filesystem UUID: fcc1b47c-ab53-4a82-ad61-6d9026a2f6c3
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632

Allocating group tables: done
Writing inode tables: done
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done 

$ mount /dev/ubuntu-vg/ubuntu-lv /mnt/src/

# копируем обратно из бекапа
$ rsync -axHAX --numeric-ids --info=progress2 /mnt/bak/ /mnt/src/
  3,136,117,362  70%  149.89MB/s    0:00:19 (xfr#123557, to-chk=0/150849)
```

Нужно пофиксить fstab, указав новый идентификатор ubuntu-lv:
```bash
$ blkid /dev/ubuntu-vg/ubuntu-lv
/dev/ubuntu-vg/ubuntu-lv: UUID="fcc1b47c-ab53-4a82-ad61-6d9026a2f6c3" BLOCK_SIZE="4096" TYPE="ext4"

$ cat /mnt/src/etc/fstab
...
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# / was on /dev/ubuntu-vg/ubuntu-lv during curtin installation
/dev/disk/by-id/dm-uuid-LVM-WAw6P9iaZ12ejOBRJCVTIffXPqkANxpIROKkUpuCbhp7pC1jx7KqIuzk1dz2y8MQ / ext4 defaults 0 1
# /boot was on /dev/vda2 during curtin installation
/dev/disk/by-uuid/9a3f9d72-5f78-4eea-87cc-dfdf10b1b199 /boot ext4 defaults 0 1

$ vim /mnt/src/etc/fstab
# replace /dev/disk/by-id/dm-uuid-LVM-WAw6P9iaZ12ejOBRJCVTIffXPqkANxpIROKkUpuCbhp7pC1jx7KqIuzk1dz2y8MQ
# with UUID=fcc1b47c-ab53-4a82-ad61-6d9026a2f6c3

$ findmnt --verify --tab-file /mnt/src/etc/fstab
Success, no errors or warnings detected
```

Нужно еще исправить `/boot`. Я не полностью понимаю, что тут происходит, просто
повторяю из методички. На лекции нам ничего про `chroot`, `grub-mkconfig` и
`update-initramfs` не говорили.

Важное отличие от методички: нужно отдельно смонтировать `/boot` с диска
исходной системы. В методичке делается следующее:
```bash
[root@lvm ~]# for i in /proc/ /sys/ /dev/ /run/ /boot/; \
 do mount --bind $i /mnt/$i; done
```
Нужно исключить `/boot`, т.к. иначе будет использован `/boot` LiveOS. А это не
то, что нам нужно.

Монтируем нужный нам `/boot`:
```bash
$ mount /dev/disk/by-uuid/9a3f9d72-5f78-4eea-87cc-dfdf10b1b199 /mnt/src/boot
```

Монтируем VFS из LiveOS:
```bash
$ mount --rbind /dev /mnt/src/dev
$ mount --make-rslave /mnt/src/dev

$ mount --rbind /proc /mnt/src/proc
$ mount --make-rslave /mnt/src/proc

$ mount --rbind /sys /mnt/src/sys
$ mount --make-rslave /mnt/src/sys

$ mount --rbind /run /mnt/src/run
$ mount --make-rslave /mnt/src/run

$ chroot /mnt/src /bin/bash
/# update-initramfs -u -k all
update-initramfs: Generating /boot/initrd.img-7.0.0-38-generic
update-initramfs: Generating /boot/initrd.img-7.0.0-14-generic

/# update-grub
Sourcing file `/etc/default/grub'
Sourcing file `/etc/default/grub.d/kdump-tools.cfg'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-7.0.0-38-generic
Found initrd image: /boot/initrd.img-7.0.0-38-generic
Found linux image: /boot/vmlinuz-7.0.0-14-generic
Found initrd image: /boot/initrd.img-7.0.0-14-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done

/# exit
```

Отмонтируем VFS и все что мы монтировали ранее:
```bash
$ umount -R /mnt/src/run
$ umount -R /mnt/src/sys
$ umount -R /mnt/src/proc
$ umount -R /mnt/src/dev

$ umount /mnt/src/boot
$ umount /mnt/src
$ umount /mnt/bak

# деактивируем logical volume
$ vgchange -an ubuntu-vg
```

Выключаем LiveOS:
```bash
$ systemctl poweroff
```

Запускаем виртуальную машину `ubuntu-lvm`, проверяем что размер logical volume
уменьшен до 8G:
```
$ lsblk
NAME                      MAJ:MIN RM SIZE RO TYPE MOUNTPOINTS
vda                       253:0    0  25G  0 disk
├─vda1                    253:1    0   1M  0 part
├─vda2                    253:2    0   2G  0 part /boot
└─vda3                    253:3    0  23G  0 part
  └─ubuntu--vg-ubuntu--lv 252:0    0   8G  0 lvm  /

$ lvdisplay
  --- Logical volume ---
  LV Path                /dev/ubuntu-vg/ubuntu-lv
  LV Name                ubuntu-lv
  VG Name                ubuntu-vg
  LV UUID                AS05GH-9EpY-e9eH-eJ41-FMMe-RCdS-qSfbNh
  LV Write Access        read/write
  LV Creation host, time otus-session, 2026-10-22 13:11:12 +0000
  LV Status              available
  # open                 1
  LV Size                8.00 GiB
  Current LE             2048
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     16384
  Block device           252:0
```

Ну, вроде все ОК!

## зеркало для /var

Как и в предыдущем задании, будем делать из LiveOS. Загружаемся в LiveOS и
подключаем диск с системой как делали в предыдущем задании. Внутри LiveOS:
```bash
lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
...
vdc                       253:32   0    1G  0 disk
vdd                       253:48   0    1G  0 disk
vde                       253:64   0    1G  0 disk
vdf                       253:80   0    1G  0 disk
vdg                       253:96   0    1G  0 disk
vdi                       253:128  0   25G  0 disk
├─vdi1                    253:129  0    1M  0 part
├─vdi2                    253:130  0    2G  0 part
└─vdi3                    253:131  0   23G  0 part
  └─ubuntu--vg-ubuntu--lv 252:0    0    8G  0 lvm
```

Примонтируем ubuntu-lv:
```bash
$ mount /dev/ubuntu-vg/ubuntu-lv /mnt/src/

$ df -h
Filesystem                         Size  Used Avail Use% Mounted on
...
/dev/vda2                           25G  7.0G   17G  31% /
/dev/mapper/ubuntu--vg-ubuntu--lv  7.8G  2.9G  4.5G  40% /mnt/src
```

Добавим диски из которых соберем зеркало:
```bash
$ pvcreate /dev/vdc
Physical volume "/dev/vdc" successfully created.

$ pvcreate /dev/vdd
Physical volume "/dev/vdd" successfully created.

$ vgextend ubuntu-vg /dev/vdc /dev/vdd
Volume group "ubuntu-vg" successfully extended
```

Создадим логический раздел и файловую систему:
```bash
$ lvcreate -L 500MiB -m1 --name lv-var ubuntu-vg /dev/vdc /dev/vdd
  Logical volume "lv-var" created.

$ mkfs -t ext4 /dev/ubuntu-vg/lv-var
mke2fs 1.47.2 (1-Jan-2025)
Discarding device blocks: done
Creating filesystem with 128000 4k blocks and 128000 inodes
Filesystem UUID: e2f4baca-d843-43b1-913d-fa54229c1e50
Superblock backups stored on blocks:
        32768, 98304

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done
```

Монтируем файловую систему и копируем данные папку /var:
```bash
$ mkdir /mnt/var
$ mount /dev/ubuntu-vg/lv-var /mnt/var

$ rsync -axHAX --numeric-ids --info=progress2 /mnt/src/var/ /mnt/var/
    385,025,817  99%  136.70MB/s    0:00:02 (xfr#3855, to-chk=0/4235)

$ rm -rf /mnt/src/var
```

Обновляем fstab:
```bash
$ blkid /dev/ubuntu-vg/lv-var
/dev/ubuntu-vg/lv-var: UUID="e2f4baca-d843-43b1-913d-fa54229c1e50" BLOCK_SIZE="4096" TYPE="ext4"

$ vim /mnt/src/etc/fstab
# add following:
# UUID=e2f4baca-d843-43b1-913d-fa54229c1e50 /var ext4 defaults 0 2

$ findmnt --verify --tab-file /mnt/src/etc/fstab
Success, no errors or warnings detected
```

Выключаем LiveOS и грузимся в ubuntu-lvm, чтобы проверить что все
работает(нужные диски нужно не забыть переподключить к ubuntu-lvm):
```bash
$ lsblk
NAME                          MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
vda                           253:0    0   25G  0 disk
├─vda1                        253:1    0    1M  0 part
├─vda2                        253:2    0    2G  0 part /boot
└─vda3                        253:3    0   23G  0 part
  └─ubuntu--vg-ubuntu--lv     252:0    0    8G  0 lvm  /
vdb                           253:16   0    1G  0 disk
├─ubuntu--vg-lv--var_rmeta_0  252:1    0    4M  0 lvm
│ └─ubuntu--vg-lv--var        252:5    0  500M  0 lvm  /var
└─ubuntu--vg-lv--var_rimage_0 252:2    0  500M  0 lvm
  └─ubuntu--vg-lv--var        252:5    0  500M  0 lvm  /var
vdc                           253:32   0    1G  0 disk
├─ubuntu--vg-lv--var_rmeta_1  252:3    0    4M  0 lvm
│ └─ubuntu--vg-lv--var        252:5    0  500M  0 lvm  /var
└─ubuntu--vg-lv--var_rimage_1 252:4    0  500M  0 lvm
  └─ubuntu--vg-lv--var        252:5    0  500M  0 lvm  /var
```

## logical volume для /home

Здесь уже не будем использовать LiveOS и все сделаем в работающей системе.
```bash
$ lvcreate -L 1GiB --name lv-home ubuntu-vg
  Logical volume "lv-home" created.

$ mkfs -t ext4 /dev/ubuntu-vg/lv-home
mke2fs 1.47.2 (1-Jan-2025)
Discarding device blocks: done
Creating filesystem with 262144 4k blocks and 65536 inodes
Filesystem UUID: b0670b9f-e126-49ee-ad37-5a9953caf08f
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376

Allocating group tables: done
Writing inode tables: done
Creating journal (8192 blocks): done
Writing superblocks and filesystem accounting information: done

$ mkdir /mnt/home
$ mount /dev/ubuntu-vg/lv-home /mnt/home
$ rsync -axHAX --numeric-ids --info=progress2 /home/ /mnt/home/
          4,997 100%    4.66MB/s    0:00:00 (xfr#6, to-chk=0/10)
$ mount /dev/ubuntu-vg/lv-home /home
$ ll /home
total 28
drwxr-xr-x  4 root    root     4096 Oct 20 13:18 ./
drwxr-xr-x 20 root    root     4096 Oct 22 16:45 ../
drwx------  2 root    root    16384 Oct 22 17:03 lost+found/
drwxr-x---  4 rzaitov rzaitov  4096 Oct 20 13:35 rzaitov/
```

Не забываем обновить fstab:
```bash
$ blkid /dev/ubuntu-vg/lv-home
/dev/ubuntu-vg/lv-home: UUID="b0670b9f-e126-49ee-ad37-5a9953caf08f" BLOCK_SIZE="4096" TYPE="ext4"

$ vim /etc/fstab
# add following:
# UUID=b0670b9f-e126-49ee-ad37-5a9953caf08f /home ext4 defaults 0 2

# Проверяем
$ findmnt --verify --tab-file /etc/fstab
   [W] your fstab has been modified, but systemd still uses the old version;
       use 'systemctl daemon-reload' to reload

0 parse errors, 0 errors, 1 warning

# Ага, делаем как сказано в сообщении
$ systemctl daemon-reload
$ findmnt --verify --tab-file /etc/fstab
Success, no errors or warnings detected
```

Перезагружаемся, чтобы убедиться что все в порядке:
```bash
$ systemctl reboot
```

После перезагрузки создаем снэпшот:
```bash
$ lvcreate -L 500MiB -s --name home-snapshot /dev/ubuntu-vg/lv-home
  Logical volume "home-snapshot" created.
```

Будем удалять папку `/home/rzaitov/.ssh`:
```bash
$ ll /home/rzaitov/.ssh/
total 12
drwx------ 2 rzaitov rzaitov 4096 Oct 20 13:23 ./
drwxr-x--- 4 rzaitov rzaitov 4096 Oct 20 13:35 ../
-rw------- 1 rzaitov rzaitov   92 Oct 20 13:37 authorized_keys

$ sha256sum /home/rzaitov/.ssh/authorized_keys
b0fd4edbd79a255a29624dc3122ded1f206ea06348eff4e6abdab340a5d8b7c1  /home/rzaitov/.ssh/authorized_keys

$ rm -rf /home/rzaitov/.ssh
$ ll /home/rzaitov/.ssh/
ls: cannot access '/home/rzaitov/.ssh/': No such file or directory
```

Восстановим снэпшот:
```bash
$ lvconvert --merge /dev/ubuntu-vg/home-snapshot
  Delaying merge since origin is open.
  Merging of snapshot ubuntu-vg/home-snapshot will occur on next activation of ubuntu-vg/lv-home.
```
Ой, что-то пошло не так как в методичке. Нужно реактивировать logical volume.

```bash
$ umount /home/
$ lvchange -an ubuntu-vg/lv-home
$ lvchange -ay ubuntu-vg/lv-home
$ mount /home

$ ll /home/rzaitov/.ssh
total 12
drwx------ 2 rzaitov rzaitov 4096 Oct 20 13:23 ./
drwxr-x--- 4 rzaitov rzaitov 4096 Oct 20 13:35 ../
-rw------- 1 rzaitov rzaitov   92 Oct 20 13:37 authorized_keys

$ sha256sum /home/rzaitov/.ssh/authorized_keys
b0fd4edbd79a255a29624dc3122ded1f206ea06348eff4e6abdab340a5d8b7c1  /home/rzaitov/.ssh/authorized_keys
```
