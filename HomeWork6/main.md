## Урок 6

### Подготовка инфраструктуры
> Создана ВМ с Ubuntu 20.04 через Oracle Virtualbox.
  На ВМ установлен postgresql версии 15.2
### Проверка кластера, наполнение таблицы, остановка кластера
> Ниже привожу блок команд. Порт 5433 подтянулся из за того что 5432 уже был занят docker контейнером.

```bash
root@ubuntu1:/home/dekholud# sudo -u postgres pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
15  main    5433 online postgres /var/lib/postgresql/15/main /var/log/postgresql/postgresql-15-main.log
root@ubuntu1:/home/dekholud# psql -U postgres -h localhost -p 5433
Пароль пользователя postgres:
psql (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
SSL-соединение (протокол: TLSv1.3, шифр: TLS_AES_256_GCM_SHA384, сжатие: выкл.)
Введите "help", чтобы получить справку.

postgres=# create database db_1
postgres-# ;
CREATE DATABASE
postgres=# \c db_1
SSL-соединение (протокол: TLSv1.3, шифр: TLS_AES_256_GCM_SHA384, сжатие: выкл.)
Вы подключены к базе данных "db_1" как пользователь "postgres".
db_1=# create table test(c1 text);
CREATE TABLE
db_1=# insert into test values('1');
INSERT 0 1
db_1=# \q
root@ubuntu1:/home/dekholud# sudo -u postgres pg_ctlcluster 15 main stop
Warning: stopping the cluster using pg_ctlcluster will mark the systemd unit as failed. Consider using systemctl:
  sudo systemctl stop postgresql@15-main
root@ubuntu1:/home/dekholud# sudo -u postgres pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
15  main    5433 down   postgres /var/lib/postgresql/15/main /var/log/postgresql/postgresql-15-main.log
```
### Монтирование диска
> Через Virualbox добавляю диск нужного размера
![Добавление диска](img/hdd.png?raw=true "Добавление диска")
Далее привожу блок команд для монтирования диска

```bash
root@ubuntu1:/home/dekholud# parted -l | grep Error
Error: /dev/sdb: unrecognised disk label
root@ubuntu1:/home/dekholud# lsblk
NAME                      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
loop0                       7:0    0 63,3M  1 loop /snap/core20/1828
loop1                       7:1    0 91,9M  1 loop /snap/lxd/24061
loop2                       7:2    0 49,9M  1 loop /snap/snapd/18357
sda                         8:0    0   20G  0 disk
├─sda1                      8:1    0    1M  0 part
├─sda2                      8:2    0  1,8G  0 part /boot
└─sda3                      8:3    0 18,2G  0 part
  └─ubuntu--vg-ubuntu--lv 253:0    0   10G  0 lvm  /
sdb                         8:16   0   10G  0 disk
sr0                        11:0    1 1024M  0 rom
root@ubuntu1:/home/dekholud# mkfs.ext4 -L datapartition /dev/sdb
mke2fs 1.45.5 (07-Jan-2020)
Creating filesystem with 2621440 4k blocks and 655360 inodes
Filesystem UUID: 3ab6ff3c-4a23-4c50-90c6-fb99269f95c6
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632

Allocating group tables: done
Writing inode tables: done
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done

root@ubuntu1:/home/dekholud# mkdir -p /mnt/data
root@ubuntu1:/home/dekholud# mount -o defaults /dev/sdb /mnt/data
root@ubuntu1:/home/dekholud# nano /etc/fstab
root@ubuntu1:/home/dekholud# df -h -x tmpfs
Filesystem                         Size  Used Avail Use% Mounted on
udev                               1,9G     0  1,9G   0% /dev
/dev/mapper/ubuntu--vg-ubuntu--lv  9,8G  4,6G  4,8G  49% /
/dev/loop1                          92M   92M     0 100% /snap/lxd/24061
/dev/loop0                          64M   64M     0 100% /snap/core20/1828
/dev/loop2                          50M   50M     0 100% /snap/snapd/18357
/dev/sda2                          1,8G  108M  1,5G   7% /boot
/dev/sdb                           9,8G   24K  9,3G   1% /mnt/data
root@ubuntu1:/home/dekholud#reboot
```
> После reboot точка монтирования все также сохраняется.

### Перенос данных и запуск кластера
```bash
root@ubuntu1:/home/dekholud# chown -R postgres:postgres /mnt/data/
root@ubuntu1:/home/dekholud# mv /var/lib/postgresql/15/ /mnt/data/
root@ubuntu1:/home/dekholud# sudo -u postgres pg_ctlcluster 15 main start
Error: /var/lib/postgresql/15/main is not accessible or does not exist
```
> Кластер ожидаемо не стартует, т.к. читает данные там где их уже не существует. В конфиг файле /etc/postgresql/15/main/postgresql.conf меняем параметр data_directory на значение /mnt/data/15/main, после чего кластер успешно стартует. Данные ожидаемо остались на месте:
```bash
root@ubuntu1:/etc/postgresql/15/main# systemctl start postgresql@15-main

root@ubuntu1:/etc/postgresql/15/main# psql -U postgres -h localhost -p 5433
Пароль пользователя postgres:
psql (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
SSL-соединение (протокол: TLSv1.3, шифр: TLS_AES_256_GCM_SHA384, сжатие: выкл.)
Введите "help", чтобы получить справку.

postgres=# \c db_1
SSL-соединение (протокол: TLSv1.3, шифр: TLS_AES_256_GCM_SHA384, сжатие: выкл.)
Вы подключены к базе данных "db_1" как пользователь "postgres".
db_1=# select * from test;
 c1
----
 1
(1 строка)

db_1=#
```

### Доступ кластера postgresql к данным на другой ВМ

> Самое простое и логичное решение использовать NFS для решения задачи:

- Клонируем нашу ВМ полностью.
- На обоих ВМ останавливаем кластер postgresql.
- На второй ВМ убираем точку монтирования и внешний диск через umount /mnt/data/ и удаление диска через интерфейс virtualbox.
Имеем 2 машины
ununtu1 - ip 192.168.1.101
ununtu2 - ip 192.168.1.102

> На ununtu1:

```bash
apt install nfs-kernel-server

Добавляем в файл /etc/exports строку 
/mnt/data 192.168.1.102(rw,sync,no_subtree_check)

exportfs -a
```
> На ununtu2:

```bash
В /etc/fstab добавляем 192.168.1.101:/mnt/data /mnt/data nfs rw,auto,rw 0 2

reboot
```
> Затем проверяем что директория примонтировалась и стартуем кластер

```bash
root@ubuntu2:/home/dekholud# df -h
Filesystem                         Size  Used Avail Use% Mounted on
udev                               1,9G     0  1,9G   0% /dev
tmpfs                              394M  1,2M  393M   1% /run
/dev/mapper/ubuntu--vg-ubuntu--lv  9,8G  4,7G  4,6G  51% /
tmpfs                              2,0G  1,1M  2,0G   1% /dev/shm
tmpfs                              5,0M     0  5,0M   0% /run/lock
tmpfs                              2,0G     0  2,0G   0% /sys/fs/cgroup
/dev/loop0                          64M   64M     0 100% /snap/core20/1828
/dev/loop2                          92M   92M     0 100% /snap/lxd/24061
/dev/loop1                          50M   50M     0 100% /snap/snapd/18357
/dev/sda2                          1,8G  108M  1,5G   7% /boot
192.168.1.101:/mnt/data            9,8G   46M  9,2G   1% /mnt/data
/dev/loop3                          54M   54M     0 100% /snap/snapd/18933
/dev/loop4                          64M   64M     0 100% /snap/core20/1852
tmpfs                              394M     0  394M   0% /run/user/1000

root@ubuntu2:/home/dekholud# systemctl start postgresql@15-main

```
> На данном этапе могут возникнуть проблемы с правами доступа, на обоих серверах у юзера ОС postgres должен быть одинаковый UID. Проверить можно командой id postgres. В моем случае это так, поэтому кластер успешно стартует.
Дополнительно проверяем, что данные остались на месте и пробуем положить новую строку, чтобы проверить права на запись.

```bash
root@ubuntu2:/home/dekholud# systemctl status postgresql@15-main
● postgresql@15-main.service - PostgreSQL Cluster 15-main
     Loaded: loaded (/lib/systemd/system/postgresql@.service; enabled-runtime; vendor preset: enabled)
     Active: active (running) since Mon 2023-05-01 12:10:52 UTC; 6min ago
   Main PID: 871 (postgres)
      Tasks: 6 (limit: 4609)
     Memory: 47.7M
     CGroup: /system.slice/system-postgresql.slice/postgresql@15-main.service
             ├─ 871 /usr/lib/postgresql/15/bin/postgres -D /mnt/data/15/main -c config_file=/etc/postgresql/15/main/postgresql.conf
             ├─ 880 postgres: 15/main: checkpointer
             ├─ 881 postgres: 15/main: background writer
             ├─1365 postgres: 15/main: walwriter
             ├─1366 postgres: 15/main: autovacuum launcher
             └─1367 postgres: 15/main: logical replication launcher

мая 01 12:10:27 ubuntu2 systemd[1]: Starting PostgreSQL Cluster 15-main...
мая 01 12:10:52 ubuntu2 systemd[1]: Started PostgreSQL Cluster 15-main.
root@ubuntu2:/home/dekholud# psql -U postgres -h localhost -p 5433
Пароль пользователя postgres:
psql (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
SSL-соединение (протокол: TLSv1.3, шифр: TLS_AES_256_GCM_SHA384, сжатие: выкл.)
Введите "help", чтобы получить справку.

postgres=# \c db_1
SSL-соединение (протокол: TLSv1.3, шифр: TLS_AES_256_GCM_SHA384, сжатие: выкл.)
Вы подключены к базе данных "db_1" как пользователь "postgres".
db_1=# select * from test;
 c1
----
 1
(1 строка)

db_1=# insert into test values('2');
INSERT 0 1
db_1=# select * from test;
 c1
----
 1
 2
(2 строки)

db_1=#
```