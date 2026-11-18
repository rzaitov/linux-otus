# Домашнее задание

1. Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в `/etc/default`).
2. Установить spawn-fcgi и создать unit-файл (`spawn-fcgi.service`) с помощью переделки [init-скрипта](https://gist.github.com/cea2k/1318020).
3. Доработать unit-файл Nginx (`nginx.service`) для запуска нескольких инстансов сервера с разными конфигурационными файлами одновременно.

## Инструкция по выполнению домашнего задания

### 1. Мониторинг лога каждые 30 секунд

Для начала создаём файл с конфигурацией для сервиса в директории `/etc/default` — из неё сервис будет брать необходимые переменные.

Файл `/etc/default/watchlog`:

```bash
# Configuration file for my watchlog service
# Place it to /etc/default

# File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log
```

Затем создаём `/var/log/watchlog.log` и пишем туда строки на своё усмотрение, плюс ключевое слово `ALERT`.

#### Скрипт

Создадим скрипт `/opt/watchlog.sh`:

```bash
#!/bin/bash

WORD=$1
LOG=$2
DATE=`date`

if grep $WORD $LOG &> /dev/null
then
    logger "$DATE: I found word, Master!"
else
    exit 0
fi
```

Команда `logger` отправляет лог в системный журнал.

Добавим права на запуск файла:

```bash
chmod +x /opt/watchlog.sh
```

#### Юнит сервиса

Создадим юнит `/etc/systemd/system/watchlog.service`:

```ini
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/default/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
```

#### Юнит таймера

Создадим юнит `/etc/systemd/system/watchlog.timer`:

```ini
[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target
```

#### Запуск и проверка

Затем достаточно только запустить timer:

```bash
systemctl start watchlog.timer
```

И убедиться в результате:

```bash
tail -n 1000 /var/log/syslog | grep word
```

Пример вывода:

```text
Jun  5 13:21:41 ubuntu-jammy root: Wed Jun  5 13:21:41 UTC 2024: I found word, Master!
Jun  5 13:22:23 ubuntu-jammy root: Wed Jun  5 13:22:23 UTC 2024: I found word, Master!
Jun  5 13:23:03 ubuntu-jammy root: Wed Jun  5 13:23:03 UTC 2024: I found word, Master!
```

### 2. Установка spawn-fcgi и создание unit-файла

Устанавливаем spawn-fcgi и необходимые для него пакеты:

```bash
apt install spawn-fcgi php php-cgi php-cli \
    apache2 libapache2-mod-fcgid -y
```

Сам init-скрипт, который будем переписывать, можно найти [здесь](https://gist.github.com/cea2k/1318020).

#### Конфигурация сервиса

Но перед этим необходимо создать файл с настройками для будущего сервиса в файле `/etc/spawn-fcgi/fcgi.conf`. Он должен получиться следующего вида:

```bash
# You must set some working options before the "spawn-fcgi" service will work.
# If SOCKET points to a file, then this file is cleaned up by the init script.
#
# See spawn-fcgi(1) for all possible options.
#
# Example :
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u www-data -g www-data -s $SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
```

#### Юнит сервиса

А сам юнит-файл `/etc/systemd/system/spawn-fcgi.service` будет примерно следующего вида:

```ini
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/spawn-fcgi/fcgi.conf
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
```

#### Запуск и проверка

Убеждаемся, что всё успешно работает:

```bash
systemctl start spawn-fcgi
systemctl status spawn-fcgi
```

### 3. Запуск нескольких инстансов Nginx

Установим Nginx из стандартного репозитория:

```bash
apt install nginx -y
```

#### Шаблонный юнит

Для запуска нескольких экземпляров сервиса модифицируем исходный service для использования различной конфигурации, а также PID-файлов. Для этого создадим новый Unit для работы с шаблонами — `/etc/systemd/system/nginx@.service`:

```ini
# Stop dance for nginx
# =======================
#
# ExecStop sends SIGSTOP (graceful stop) to the nginx process.
# If, after 5s (--retry QUIT/5) nginx is still running, systemd takes control
# and sends SIGTERM (fast shutdown) to the main process.
# After another 5s (TimeoutStopSec=5), and if nginx is alive, systemd sends
# SIGKILL to all the remaining processes in the process group (KillMode=mixed).
#
# nginx signals reference doc:
# http://nginx.org/en/docs/control.html
#
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx-%I.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-%I.conf -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx-%I.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target
```

#### Конфигурации экземпляров

Далее необходимо создать два файла конфигурации:

- `/etc/nginx/nginx-first.conf`;
- `/etc/nginx/nginx-second.conf`.

Их можно сформировать из стандартного конфига `/etc/nginx/nginx.conf`, с модификацией путей до PID-файлов и разделением по портам:

```nginx
pid /run/nginx-first.pid;

http {
    …
    server {
        listen 9001;
    }
    #include /etc/nginx/sites-enabled/*;
    …
}
```

Этого достаточно для успешного запуска сервисов.

#### Запуск и проверка

Проверим работу:

```bash
systemctl start nginx@first
systemctl start nginx@second
systemctl status nginx@second
```

Проверить можно несколькими способами, например, посмотреть, какие порты слушаются:

```bash
ss -tnulp | grep nginx
```

Или просмотреть список процессов:

```bash
ps afx | grep nginx
```

Если мы видим две группы процессов Nginx, то всё в порядке. Если сервисы не стартуют, смотрим их статус, ищем ошибки, проверяем ошибки в `/var/log/nginx/error.log`, а также в `journalctl -u nginx@first`.

Задание выполнено.

## Критерии приёмки

Статус «Принято» ставится при выполнении основных пунктов задачи (1–3).
