# Работа с ZFS

На хостовой машине создадим 4 диска:
```bash
vm=ubuntu26.04
imgs="$HOME/.local/share/libvirt/images/otus-linux/lec-zfs"
mkdir -p "$imgs"
disk_names=(vdb vdc vdd vde)

for dn in "${disk_names[@]}"; do
    qemu-img create -f qcow2 "${imgs}/${dn}.qcow2" 5G
done

ls -Al $imgs
total 784
-rw-r--r-- 1 rzaitov rzaitov 196688 Oct 30 16:40 vdb.qcow2
-rw-r--r-- 1 rzaitov rzaitov 196688 Oct 30 16:40 vdc.qcow2
-rw-r--r-- 1 rzaitov rzaitov 196688 Oct 30 16:40 vdd.qcow2
-rw-r--r-- 1 rzaitov rzaitov 196688 Oct 30 16:40 vde.qcow2
```

Подключим диски к виртуальной машине:
```bash
for dn in "${disk_names[@]}"; do
    virsh attach-disk "$vm" "${imgs}/${dn}.qcow2" "$dn" --subdriver qcow2
done
```

В виртуальной машине проверим, что диски подключены:
```bash
$ lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sr0     11:0    1 1024M  1 rom
vda    253:0    0   25G  0 disk
├─vda1 253:1    0    1M  0 part
└─vda2 253:2    0   25G  0 part /
vdb    253:16   0    5G  0 disk
vdc    253:32   0    5G  0 disk
vdd    253:48   0    5G  0 disk
vde    253:64   0    5G  0 disk
vdf    253:80   0    5G  0 disk
```

Установим пакет для работы с zfs:
```bash
apt install zfsutils-linux
```

Создадим пулы на каждом из дисков:
```bash
zpool create otus1 /dev/vdb
zpool create otus2 /dev/vdc
zpool create otus3 /dev/vdd
zpool create otus4 /dev/vde

zpool list
NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
otus1  4.50G   123K  4.50G        -         -     0%     0%  1.00x    ONLINE  -
otus2  4.50G   120K  4.50G        -         -     0%     0%  1.00x    ONLINE  -
otus3  4.50G   120K  4.50G        -         -     0%     0%  1.00x    ONLINE  -
otus4  4.50G   124K  4.50G        -         -     0%     0%  1.00x    ONLINE  -
```

Включим сжатие:
```bash
zfs set compression=lz4 otus1
zfs set compression=gzip-6 otus2
zfs set compression=zstd-3 otus3
zfs set compression=zstd-6 otus4
```

Проверим что настройки вступили в силу:
```bash
zfs get compression
NAME   PROPERTY     VALUE           SOURCE
otus1  compression  lz4             local
otus2  compression  gzip            local
otus3  compression  zstd-3          local
otus4  compression  zstd-6          local
```

Я пробросил в VM копию `/var/log/` с хостовой машины. Файлы доступны по пути
`/mnt/host-logs` с ними и будем работать:
```bash
$ df -h
...
host_logs       1.9T  461G  1.4T  25% /mnt/host-logs

$ du -sh /mnt/host-logs/
5.0G    /mnt/host-logs/
```

Копируем в ранее созданные zpool'ы:
```bash
rsync -avH /mnt/host-logs/ /otus1
rsync -avH /mnt/host-logs/ /otus2
rsync -avH /mnt/host-logs/ /otus3
rsync -avH /mnt/host-logs/ /otus4
```

Смотрим что лучше сжалось:
```bash
zfs get compressratio
NAME   PROPERTY       VALUE  SOURCE
otus1  compressratio  2.39x  -
otus2  compressratio  3.47x  -
otus3  compressratio  3.22x  -
otus4  compressratio  3.28x  -
```

Видно, что gzip "победил", но zstd-3 и zstd-6 очень близки.

## Определить настройки пула

скачиваем архив:
```bash
$ curl -L 'https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download' -o archive.tar.gz
  % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
                                 Dload  Upload  Total   Spent   Left   Speed
100  6.93M 100  6.93M   0      0 946.5k      0   00:07   00:07         487.8k
```

распаковываем его:
```bash
$ tar -xvf archive.tar.gz
zpoolexport/
zpoolexport/filea
zpoolexport/fileb
```

Смотрим конфигурацию пула:
```bash
$ zpool import -d zpoolexport/
  pool: otus
    id: 6554193320433390805
 state: ONLINE
status: Some supported features are not enabled on the pool.
        (Note that they may be intentionally disabled if the
        'compatibility' property is set.)
action: The pool can be imported using its name or numeric identifier, though
        some features will not be available without an explicit 'zpool upgrade'.
config:

        otus                         ONLINE
          mirror-0                   ONLINE
            /root/zpoolexport/filea  ONLINE
            /root/zpoolexport/fileb  ONLINE
```

Импортируем:
```bash
$ zpool import -d zpoolexport/ otus
$ zfs list
NAME             USED  AVAIL  REFER  MOUNTPOINT
otus            2.04M   350M    24K  /otus
otus/hometask2  1.88M   350M  1.88M  /otus/hometask2

$ zpool status
  pool: otus
 state: ONLINE
status: Some supported and requested features are not enabled on the pool.
        The pool can still be used, but some features are unavailable.
action: Enable all features using 'zpool upgrade'. Once this is done,
        the pool may no longer be accessible by software that does not support
        the features. See zpool-features(7) for details.
config:

        NAME                         STATE     READ WRITE CKSUM
        otus                         ONLINE       0     0     0
          mirror-0                   ONLINE       0     0     0
            /root/zpoolexport/filea  ONLINE       0     0     0
            /root/zpoolexport/fileb  ONLINE       0     0     0

errors: No known data errors
```

Читаем настройки пула:
```bash
$ zfs get available
NAME            PROPERTY   VALUE  SOURCE
otus            available  350M   -
otus/hometask2  available  350M   -

$ zfs get type
NAME            PROPERTY  VALUE       SOURCE
otus            type      filesystem  -
otus/hometask2  type      filesystem  -

$ zfs get recordsize
NAME            PROPERTY    VALUE    SOURCE
otus            recordsize  128K     local
otus/hometask2  recordsize  128K     inherited from otus

$ zfs get compression
NAME            PROPERTY     VALUE           SOURCE
otus            compression  zle             local
otus/hometask2  compression  zle             inherited from otus

$ zfs get checksum
NAME            PROPERTY  VALUE      SOURCE
otus            checksum  sha256     local
otus/hometask2  checksum  sha256     inherited from otus
```

## Работа со снапшотом

Скачиваем файл
```bash
$ curl -L "https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI&export=download" --output otus-task2.file
$ ll
total 12468
...
-rw-r--r--  1 root    root    7275140 Nov  1 19:33 archive.tar.gz
-rw-rw-r--  1 rzaitov rzaitov 5432736 Nov  1 22:46 otus-task2.file
drwxr-xr-x  2 root    root       4096 May 15  2020 zpoolexport/
```


Методичка, говорит использовать `zfs receive`, я не помню, чтобы эта команда
была на лекции, поэтому обратимся к man:
```bash
$ man zfs
...
zfs-receive(8)
 Creates  a  snapshot  whose contents are as specified in the stream provided on standard input.  If a full stream is received, then a new
 file system is created as well.  Streams are created using the zfs-send(8) subcommand, which by default creates a full stream.
```

После успешного выполнения команды ожидается что будет создана файловая система:
```bash
$ zfs receive otus/test@today < otus-task2.file

$ zfs list
NAME             USED  AVAIL  REFER  MOUNTPOINT
otus            4.91M   347M    24K  /otus
otus/hometask2  1.88M   347M  1.88M  /otus/hometask2
otus/test       2.85M   347M  2.83M  /otus/test

$ df -h
Filesystem      Size  Used Avail Use% Mounted on
...
otus            348M  128K  347M   1% /otus
otus/hometask2  349M  2.0M  347M   1% /otus/hometask2
tmpfs           743M  8.0K  743M   1% /run/user/1000
otus/test       350M  2.9M  347M   1% /otus/test
```

Ищем файл и выводим его содержимое:
```bash
$ find /otus/test -name secret_message
/otus/test/task1/file_mess/secret_message

$ cat /otus/test/task1/file_mess/secret_message
https://otus.ru/lessons/linux-hl/
```
