## Урок 12

### Установка кластера
> Postgres 15 уже установлен. Просто добавил новый кластер по порту 5433.
```sql
dekholud@ubuntu1:~$ sudo -u postgres psql -p 5433
psql (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
Введите "help", чтобы получить справку.

postgres=# create database db_1;
CREATE DATABASE
postgres=# \l
                                                  Список баз данных
    Имя    | Владелец | Кодировка | LC_COLLATE  |  LC_CTYPE   | локаль ICU | Провайдер локали |     Права доступа
-----------+----------+-----------+-------------+-------------+------------+------------------+-----------------------
 db_1      | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 |            | libc             |
 postgres  | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 |            | libc             |
 template0 | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 |            | libc             | =c/postgres          +
           |          |           |             |             |            |                  | postgres=CTc/postgres
 template1 | postgres | UTF8      | ru_RU.UTF-8 | ru_RU.UTF-8 |            | libc             | =c/postgres          +
           |          |           |             |             |            |                  | postgres=CTc/postgres
(4 строки)


```

### Нагрузка на дефолтную бд
> Нагружаем бд до изменения параметров
```bash
dekholud@ubuntu1:~$ sudo -u postgres pgbench -p 5433 -i db_1
dropping old tables...
ЗАМЕЧАНИЕ:  таблица "pgbench_accounts" не существует, пропускается
ЗАМЕЧАНИЕ:  таблица "pgbench_branches" не существует, пропускается
ЗАМЕЧАНИЕ:  таблица "pgbench_history" не существует, пропускается
ЗАМЕЧАНИЕ:  таблица "pgbench_tellers" не существует, пропускается
creating tables...
generating data (client-side)...
100000 of 100000 tuples (100%) done (elapsed 0.31 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 0.55 s (drop tables 0.00 s, create tables 0.01 s, client-side generate 0.35 s, vacuum 0.12 s, primary keys 0.07 s).
dekholud@ubuntu1:~$ sudo -u postgres pgbench -p 5433 --client=20 --connect --jobs=5 --progress=30 --time=300 db_1
pgbench (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
starting vacuum...end.
progress: 30.0 s, 204.5 tps, lat 90.183 ms stddev 64.080, 0 failed
progress: 60.0 s, 180.0 tps, lat 102.003 ms stddev 76.260, 0 failed
progress: 90.0 s, 199.1 tps, lat 92.696 ms stddev 66.355, 0 failed
progress: 120.0 s, 200.1 tps, lat 92.141 ms stddev 64.694, 0 failed
progress: 150.0 s, 200.3 tps, lat 92.113 ms stddev 63.379, 0 failed
progress: 180.0 s, 199.0 tps, lat 92.813 ms stddev 69.295, 0 failed
progress: 210.0 s, 205.2 tps, lat 90.083 ms stddev 63.910, 0 failed
progress: 240.0 s, 203.5 tps, lat 90.887 ms stddev 64.560, 0 failed
progress: 270.0 s, 199.3 tps, lat 92.613 ms stddev 65.735, 0 failed
progress: 300.0 s, 202.8 tps, lat 91.107 ms stddev 66.224, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 20
number of threads: 5
maximum number of tries: 1
duration: 300 s
number of transactions actually processed: 59837
number of failed transactions: 0 (0.000%)
latency average = 92.550 ms
latency stddev = 66.494 ms
average connection time = 7.728 ms
tps = 199.414525 (including reconnection times)

```
### Нагрузка на бд с измененными параметрами
> На 1м этапе проведем наименее влияющие на мой взгляд параметры разбив их на группы.
И затем сделаем замер. Помним что надежность кластера нам не интересна в данном случае.

> Логирование, отслеживание активности
```sql
postgres=# ALTER SYSTEM SET track_activities = 'off';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET track_counts = 'off';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET log_min_error_statement = 'fatal';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET log_min_messages = 'fatal';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET log_error_verbosity = 'terse';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET log_checkpoints = 'off';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET log_startup_progress_interval = '0';
ALTER SYSTEM
```
> SSL, количество подключений
```sql
postgres=# ALTER SYSTEM SET ssl = 'off';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET max_connections = '30';
ALTER SYSTEM
```
> Vacuum
```sql
postgres=# ALTER SYSTEM SET autovacuum = 'off';
ALTER SYSTEM
```
> Планировщик
```sql
postgres=# ALTER SYSTEM SET geqo = 'off';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET default_statistics_target = '150';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET random_page_cost = '1.1';
ALTER SYSTEM
```
> pgtune предлагал выставить default_statistics_target = 100, но кажется что нам нужна точность чуть выше стандартной для оптимальных планов запросов.

> Перезагружаем кластер и пробуем тестировать повторно

```bash
dekholud@ubuntu1:~$ sudo -u postgres pgbench -p 5433 --client=20 --connect --jobs=5 --progress=30 --time=300 db_1
pgbench (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
starting vacuum...end.
progress: 30.0 s, 214.5 tps, lat 85.737 ms stddev 62.998, 0 failed
progress: 60.0 s, 208.4 tps, lat 88.291 ms stddev 66.956, 0 failed
progress: 90.0 s, 200.4 tps, lat 91.651 ms stddev 70.273, 0 failed
progress: 120.0 s, 203.9 tps, lat 90.181 ms stddev 67.097, 0 failed
progress: 150.0 s, 207.3 tps, lat 88.848 ms stddev 65.177, 0 failed
progress: 180.0 s, 208.5 tps, lat 88.224 ms stddev 63.157, 0 failed
progress: 210.0 s, 200.5 tps, lat 91.661 ms stddev 69.080, 0 failed
progress: 240.0 s, 209.2 tps, lat 88.046 ms stddev 66.611, 0 failed
progress: 270.0 s, 203.9 tps, lat 90.128 ms stddev 66.629, 0 failed
progress: 300.0 s, 208.3 tps, lat 88.275 ms stddev 65.798, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 20
number of threads: 5
maximum number of tries: 1
duration: 300 s
number of transactions actually processed: 61967
number of failed transactions: 0 (0.000%)
latency average = 89.074 ms
latency stddev = 66.400 ms
average connection time = 7.758 ms
tps = 206.514238 (including reconnection times)

```
> Глобально получили практически то же самое, средний tps выше всего на 7 транзакций в секунду.

> На 2м этапе конфигурируем настройки WAL и сброс на диск.

> WAL
```sql
postgres=# ALTER SYSTEM SET wal_level='minimal';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET max_wal_senders='0';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET min_wal_size = '1GB';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET max_wal_size = '4GB';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET full_page_writes='off';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET checkpoint_completion_target = '0.9';
ALTER SYSTEM
```
> Сброс на диск
```sql
postgres=# ALTER SYSTEM SET synchronous_commit = 'off';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET fsync = 'off';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET effective_io_concurrency = '200';
ALTER SYSTEM
```
> Перезагружаем кластер и пробуем тестировать повторно

```bash
dekholud@ubuntu1:~$ sudo -u postgres pgbench -p 5433 --client=20 --connect --jobs=5 --progress=30 --time=300 db_1
pgbench (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
starting vacuum...end.
progress: 30.0 s, 258.3 tps, lat 68.130 ms stddev 39.551, 0 failed
progress: 60.0 s, 263.3 tps, lat 66.878 ms stddev 39.487, 0 failed
progress: 90.0 s, 268.0 tps, lat 65.703 ms stddev 38.807, 0 failed
progress: 120.0 s, 275.0 tps, lat 63.893 ms stddev 37.058, 0 failed
progress: 150.0 s, 267.6 tps, lat 65.728 ms stddev 36.814, 0 failed
progress: 180.0 s, 268.7 tps, lat 65.480 ms stddev 36.818, 0 failed
progress: 210.0 s, 268.9 tps, lat 65.516 ms stddev 36.738, 0 failed
progress: 240.0 s, 276.7 tps, lat 63.635 ms stddev 34.979, 0 failed
progress: 270.0 s, 274.1 tps, lat 64.299 ms stddev 36.633, 0 failed
progress: 300.0 s, 273.7 tps, lat 64.322 ms stddev 36.156, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 20
number of threads: 5
maximum number of tries: 1
duration: 300 s
number of transactions actually processed: 80846
number of failed transactions: 0 (0.000%)
latency average = 65.331 ms
latency stddev = 37.329 ms
average connection time = 8.885 ms
tps = 269.450682 (including reconnection times)

```
> Видим уже существенный прирост tps до 269.

> На 3м этапе конфигурируем настройки памяти
```sql
postgres=# ALTER SYSTEM SET shared_buffers = '1GB';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET effective_cache_size = '3GB';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET maintenance_work_mem = '256MB';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET work_mem = '13107kB';
ALTER SYSTEM
```
> Перезагружаем кластер и пробуем тестировать повторно
```bash
dekholud@ubuntu1:~$ sudo -u postgres pgbench -p 5433 --client=20 --connect --jobs=5 --progress=30 --time=300 db_1
pgbench (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
starting vacuum...end.
progress: 30.0 s, 267.9 tps, lat 65.688 ms stddev 36.254, 0 failed
progress: 60.0 s, 271.3 tps, lat 64.883 ms stddev 36.113, 0 failed
progress: 90.0 s, 268.9 tps, lat 65.514 ms stddev 36.976, 0 failed
progress: 120.0 s, 263.7 tps, lat 66.795 ms stddev 55.232, 0 failed
progress: 150.0 s, 267.9 tps, lat 65.723 ms stddev 36.578, 0 failed
progress: 180.0 s, 270.0 tps, lat 65.073 ms stddev 35.911, 0 failed
progress: 210.0 s, 267.4 tps, lat 65.874 ms stddev 37.410, 0 failed
progress: 240.0 s, 268.5 tps, lat 65.663 ms stddev 38.443, 0 failed
progress: 270.0 s, 265.6 tps, lat 66.237 ms stddev 37.325, 0 failed
progress: 300.0 s, 267.4 tps, lat 65.844 ms stddev 37.308, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 20
number of threads: 5
maximum number of tries: 1
duration: 300 s
number of transactions actually processed: 80378
number of failed transactions: 0 (0.000%)
latency average = 65.723 ms
latency stddev = 39.115 ms
average connection time = 8.925 ms
tps = 267.897323 (including reconnection times)

```

> Большие надежды возлагал на synchronous_commit - и тут кажется это сработало tps вырос, однако не так существенно как я ожидал. Также большие надежды возлагал на размеры work_mem и shared_buffers, но тут чуда не случилось и tps не вырос. Если мониторить нагрузку, то видно что в указанной конфигурации упираемся в железо. CPU используется под 100, а RAM около 80%, запись на диск достаточно неторопливая и диск вполне себе справляется.
