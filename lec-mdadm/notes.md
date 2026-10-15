# Работа с разделами и raid массивом

## Востановление raid10 массива

Ломаем raid массив:
```bash
$ mdadm /dev/md10 --fail /dev/vdb
$ mdadm -D /dev/md10
/dev/md10:
           Version : 1.2
     Creation Time : Thu Oct 15 11:36:37 2026
        Raid Level : raid10
        Array Size : 2093056 (2044.00 MiB 2143.29 MB)
     Used Dev Size : 1046528 (1022.00 MiB 1071.64 MB)
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent

     Intent Bitmap : Internal

       Update Time : Thu Oct 15 11:37:33 2026
             State : clean, degraded
    Active Devices : 3
   Working Devices : 3
    Failed Devices : 1
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : bitmap

              Name : otus-session:10  (local to host otus-session)
              UUID : 9f8d0442:eee5ae05:02530b2b:ee60b9c9
            Events : 30

    Number   Major   Minor   RaidDevice State
       -       0        0        0      removed
       1     253       32        1      active sync set-B   /dev/vdc
       2     253       48        2      active sync set-A   /dev/vdd
       3     253       64        3      active sync set-B   /dev/vde

       0     253       16        -      faulty   /dev/vdb
```

Удаляем "сбойный" диск из массива:
```bash
$ mdadm /dev/md10 --remove /dev/vdb
mdadm: hot removed /dev/vdb from /dev/md10

$ mdadm -D /dev/md10
/dev/md10:
...
      Raid Devices : 4
     Total Devices : 3
...
             State : clean, degraded
    Active Devices : 3
   Working Devices : 3
    Failed Devices : 0
     Spare Devices : 0
...

    Number   Major   Minor   RaidDevice State
       -       0        0        0      removed
       1     253       32        1      active sync set-B   /dev/vdc
       2     253       48        2      active sync set-A   /dev/vdd
       3     253       64        3      active sync set-B   /dev/vde
```

Готовим новый диск к добавлению в raid массив:
```bash
$ mdadm --zero-superblock /dev/vdf

```

Добавляем подготовленный диск в raid массив:
```bash
$ mdadm /dev/md10 --add /dev/vdf
mdadm: added /dev/vdf

$ mdadm -D /dev/md10
/dev/md10:
...
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent
...
    Active Devices : 3
   Working Devices : 4
    Failed Devices : 0
     Spare Devices : 1
...
    Rebuild Status : 40% complete

              Name : otus-session:10  (local to host otus-session)
              UUID : 9f8d0442:eee5ae05:02530b2b:ee60b9c9
            Events : 61

    Number   Major   Minor   RaidDevice State
       4     253       80        0      spare rebuilding   /dev/vdf
       1     253       32        1      active sync set-B   /dev/vdc
       2     253       48        2      active sync set-A   /dev/vdd
       3     253       64        3      active sync set-B   /dev/vde
```

Проверяем через пару секунд состояние массива:
```bash
$ mdadm -D /dev/md10
/dev/md10:
...
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent
...
             State : clean
    Active Devices : 4
   Working Devices : 4
    Failed Devices : 0
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : bitmap

              Name : otus-session:10  (local to host otus-session)
              UUID : 9f8d0442:eee5ae05:02530b2b:ee60b9c9
            Events : 72

    Number   Major   Minor   RaidDevice State
       4     253       80        0      active sync set-A   /dev/vdf
       1     253       32        1      active sync set-B   /dev/vdc
       2     253       48        2      active sync set-A   /dev/vdd
       3     253       64        3      active sync set-B   /dev/vde
```

## Создание 5 gpt разделов на диске

Подготавливаем диск для работы
```bash
$ sgdisk --zap-all /dev/vdb
Creating new GPT entries in memory.
GPT data structures destroyed! You may now partition the disk using fdisk or
other utilities.
```

gpt разметку будем создавать с помощью gdisk:
```bash
$ gdisk /dev/vdb

GPT fdisk (gdisk) version 1.0.10

Partition table scan:
  MBR: not present
  BSD: not present
  APM: not present
  GPT: not present

Creating new GPT entries in memory.

Command (? for help): p
Disk /dev/vdb: 2097152 sectors, 1024.0 MiB
Sector size (logical/physical): 512/512 bytes
Disk identifier (GUID): D7A93183-024F-4A0D-B839-70C70721B900
Partition table holds up to 128 entries
Main partition table begins at sector 2 and ends at sector 33
First usable sector is 34, last usable sector is 2097118
Partitions will be aligned on 2048-sector boundaries
Total free space is 2097085 sectors (1024.0 MiB)

Number  Start (sector)    End (sector)  Size       Code  Name

Command (? for help): n
Partition number (1-128, default 1):
First sector (34-2097118, default = 2048) or {+-}size{KMGTP}:
Last sector (2048-2097118, default = 2095103) or {+-}size{KMGTP}: +100MiB
Current type is 8300 (Linux filesystem)
Hex code or GUID (L to show codes, Enter = 8300):
Changed type of partition to 'Linux filesystem'

Command (? for help): n
Partition number (2-128, default 2):
First sector (34-2097118, default = 206848) or {+-}size{KMGTP}:
Last sector (206848-2097118, default = 2095103) or {+-}size{KMGTP}: +100MiB
Current type is 8300 (Linux filesystem)
Hex code or GUID (L to show codes, Enter = 8300):
Changed type of partition to 'Linux filesystem'

Command (? for help): n
Partition number (3-128, default 3):
First sector (34-2097118, default = 411648) or {+-}size{KMGTP}:
Last sector (411648-2097118, default = 2095103) or {+-}size{KMGTP}: +100MiB
Current type is 8300 (Linux filesystem)
Hex code or GUID (L to show codes, Enter = 8300):
Changed type of partition to 'Linux filesystem'

Command (? for help): n
Partition number (4-128, default 4):
First sector (34-2097118, default = 616448) or {+-}size{KMGTP}:
Last sector (616448-2097118, default = 2095103) or {+-}size{KMGTP}: +100MiB
Current type is 8300 (Linux filesystem)
Hex code or GUID (L to show codes, Enter = 8300):
Changed type of partition to 'Linux filesystem'

Command (? for help): n
Partition number (5-128, default 5):
First sector (34-2097118, default = 821248) or {+-}size{KMGTP}:
Last sector (821248-2097118, default = 2095103) or {+-}size{KMGTP}: 100%
Last sector (821248-2097118, default = 2095103) or {+-}size{KMGTP}:
Current type is 8300 (Linux filesystem)
Hex code or GUID (L to show codes, Enter = 8300):
Changed type of partition to 'Linux filesystem'

Command (? for help): p
Disk /dev/vdb: 2097152 sectors, 1024.0 MiB
Sector size (logical/physical): 512/512 bytes
Disk identifier (GUID): D7A93183-024F-4A0D-B839-70C70721B900
Partition table holds up to 128 entries
Main partition table begins at sector 2 and ends at sector 33
First usable sector is 34, last usable sector is 2097118
Partitions will be aligned on 2048-sector boundaries
Total free space is 4029 sectors (2.0 MiB)

Number  Start (sector)    End (sector)  Size       Code  Name
   1            2048          206847   100.0 MiB   8300  Linux filesystem
   2          206848          411647   100.0 MiB   8300  Linux filesystem
   3          411648          616447   100.0 MiB   8300  Linux filesystem
   4          616448          821247   100.0 MiB   8300  Linux filesystem
   5          821248         2095103   622.0 MiB   8300  Linux filesystem

Command (? for help): w

Final checks complete. About to write GPT data. THIS WILL OVERWRITE EXISTING
PARTITIONS!!

Do you want to proceed? (Y/N): y
OK; writing new GUID partition table (GPT) to /dev/vdb.
The operation has completed successfully.
```

Убедимся что разделы созданы:
```
$ lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE   MOUNTPOINTS
sr0     11:0    1 1024M  1 rom
vda    253:0    0   25G  0 disk
├─vda1 253:1    0    1M  0 part
└─vda2 253:2    0   25G  0 part   /
vdb    253:16   0    1G  0 disk
├─vdb1 253:17   0  100M  0 part
├─vdb2 253:18   0  100M  0 part
├─vdb3 253:19   0  100M  0 part
├─vdb4 253:20   0  100M  0 part
└─vdb5 253:21   0  622M  0 part
...
```

Создадим файловую систему на каждом из разделов
```bash
$ for i in {1..5}; do
	mkfs -t ext4 "/dev/vdb$i"
done

$ lsblk -o +FSTYPE

NAME   MAJ:MIN RM  SIZE RO TYPE   MOUNTPOINTS FSTYPE
sr0     11:0    1 1024M  1 rom
vda    253:0    0   25G  0 disk
├─vda1 253:1    0    1M  0 part
└─vda2 253:2    0   25G  0 part   /           ext4
vdb    253:16   0    1G  0 disk
├─vdb1 253:17   0  100M  0 part               ext4
├─vdb2 253:18   0  100M  0 part               ext4
├─vdb3 253:19   0  100M  0 part               ext4
├─vdb4 253:20   0  100M  0 part               ext4
└─vdb5 253:21   0  622M  0 part               ext4
```

Смонтируем все разделы:
```bash
$ for i in {1..5}; do
    mkdir -p "/mnt/$i"
    mount "/dev/vdb$i" "/mnt/$i"
done

$ lsblk -o +FSTYPE

NAME   MAJ:MIN RM  SIZE RO TYPE   MOUNTPOINTS FSTYPE
sr0     11:0    1 1024M  1 rom
vda    253:0    0   25G  0 disk
├─vda1 253:1    0    1M  0 part
└─vda2 253:2    0   25G  0 part   /           ext4
vdb    253:16   0    1G  0 disk
├─vdb1 253:17   0  100M  0 part   /mnt/1      ext4
├─vdb2 253:18   0  100M  0 part   /mnt/2      ext4
├─vdb3 253:19   0  100M  0 part   /mnt/3      ext4
├─vdb4 253:20   0  100M  0 part   /mnt/4      ext4
└─vdb5 253:21   0  622M  0 part   /mnt/5      ext4
```
