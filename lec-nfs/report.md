# NFS

## NFS сервер

Установим пакет, чтобы запустить nfs server:
```bash
$ apt install nfs-kernel-server
...
```

Посмотрим какие сервисы распространяются с этим пакетом:
```bash
$ dpkg -L nfs-kernel-server | grep service
/usr/lib/systemd/system/fsidd.service
/usr/lib/systemd/system/nfs-mountd.service
/usr/lib/systemd/system/nfs-server.service
/usr/lib/systemd/system/nfsdcld.service
/usr/lib/systemd/system/nfs-kernel-server.service
```

Проверяем порты:
```bash
$ ss -tulpn | grep 2049
tcp   LISTEN 0      4096                           0.0.0.0:2049       0.0.0.0:*
tcp   LISTEN 0      4096                              [::]:2049          [::]:*

$ ss -tulpn | grep 111
udp   UNCONN 0      0                              0.0.0.0:111        0.0.0.0:*    users:(("rpcbind",pid=777,fd=5),("systemd",pid=1,fd=41))
udp   UNCONN 0      0                                 [::]:111           [::]:*    users:(("rpcbind",pid=777,fd=7),("systemd",pid=1,fd=43))
tcp   LISTEN 0      4096                           0.0.0.0:111        0.0.0.0:*    users:(("rpcbind",pid=777,fd=4),("systemd",pid=1,fd=40))
tcp   LISTEN 0      4096                              [::]:111           [::]:*    users:(("rpcbind",pid=777,fd=6),("systemd",pid=1,fd=42))
```

Создадим директорию в которой будут храниться nfs share директории:
```bash
$ mkdir -p /mnt/nfs-export/upload
$ chown -R nobody:nogroup /mnt/nfs-export/
$ chmod 0777 /mnt/nfs-export/upload/
```

Забекапим файл с конфигурацией:
```bash
$ cp /etc/exports /etc/exports.bak
```

Определим подсеть для которой будет доступен nfs сервер:
```bash
$ ip addr
...
3: enp7s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 52:54:00:47:54:d0 brd ff:ff:ff:ff:ff:ff
    altname enx5254004754d0
    inet 10.10.10.1/24 scope global enp7s0
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fe47:54d0/64 scope link proto kernel_ll
       valid_lft forever preferred_lft forever
...
```

Предоставляем доступ к папке из под сети:
```bash
$ vim /etc/exports

/mnt/nfs-export/upload 10.10.10.0/24(rw,sync,root_squash,no_subtree_check)
```

Делаем reexport nfs директорий:
```bash
$ exportfs -r
```

Просим показать экспортированные директории:
```bash
$ exportfs -s
/mnt/nfs-export/upload  10.10.10.0/24(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
```

Создадим файл на сервере:
```bash
$ echo "hello from Rustam!" > /mnt/nfs-export/upload/hello
```

## NFS клиент

Установим пакет, чтобы запустить nfs клиент:
```bash
$ apt install nfs-common
...
```

Проверим, что предлагает нам nfs server:
```bash
$ showmount --exports 10.10.10.1
Export list for 10.10.10.1:
/mnt/nfs-export/upload 10.10.10.0/24
```

Динамическое монтирование будем делать через autofs. Установим необходимый пакет:
```bash
$ apt install autofs
```

Создадим директорию куда будут монтироваться nfs директории:
```bash
$ mkdir -p /mnt/nfs
```

Потребуется изменить 2 файла конфигурации:
```bash
$ vim /etc/auto.master
/mnt/nfs /etc/auto.nfs --ghost --timeout=60

$ vim /etc/auto.nfs
upload -fstype=nfs4,rw 10.10.10.1:/mnt/nfs-export/upload
```
`--ghost` автоматически создаст `upload` внутри `/mnt/nfs` при обращении.
`--timeout=60` после 60с неиспользование произойдет отмантирование.

Перезапустим `autofs` чтобы применить изменения конфигурационных файлов:
```bash
$ systemctl restart autofs.service
```

При этом, без обращения к `/mnt/nfs` файловая система не монтируется:
```bash
$ df -h | grep "/mnt/nfs"
# пусто
```

Запросим содержимое папки `/mnt/nfs`:
```bash
$ ll /mnt/nfs
total 8
drwxr-xr-x  3 root   root       0 Nov  2 16:45 ./
drwxr-xr-x 14 root   root    4096 Nov  2 16:34 ../
drwxrwxrwx+ 2 nobody nogroup 4096 Nov  2 14:50 upload/
```

Видно, что монтирование произведено:
```bash
$ df -h | grep "/mnt/nfs"
10.10.10.1:/mnt/nfs-export/upload   12G  2.9G  7.8G  28% /mnt/nfs/upload
```

Прочитаем файл c nfs сервера и запишем файл на сервер:
```bash
$ cat /mnt/nfs/upload/hello
hello from Rustam!

$ echo "topsecret" > /mnt/nfs/upload/password
```

Проверим, что timeout указанный в /etc/auto.master работает:
```bash
$ watch "mount | grep nfs"

Every 2.0s: mount | grep nfs                                                                                 otus-session: Mon Nov  2 16:47:58 2026

/etc/auto.nfs on /mnt/nfs type autofs (rw,relatime,fd=6,pgrp=3998,timeout=60,minproto=5,maxproto=5,indirect,pipe_ino=23964)
10.10.10.1:/mnt/nfs-export/upload on /mnt/nfs/upload type nfs4 (rw,relatime,vers=4.2,rsize=1048576,wsize=1048576,namlen=255,hard,fatal_neterrors=no
ne,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=10.10.10.2,local_lock=none,addr=10.10.10.1)

## 60 seconds later ##

Every 2.0s: mount | grep nfs                                                                                 otus-session: Mon Nov  2 16:48:58 2026

/etc/auto.nfs on /mnt/nfs type autofs (rw,relatime,fd=6,pgrp=3998,timeout=60,minproto=5,maxproto=5,indirect,pipe_ino=23964)
```

### Комментарий

При попытке воспользоваться nfs3 как указано в задании я получал что-то
странное при просмотре содержимого nfs директории:
```bash
$ vim /etc/auto.nfs
upload -fstype=nfs3,rw 10.10.10.1:/mnt/nfs-export/upload
```

Вот что я видел:
```bash
$ ll /mnt/nfs
total 4
drwxr-xr-x  3 root root    0 Nov  2 16:41 ./
drwxr-xr-x 14 root root 4096 Nov  2 16:34 ../
d?????????  ? ?    ?       ?            ? upload/
```

Про настройку AutoFS я смотрел вот это видео:
How to Set Up an NFS Server on Ubuntu (Complete with AutoFS!)
https://www.youtube.com/watch?v=Na_jKeVWzrc

Если честно, то большую часть времени заняла настройка виртуальной сети в virt-manager ))
Задание мне очень понравилось, как и сама лекция, в силу их практичности.
Раньше я использовал внешние hdd диски если хотел забекапить какие-то данные перед переустановкой OC, то теперь буду настраивать NFS.
