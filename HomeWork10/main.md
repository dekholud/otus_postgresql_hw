## Урок 10

### Установка checkpoint_timeout
```sql
dekholud@ubuntu1:~$ sudo -u postgres psql
[sudo] password for dekholud:
psql (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
Введите "help", чтобы получить справку.

postgres=# alter system set checkpoint_timeout = 30;
ALTER SYSTEM

postgres=# select context from pg_settings where name = 'checkpoint_timeout';
 context
---------
 sighup
(1 строка)

postgres=# select pg_reload_conf();
 pg_reload_conf
----------------
 t
(1 строка)

postgres=# show checkpoint_timeout;
 checkpoint_timeout
--------------------
 30s
(1 строка)

```

### Нагрузка на бд
> До нагрузки на бд сохраням информацию о WAL
```sql
db_1=# SELECT pg_current_wal_lsn(), pg_current_wal_insert_lsn(), pg_walfile_name(pg_current_wal_lsn()) file_current_wal_lsn, pg_walfile_name(pg_current_wal_insert_lsn()) file_current_wal_insert_lsn;
 pg_current_wal_lsn | pg_current_wal_insert_lsn |   file_current_wal_lsn   | file_current_wal_insert_lsn
--------------------+---------------------------+--------------------------+-----------------------------
 2/6F5B2600         | 2/6F5B2600                | 00000001000000020000006F | 00000001000000020000006F
(1 строка)

```
> Также сбросим статистику background writer.
```sql
SELECT pg_stat_reset_shared('bgwriter');
```

> Утилитой pgbench нагружаем бд 10 минут (-T 600)

```bash
dekholud@ubuntu1:~$ sudo -u postgres pgbench -P 30 -T 600 -c 20 db_1
pgbench (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
starting vacuum...end.
progress: 30.0 s, 423.4 tps, lat 47.029 ms stddev 31.082, 0 failed
progress: 60.0 s, 412.4 tps, lat 48.429 ms stddev 33.318, 0 failed
progress: 90.0 s, 432.6 tps, lat 46.153 ms stddev 38.404, 0 failed
progress: 120.0 s, 445.5 tps, lat 44.830 ms stddev 31.082, 0 failed
progress: 150.0 s, 442.2 tps, lat 45.169 ms stddev 31.994, 0 failed
progress: 180.0 s, 419.1 tps, lat 47.672 ms stddev 32.856, 0 failed
progress: 210.0 s, 429.7 tps, lat 46.481 ms stddev 32.501, 0 failed
progress: 240.0 s, 424.5 tps, lat 47.047 ms stddev 32.560, 0 failed
progress: 270.0 s, 434.8 tps, lat 45.940 ms stddev 32.326, 0 failed
progress: 300.0 s, 442.2 tps, lat 45.166 ms stddev 30.929, 0 failed
progress: 330.0 s, 447.3 tps, lat 44.640 ms stddev 31.208, 0 failed
progress: 360.0 s, 441.4 tps, lat 45.267 ms stddev 31.706, 0 failed
progress: 390.0 s, 451.5 tps, lat 44.235 ms stddev 31.097, 0 failed
progress: 420.0 s, 453.4 tps, lat 44.042 ms stddev 30.359, 0 failed
progress: 450.0 s, 455.3 tps, lat 43.867 ms stddev 30.849, 0 failed
progress: 480.0 s, 453.7 tps, lat 44.024 ms stddev 30.156, 0 failed
progress: 510.0 s, 445.1 tps, lat 44.865 ms stddev 32.343, 0 failed
progress: 540.0 s, 450.7 tps, lat 44.311 ms stddev 30.224, 0 failed
progress: 570.0 s, 453.4 tps, lat 44.071 ms stddev 30.536, 0 failed
progress: 600.0 s, 452.7 tps, lat 44.106 ms stddev 30.012, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 20
number of threads: 1
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 264338
number of failed transactions: 0 (0.000%)
latency average = 45.331 ms
latency stddev = 31.826 ms
initial connection time = 65.927 ms
tps = 440.561364 (without initial connection time)
```
> Посмотрим информацию о wal сразу после теста, а также статистику bgwriter.
```sql
db_1=# select checkpoints_timed, checkpoints_req from pg_stat_bgwriter;
 checkpoints_timed | checkpoints_req
-------------------+-----------------
                21 |               0
(1 строка)

db_1=# SELECT pg_current_wal_lsn(), pg_current_wal_insert_lsn(), pg_walfile_name(pg_current_wal_lsn()) file_current_wal_lsn, pg_walfile_name(pg_current_wal_insert_lsn()) file_current_wal_insert_lsn;
 pg_current_wal_lsn | pg_current_wal_insert_lsn |   file_current_wal_lsn   | file_current_wal_insert_lsn
--------------------+---------------------------+--------------------------+-----------------------------
 2/88E55E08         | 2/88E55E08                | 000000010000000200000088 | 000000010000000200000088
(1 строка)
```

> Вычисялем размер журнальных файлов сгенерированный за время работы pgbench
```sql
db_1=# SELECT pg_size_pretty('2/88E55E08'::pg_lsn - '2/6F5B2600'::pg_lsn)
db_1-# ;
 pg_size_pretty
----------------
 409 MB
(1 строка)

```
### Итоги нагрузки
> По статистике bgwriter мы 20 раз сделали контрольную точку, что соответствует 409MB/20 = 20,5 MB журнальных файлов на одну контрольную точку.

> По представлению pg_stat_bgwriter видим, что число принудительных контрольных точек checkpoints_req = 0 и мы выполнили ровно 20 контрольных точек по расписанию.
Потенциально могло быть иначе если бы мы например превысиили max_wal_size до истечения 30 секунд и тогда контрольная точка была бы сделана принудительно.

### Нагрузка в синхронном и асинхронном режиме коммита
> Проверяем параметры бд с которыми мы запускали 1 тест

```sql
db_1=# select name, setting, unit
db_1-# from pg_catalog.pg_settings
db_1-# where name in ('synchronous_commit','commit_delay','commit_siblings','wal_writer_delay');
        name        | setting | unit
--------------------+---------+------
 commit_delay       | 0       |
 commit_siblings    | 5       |
 synchronous_commit | on      |
 wal_writer_delay   | 200     | ms
(4 строки)

```
> Бд работала в синхронном режиме и мы получили tps=440. Переводим бд в асинхронный режим коммита
```sql
db_1=# ALTER SYSTEM SET synchronous_commit = off;
ALTER SYSTEM
db_1=# SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t
(1 строка)

db_1=# select name, setting, unit
from pg_catalog.pg_settings
where name in ('synchronous_commit','commit_delay','commit_siblings','wal_writer_delay');
        name        | setting | unit
--------------------+---------+------
 commit_delay       | 0       |
 commit_siblings    | 5       |
 synchronous_commit | off     |
 wal_writer_delay   | 200     | ms
(4 строки)
```
> Проводим повторный тест с помощью утилиты
```sql
dekholud@ubuntu1:~$ sudo -u postgres pgbench -P 30 -T 600 -c 20 db_1
pgbench (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
starting vacuum...end.
progress: 30.0 s, 1344.8 tps, lat 14.707 ms stddev 9.438, 0 failed
progress: 60.0 s, 1372.7 tps, lat 14.564 ms stddev 9.287, 0 failed
progress: 90.0 s, 1414.9 tps, lat 14.129 ms stddev 8.641, 0 failed
progress: 120.0 s, 1404.3 tps, lat 14.236 ms stddev 8.856, 0 failed
progress: 150.0 s, 1484.3 tps, lat 13.469 ms stddev 8.003, 0 failed
progress: 180.0 s, 1487.8 tps, lat 13.437 ms stddev 8.070, 0 failed
progress: 210.0 s, 1440.9 tps, lat 13.872 ms stddev 8.481, 0 failed
progress: 240.0 s, 1448.3 tps, lat 13.806 ms stddev 8.250, 0 failed
progress: 270.0 s, 1468.5 tps, lat 13.613 ms stddev 8.075, 0 failed
progress: 300.0 s, 1486.9 tps, lat 13.446 ms stddev 8.225, 0 failed
progress: 330.0 s, 1493.4 tps, lat 13.385 ms stddev 7.814, 0 failed
progress: 360.0 s, 1501.5 tps, lat 13.316 ms stddev 8.066, 0 failed
progress: 390.0 s, 1493.7 tps, lat 13.384 ms stddev 7.849, 0 failed
progress: 420.0 s, 1499.1 tps, lat 13.337 ms stddev 7.898, 0 failed
progress: 450.0 s, 1485.4 tps, lat 13.458 ms stddev 8.091, 0 failed
progress: 480.0 s, 1463.5 tps, lat 13.660 ms stddev 8.229, 0 failed
progress: 510.0 s, 1457.5 tps, lat 13.716 ms stddev 8.178, 0 failed
progress: 540.0 s, 1417.3 tps, lat 14.108 ms stddev 9.202, 0 failed
progress: 570.0 s, 1432.1 tps, lat 13.958 ms stddev 8.382, 0 failed
progress: 600.0 s, 1467.1 tps, lat 13.628 ms stddev 8.190, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 20
number of threads: 1
maximum number of tries: 1
duration: 600 s
number of transactions actually processed: 871945
number of failed transactions: 0 (0.000%)
latency average = 13.750 ms
latency stddev = 8.371 ms
initial connection time = 312.342 ms
tps = 1453.905360 (without initial connection time)
```
> Видим что tps вырос до 1453 и производительность существенно выросла. Однако в данном режиме мы жертвуем надежностью и в случае сбоя рискуем потярять часть изменений.

### Кластер с контрольной суммой страниц
> Поднимаем кластер
```bash
sudo -u postgres pg_createcluster 15 main2 --start -- --data-checksums
```
> Создаем таблицу и наполняем данными
```sql
dekholud@ubuntu1:~$ sudo -u postgres psql -p 5433
psql (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
Введите "help", чтобы получить справку.

postgres=# CREATE TABLE test_tb1(a text);
CREATE TABLE
postgres=# insert into test_tb1
postgres-# SELECT a::text FROM generate_series(1,500) AS t(a);
INSERT 0 500
postgres=# SELECT pg_relation_filepath('test_tb1');
 pg_relation_filepath
----------------------
 base/5/16388
(1 строка)

```

> Останавливаем кластер и портим данные таблицы на диске

```bash
dekholud@ubuntu1:~$ sudo -u postgres pg_ctlcluster 15 main2 stop
dekholud@ubuntu1:~$ sudo -u postgres pg_lsclusters
Ver Cluster Port Status Owner    Data directory               Log file
15  main    5432 online postgres /mnt/data/15/main            /var/log/postgresql/postgresql-15-main.log
15  main2   5433 down   postgres /var/lib/postgresql/15/main2 /var/log/postgresql/postgresql-15-main2.log

postgres@ubuntu1:/home/dekholud$ dd if=/dev/zero of=/var/lib/postgresql/15/main2/base/5/16388 oflag=dsync conv=notrunc bs=1 count=8
```
> Поднимаем кластер и пробуем select из нашей таблицы
```bash
dekholud@ubuntu1:~$ sudo -u postgres pg_ctlcluster 15 main2 start
Warning: the cluster will not be running as a systemd service. Consider using systemctl:
  sudo systemctl start postgresql@15-main2
dekholud@ubuntu1:~$ sudo -u postgres psql -p 5433
psql (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
Введите "help", чтобы получить справку.

postgres=# select * from test_tb1;
ПРЕДУПРЕЖДЕНИЕ:  ошибка проверки страницы: получена контрольная сумма 6287, а ожидалась - 31105
ОШИБКА:  неверная страница в блоке 0 отношения base/5/16388
```
> Можем читать неповрежденные данные из таблицы следующим образом:
```sql
postgres=# ALTER SYSTEM SET ignore_checksum_failure = 'on';
ALTER SYSTEM
postgres=# SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t
(1 строка)

postgres=# show ignore_checksum_failure;
 ignore_checksum_failure
-------------------------
 on
(1 строка)

postgres=# select * from test_tb1 limit 2;
 a
---
 1
 2
(2 строки)
```