# Отчет по домашнему заданию

## watchlog

Подключаемся к виртуальной машине и создаем файл `/etc/default/watchlog`:
```bash
$ vim /etc/default/watchlog

WORD="ALERT"
LOG=/var/log/watchlog.log

:wq
```

Создадим пока пустой файл с логом:
```bash
$ touch /var/log/watchlog.log
```

Дадим права на исполнение скрипту:
```bash
$ chmod +x /opt/watchlog.sh
```

Мой скрипт имеет пару существенных отличий от скрипта, предложенного в методичке:
```bash
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
```

* `-F` ищет строковый литерал, а не регулярное выражение
* `--` нужно отделить аргументы к grep, иначе grep воспримет ключевое слово, которое начинается с дефиса, например, `-WARN` как свою опцию.

Также предложенный в методичке watchlog.timer не запустит watchlog.service. Исправленная версия:
```systemd
[Unit]
Description=Run watchlog script every 30 second

[Timer]
AccuracySec=5s
OnActiveSec=0s
OnUnitActiveSec=30s

[Install]
WantedBy=timers.target
```

В методичке указано только `OnUnitActiveSec=30s`, обратимся к man page:
```bash
$ man systemd.timer
...
│ OnUnitActiveSec=   │ Defines a timer relative to when the unit the     │
│                    │ timer unit is activating was last activated.      │
```

Т.е. это указывает время отсчета от запуска watchlog.service. Поэтому если указать только этот параметр, как сделано в методичке, то запуск таймера не приведет к запуску сервиса, т.к. еще не существует "предыдущего запуска". Указание же `OnActiveSec=0s` исправлет эту проблему, т.к. запуск таймера приводит к немедленному запуску сервиса, от которого уже потом будет отсчитываться 30секундная задержка для последующего запуска.

Теперь можно активировать таймер и убедиться в его работе:
```bash
$ systemctl start watchlog.service

$ journalctl -u watchlog
...
Nov 18 10:26:10 otus watchlog.sh[20237]: some ALERT from Rustam
Nov 18 10:26:10 otus root[20239]: [Wed Nov 18 10:26:10 AM UTC 2026]: keyword 'ALERT' found
Nov 18 10:26:10 otus systemd[1]: watchlog.service: Deactivated successfully.
Nov 18 10:26:10 otus systemd[1]: Finished watchlog.service - Simple watchlog service.
Nov 18 10:26:45 otus systemd[1]: Starting watchlog.service - Simple watchlog service...
Nov 18 10:26:45 otus watchlog.sh[20242]: some ALERT from Rustam
...
```

## spawn-fcgi.service

Методичка предложенная для выполнения ДЗ содержит серьезную ошибку.

В методичке предлогается создать файл `/etc/spawn-fcgi/fcgi.conf`:
```bash
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u www-data -g www-data -s $SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
```

И сам сервис `spawn-fcgi.service`:
```ini
...
[Service]
EnvironmentFile=/etc/spawn-fcgi/fcgi.conf
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
...
```

Очевидно, предполагается, что `$SOCKET` будет подставлен в OPTIONS, но это не так!
bash/sh не интерпретирует указанный в сервисе EnvironmentFile, а значит, что значение переменной окружения SOCKET не будет подставлено.
Для демонстрации проблемы я создал пример сервиса, который выводит в консоль переданные скрипту параметры (см директорию var-expansion).

Сервис `show-args.service`:
```ini
[Unit]
Description=systemd environment variable expansion demo

[Service]
Type=oneshot
EnvironmentFile=/tmp/show-args.env
ExecStart=/etc/show-args.sh $OPTIONS
```

Файл с переменными `show-args.env`:
```bash
SOCKET=/run/example.sock
OPTIONS="-s $SOCKET"
```

Вызываемый скрипт `show-args.sh`:
```bash
#!/bin/bash

set -euo pipefail

printf 'SOCKET=<%s>\n' "$SOCKET"
printf 'OPTIONS=<%s>\n' "$OPTIONS"
printf 'arguments=<%s>\n' "$@"
```

Запустим данный сервис и посмотрим, что он выведет:
```bash
$ systemctl start show-args.service

$ journalctl -u show-args.service
Nov 18 15:04:44 otus systemd[1]: Starting show-args.service - systemd environment variable expansion demo...
Nov 18 15:04:44 otus show-args.sh[21537]: SOCKET=</run/example.sock>
Nov 18 15:04:44 otus show-args.sh[21537]: OPTIONS=<-s $SOCKET>
Nov 18 15:04:44 otus show-args.sh[21537]: arguments=<-s>
Nov 18 15:04:44 otus show-args.sh[21537]: arguments=<$SOCKET>
Nov 18 15:04:44 otus systemd[1]: show-args.service: Deactivated successfully.
Nov 18 15:04:44 otus systemd[1]: Finished show-args.service - systemd environment variable expansion demo.
```

Видно, что значение переменной SOCKET не было подставлено в OPTIONS.

Возвращаясь к заданию, исправленный env файл не должен содержать подстановок:
```bash
OPTIONS="-u www-data -g www-data -s /var/run/php-fcgi.sock -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
```

Также `man systemd.kill` не рекомендует использовать KillMode=process, как сделано в методичке:
```bash
$ man systemd.kill

KillMode=
    ...
    If set to process, only the main process itself is killed (not recommended!).
    ...
```

После описанных выше исправлений, попытаемся запустить сервис и проверить что он работает:
```bash
$ apt install spawn-fcgi php php-cgi php-cli apache2 libapache2-mod-fcgid -y
$ install -D -m 644 fcgi.conf /etc/spawn-fcgi/fcgi.conf
$ install -m 644 spawn-fcgi.service /etc/systemd/system/spawn-fcgi.service

$ systemctl daemon-reload
$ systemctl start spawn-fcgi.service
$ systemctl status spawn-fcgi.service

● spawn-fcgi.service - Spawn-fcgi startup service by Otus
     Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; preset: enabled)
     Active: active (running) since Wed 2026-11-18 16:22:20 UTC; 7s ago
 Invocation: fc71b324803349bb92ab37ed59845b26
   Main PID: 28736 (php-cgi)
      Tasks: 33 (limit: 8826)
     Memory: 16M (peak: 16M)
        CPU: 88ms
     CGroup: /system.slice/spawn-fcgi.service
             ├─28736 /usr/bin/php-cgi
             ├─28741 /usr/bin/php-cgi
             ├─28742 /usr/bin/php-cgi
             ├─28743 /usr/bin/php-cgi
             ├─28744 /usr/bin/php-cgi
             ├─28745 /usr/bin/php-cgi
             ├─28746 /usr/bin/php-cgi
             ├─28747 /usr/bin/php-cgi
             ├─28748 /usr/bin/php-cgi
             ├─28749 /usr/bin/php-cgi
             ├─28750 /usr/bin/php-cgi
             ├─28751 /usr/bin/php-cgi
             ├─28752 /usr/bin/php-cgi
             ├─28753 /usr/bin/php-cgi
             ├─28754 /usr/bin/php-cgi
             ├─28755 /usr/bin/php-cgi
             ├─28756 /usr/bin/php-cgi
             ├─28757 /usr/bin/php-cgi
             ├─28758 /usr/bin/php-cgi
             ├─28759 /usr/bin/php-cgi
             ├─28760 /usr/bin/php-cgi
             ├─28761 /usr/bin/php-cgi
             ├─28762 /usr/bin/php-cgi
             ├─28763 /usr/bin/php-cgi
             ├─28764 /usr/bin/php-cgi
lines 1-34
```

Видно, что было запущенно много дочерних процессов. Проверим, что измененный KillMode был сделан не зря:
```bash
$ systemctl stop spawn-fcgi.service
$ pgrep php-cgi
# nothing here
```

## nginx

Установим nginx, как было предложено в методичке:
```bash
$ apt install nginx -y
```

В debian based системах nginx запускается при установке. Остановим его:
```bash
$ systemctl stop nginx
$ systemctl disable nginx
Synchronizing state of nginx.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install disable nginx
Removed '/etc/systemd/system/multi-user.target.wants/nginx.service'.

$ systemctl status nginx
○ nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; preset: enabled)
     Active: inactive (dead)
       Docs: man:nginx(8)

Nov 18 16:31:58 otus systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
Nov 18 16:31:58 otus systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.
Nov 18 16:39:11 otus systemd[1]: Stopping nginx.service - A high performance web server and a reverse proxy server...
Nov 18 16:39:11 otus systemd[1]: nginx.service: Deactivated successfully.
Nov 18 16:39:11 otus systemd[1]: Stopped nginx.service - A high performance web server and a reverse proxy server.
```

Копируем существующий nginx unit файл:
```bash
$ systemctl cat nginx.service > /etc/systemd/system/nginx@.service
```

Отредактируем nginx@.service файл как указано в методичке, указав явно путь к конфигурационному файлу - `-c /etc/nginx/nginx-%I.conf`

Скопируем файл конфигурации для первого и второго инстансов:
```bash
$ cp /etc/nginx/nginx.conf /etc/nginx/nginx-first.conf
$ cp /etc/nginx/nginx.conf /etc/nginx/nginx-second.conf
```

Обновим nginx-first.conf:
```bash
$ vim /etc/nginx/nginx-first.conf

pid /run/nginx-first.pid;
error_log /var/log/nginx/error-first.log;
...
http {
  server {
      listen 9001;
  }
  ...
  access_log /var/log/nginx/access-first.log;
  # include /etc/nginx/sites-enabled/*;
}
```

Обновим nginx-second.conf:
```bash
$ vim /etc/nginx/nginx-second.conf

pid /run/nginx-second.pid;
error_log /var/log/nginx/error-second.log;
...
http {
  server {
      listen 9002;
  }
  ...
  access_log /var/log/nginx/access-second.log;
  # include /etc/nginx/sites-enabled/*;
}
```

Стартуем сервера и проверяем их работу:
```bash
$ systemctl start nginx@first
$ systemctl status nginx@first
● nginx@first.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/etc/systemd/system/nginx@.service; disabled; preset: enabled)
     Active: active (running) since Wed 2026-11-18 16:54:59 UTC; 4s ago
 Invocation: e24e5542ead94fe1ab5b4e67f00c696f
       Docs: man:nginx(8)
    Process: 29908 ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-first.conf -q -g daemon on; master_process on; (code=exited, status=0/SUCCE>
    Process: 29909 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-first.conf -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 29911 (nginx)
      Tasks: 3 (limit: 8826)
     Memory: 3.4M (peak: 3.4M)
        CPU: 75ms
     CGroup: /system.slice/system-nginx.slice/nginx@first.service
             ├─29911 "nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx-first.conf -g daemon on; master_process on;"
             ├─29912 "nginx: worker process"
             └─29913 "nginx: worker process"

Nov 18 16:54:58 otus systemd[1]: Starting nginx@first.service - A high performance web server and a reverse proxy server...
Nov 18 16:54:59 otus systemd[1]: Started nginx@first.service - A high performance web server and a reverse proxy server.

$ curl localhost:9001
<!DOCTYPE html>
....
```

Запускаем второй:
```bash
$ systemctl start nginx@second
$ systemctl status nginx@second
● nginx@second.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/etc/systemd/system/nginx@.service; disabled; preset: enabled)
     Active: active (running) since Wed 2026-11-18 17:02:14 UTC; 4s ago
 Invocation: 2d83417c134340e9bbe452f3ca98d092
       Docs: man:nginx(8)
    Process: 30069 ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-second.conf -q -g daemon on; master_process on; (code=exited, status=0/SUCC>
    Process: 30070 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-second.conf -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 30072 (nginx)
      Tasks: 3 (limit: 8826)
     Memory: 3.1M (peak: 3.2M)
        CPU: 79ms
     CGroup: /system.slice/system-nginx.slice/nginx@second.service
             ├─30072 "nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx-second.conf -g daemon on; master_process on;"
             ├─30073 "nginx: worker process"
             └─30074 "nginx: worker process"

Nov 18 17:02:14 otus systemd[1]: Starting nginx@second.service - A high performance web server and a reverse proxy server...
Nov 18 17:02:14 otus systemd[1]: Started nginx@second.service - A high performance web server and a reverse proxy server.

$ curl localhost:9002
<!DOCTYPE html>
....
```
