## Урок 13

### Установка кластера, подготовка данных
> Postgres 15 уже установлен. Просто добавил новый кластер по порту 5434.
```sql
dekholud@ubuntu1:~$ sudo -u postgres pg_lsclusters
Ver Cluster Port Status Owner    Data directory               Log file
15  main    5432 online postgres /mnt/data/15/main            /var/log/postgresql/postgresql-15-main.log
15  main2   5433 online postgres /var/lib/postgresql/15/main2 /var/log/postgresql/postgresql-15-main2.log
15  main3   5434 online postgres /var/lib/postgresql/15/main3 /var/log/postgresql/postgresql-15-main3.log
dekholud@ubuntu1:~$ sudo -u postgres psql -p 5434
psql (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
Введите "help", чтобы получить справку.

postgres=# create database db_test_backup;
CREATE DATABASE
postgres=# \c db_test_backup
Вы подключены к базе данных "db_test_backup" как пользователь "postgres".
db_test_backup=# create schema schema_test_backup;
CREATE SCHEMA
db_test_backup=# create table schema_test_backup.tab_test(a int);
CREATE TABLE
db_test_backup=# INSERT INTO schema_test_backup.tab_test SELECT generate_series(1,100);
INSERT 0 100

```

### Логический бэкап одной таблицы в другую, используя утилиту COPY
> Ниже приведен блок команд по созданию директории, выгрузке бэкапа и загрузке в другую таблицу.

```sql
dekholud@ubuntu1:~$ sudo -u postgres mkdir /var/lib/postgresql/15/main3/backup
dekholud@ubuntu1:~$ sudo -u postgres psql -p 5434 -d db_test_backup
psql (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
Введите "help", чтобы получить справку.

db_test_backup=# \copy schema_test_backup.tab_test to '/var/lib/postgresql/15/main3/backup/tab_test.sql';
COPY 100
db_test_backup=# create table schema_test_backup.tab_test2(a int);
CREATE TABLE
db_test_backup=# \copy schema_test_backup.tab_test2 from '/var/lib/postgresql/15/main3/backup/tab_test.sql';
COPY 100
db_test_backup=# select count(1) from schema_test_backup.tab_test2;
 count
-------
   100
(1 строка)

```

### Бэкап через pg_dump и pg_restore
> Сделаем бэкап в gz формате 2х таблиц
```bash
postgres@ubuntu1:/home/dekholud$ pg_dump -p 5434 -d db_test_backup -t schema_test_backup.tab_test2 -t schema_test_backup.tab_test -Fc > /var/lib/postgresql/15/main3/backup/back_tables.gz
postgres@ubuntu1:/home/dekholud$ ls -la /var/lib/postgresql/15/main3/backup
total 16
drwxrwxr-x  2 postgres postgres 4096 авг 26 12:23 .
drwx------ 20 postgres postgres 4096 авг 26 12:04 ..
-rw-rw-r--  1 postgres postgres 2141 авг 26 12:23 back_tables.gz
-rw-rw-r--  1 postgres postgres  292 авг 26 12:06 tab_test.sql
postgres@ubuntu1:/home/dekholud$

```
> Используя pg_restore восстановим только 2ю таблицу
```sql
postgres=# create database db_dump_backup;
CREATE DATABASE
postgres=# \c db_dump_backup
Вы подключены к базе данных "db_dump_backup" как пользователь "postgres".
db_dump_backup=# create schema schema_test_backup;
CREATE SCHEMA
db_dump_backup=# CREATE SCHEMA
postgres@ubuntu1:/home/dekholud$ pg_restore -p 5434 -d db_dump_backup -U postgres -t tab_test2 '/var/lib/postgresql/15/main3/backup/back_tables.gz'

db_dump_backup=# select * from pg_tables where schemaname='schema_test_backup';
     schemaname     | tablename | tableowner | tablespace | hasindexes | hasrules | hastriggers | rowsecurity
--------------------+-----------+------------+------------+------------+----------+-------------+-------------
 schema_test_backup | tab_test2 | postgres   |            | f          | f        | f           | f
(1 строка)

db_dump_backup=# select * from schema_test_backup.tab_test2 limit 5;
 a
---
 1
 2
 3
 4
 5
(5 строк)

```