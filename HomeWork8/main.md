## Урок 8

### Подготовка инфраструктуры
> Создан кластер PostgresSQL 15 на ВМ 2CPU, 4 RAM, 10GB storage.

### Статус кластера
```bash
dekholud@ubuntu1:~$ systemctl status postgresql@15-main
● postgresql@15-main.service - PostgreSQL Cluster 15-main
     Loaded: loaded (/lib/systemd/system/postgresql@.service; enabled-runtime; vendor preset: enabled)
     Active: active (running) since Sun 2023-08-06 07:38:50 UTC; 48s ago
    Process: 791 ExecStart=/usr/bin/pg_ctlcluster --skip-systemctl-redirect 15-main start (code=exited, status=0/SUCCESS)
   Main PID: 902 (postgres)
      Tasks: 6 (limit: 4609)
     Memory: 40.0M
     CGroup: /system.slice/system-postgresql.slice/postgresql@15-main.service
             ├─ 902 /usr/lib/postgresql/15/bin/postgres -D /var/lib/postgresql/15/main -c config_file=/etc/postgresql/15/main/postgresql.conf
             ├─ 912 postgres: 15/main: checkpointer
             ├─ 913 postgres: 15/main: background writer
             ├─1036 postgres: 15/main: walwriter
             ├─1037 postgres: 15/main: autovacuum launcher
             └─1038 postgres: 15/main: logical replication launcher

авг 06 07:38:41 ubuntu1 systemd[1]: Starting PostgreSQL Cluster 15-main...
авг 06 07:38:42 ubuntu1 postgresql@15-main[791]: Removed stale pid file.
авг 06 07:38:50 ubuntu1 systemd[1]: Started PostgreSQL Cluster 15-main.
```

### Инициализация pgbench
```bash
root@ubuntu1:/home/dekholud# sudo -u postgres pgbench -i postgres
dropping old tables...
ЗАМЕЧАНИЕ:  таблица "pgbench_accounts" не существует, пропускается
ЗАМЕЧАНИЕ:  таблица "pgbench_branches" не существует, пропускается
ЗАМЕЧАНИЕ:  таблица "pgbench_history" не существует, пропускается
ЗАМЕЧАНИЕ:  таблица "pgbench_tellers" не существует, пропускается
creating tables...
generating data (client-side)...
100000 of 100000 tuples (100%) done (elapsed 0.06 s, remaining 0.00 s)
vacuuming...
creating primary keys...
done in 0.25 s (drop tables 0.00 s, create tables 0.01 s, client-side generate 0.10 s, vacuum 0.04 s, primary keys 0.10 s).
```
### Запуск теста производительности с помощью pgbench
```bash
root@ubuntu1:/home/dekholud# sudo -u postgres pgbench -c8 -P 6 -T 60 postgres
pgbench (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
starting vacuum...end.
progress: 6.0 s, 389.7 tps, lat 20.362 ms stddev 18.094, 0 failed
progress: 12.0 s, 388.3 tps, lat 20.550 ms stddev 17.453, 0 failed
progress: 18.0 s, 393.7 tps, lat 20.229 ms stddev 17.241, 0 failed
progress: 24.0 s, 388.5 tps, lat 20.580 ms stddev 17.641, 0 failed
progress: 30.0 s, 393.5 tps, lat 20.283 ms stddev 17.164, 0 failed
progress: 36.0 s, 386.7 tps, lat 20.616 ms stddev 17.805, 0 failed
progress: 42.0 s, 391.0 tps, lat 20.432 ms stddev 17.342, 0 failed
progress: 48.0 s, 390.0 tps, lat 20.470 ms stddev 17.837, 0 failed
progress: 54.0 s, 397.2 tps, lat 20.076 ms stddev 17.482, 0 failed
progress: 60.0 s, 398.7 tps, lat 20.001 ms stddev 17.652, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 1
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 23511
number of failed transactions: 0 (0.000%)
latency average = 20.362 ms
latency stddev = 17.575 ms
initial connection time = 20.156 ms
tps = 391.819458 (without initial connection time)
```
### Меняем параметры кластера

```sql
root@ubuntu1:/etc/postgresql/15/main# sudo -u postgres psql
psql (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
Введите "help", чтобы получить справку.

postgres=# alter system set max_connections = 40;
ALTER SYSTEM
postgres=# alter system set shared_buffers = '1GB';
ALTER SYSTEM
postgres=# alter system set effective_cache_size = '3GB';
ALTER SYSTEM
postgres=# alter system set maintenance_work_mem = '512MB';
ALTER SYSTEM
postgres=# alter system set checkpoint_completion_target = 0.9;
ALTER SYSTEM
postgres=# alter system set wal_buffers = '16MB';
ALTER SYSTEM
postgres=# alter system set default_statistics_target = 500;
ALTER SYSTEM
postgres=# alter system set random_page_cost = 4;
ALTER SYSTEM
postgres=# alter system set effective_io_concurrency = 2;
ALTER SYSTEM
postgres=# alter system set work_mem = '6553kB';
ALTER SYSTEM
postgres=# alter system set min_wal_size = '4GB';
ALTER SYSTEM
postgres=# alter system set max_wal_size = '16GB';
ALTER SYSTEM
postgres=# \q
root@ubuntu1:/etc/postgresql/15/main# systemctl restart postgresql@15-main
```

### Тестируем кластер заново через pgbench

```bash
root@ubuntu1:/etc/postgresql/15/main# sudo -u postgres pgbench -c8 -P 6 -T 60 postgres
pgbench (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
starting vacuum...end.
progress: 6.0 s, 378.7 tps, lat 20.933 ms stddev 18.851, 0 failed
progress: 12.0 s, 390.5 tps, lat 20.423 ms stddev 17.680, 0 failed
progress: 18.0 s, 396.5 tps, lat 20.141 ms stddev 18.319, 0 failed
progress: 24.0 s, 391.7 tps, lat 20.352 ms stddev 18.125, 0 failed
progress: 30.0 s, 393.0 tps, lat 20.296 ms stddev 19.094, 0 failed
progress: 36.0 s, 400.0 tps, lat 19.966 ms stddev 18.525, 0 failed
progress: 42.0 s, 401.4 tps, lat 19.872 ms stddev 17.906, 0 failed
progress: 48.0 s, 400.3 tps, lat 19.933 ms stddev 17.661, 0 failed
progress: 54.0 s, 394.5 tps, lat 20.224 ms stddev 17.476, 0 failed
progress: 60.0 s, 396.2 tps, lat 20.151 ms stddev 17.981, 0 failed
transaction type: <builtin: TPC-B (sort of)>
scaling factor: 1
query mode: simple
number of clients: 8
number of threads: 1
maximum number of tries: 1
duration: 60 s
number of transactions actually processed: 23664
number of failed transactions: 0 (0.000%)
latency average = 20.226 ms
latency stddev = 18.167 ms
initial connection time = 24.849 ms
tps = 394.396358 (without initial connection time)
```
> Каких то серьезных изменений в производительности не наблюдаем. tps стал на 3 транзакции в секунду выше. Предполагаю что тест слишком синтетический и возможно на большем объеме данных и другом тесте мы бы могли получить совсем другой результат.

### Создание таблицы со случайным наполнением

```sql
dekholud@ubuntu1:~$ sudo -u postgres psql
psql (15.2 (Ubuntu 15.2-1.pgdg20.04+1))
Введите "help", чтобы получить справку.

postgres=# create table test_tab as SELECT md5(random()::text) as f FROM generate_series(1,1000000);
SELECT 1000000
postgres=# select pg_size_pretty(pg_table_size('test_tab'));
 pg_size_pretty
----------------
 65 MB
(1 строка)
```
> Фиксируем размер таблицы 65MB до манипуляций.

### Обновление таблицы с включенным avtovacuum
```sql
postgres=# SELECT relname, n_live_tup, n_dead_tup, trunc(100*n_dead_tup/(n_live_tup+1))::float "ratio%", last_autovacuum FROM pg_stat_user_TABLEs WHERE relname = 'test_tab';
 relname  | n_live_tup | n_dead_tup | ratio% | last_autovacuum
----------+------------+------------+--------+-----------------
 test_tab |    1000000 |          0 |      0 |
(1 строка)

postgres=# update test_tab set f=f||'#';
UPDATE 1000000
postgres=# update test_tab set f=f||'#';
UPDATE 1000000
postgres=# update test_tab set f=f||'$';
UPDATE 1000000
postgres=# update test_tab set f=f||'#';
UPDATE 1000000
postgres=# update test_tab set f=f||'$';
UPDATE 1000000
postgres=# SELECT relname, n_live_tup, n_dead_tup, trunc(100*n_dead_tup/(n_live_tup+1))::float "ratio%", last_autovacuum FROM pg_stat_user_TABLEs WHERE relname = 'test_tab';
 relname  | n_live_tup | n_dead_tup | ratio% |        last_autovacuum
----------+------------+------------+--------+-------------------------------
 test_tab |    1000000 |    4999814 |    499 | 2023-08-06 08:19:13.168125+00
(1 строка)

postgres=# update test_tab set f=f||'$';
UPDATE 1000000
postgres=# update test_tab set f=f||'#';
UPDATE 1000000
postgres=# update test_tab set f=f||'$';
UPDATE 1000000
postgres=# update test_tab set f=f||'#';
UPDATE 1000000
postgres=# update test_tab set f=f||'$';
UPDATE 1000000
postgres=# select pg_size_pretty(pg_table_size('test_tab'));
 pg_size_pretty
----------------
 414 MB
(1 строка)

postgres=# SELECT relname, n_live_tup, n_dead_tup, trunc(100*n_dead_tup/(n_live_tup+1))::float "ratio%", last_autovacuum FROM pg_stat_user_TABLEs WHERE relname = 'test_tab';
 relname  | n_live_tup | n_dead_tup | ratio% |        last_autovacuum
----------+------------+------------+--------+-------------------------------
 test_tab |    1010723 |          0 |      0 | 2023-08-06 08:42:30.677301+00
(1 строка)

```

> После апдейтов успел посмотреть состояние до avtovacuum и получить около 5 млн "мертвых" строк. Размер таблицы увеличился до 414 MB.
После же avtovacuum количество "мертвых" строк закономерно стало равным нулю. Активных строк стало чуть больше чем было, что странно.

### Обновление таблицы с выключенным avtovacuum
```sql
postgres=# alter table test_tab set (autovacuum_enabled = off);
ALTER TABLE
postgres=# update test_tab set f=f||'$';
UPDATE 1000000
postgres=# update test_tab set f=f||'#';
UPDATE 1000000
postgres=# update test_tab set f=f||'$';
UPDATE 1000000
postgres=# update test_tab set f=f||'#';
UPDATE 1000000
postgres=# update test_tab set f=f||'$';
UPDATE 1000000
postgres=# update test_tab set f=f||'#';
UPDATE 1000000
postgres=# update test_tab set f=f||'$';
UPDATE 1000000
postgres=# update test_tab set f=f||'#';
UPDATE 1000000
postgres=# update test_tab set f=f||'$';
UPDATE 1000000
postgres=# update test_tab set f=f||'#';
UPDATE 1000000
postgres=# select pg_size_pretty(pg_table_size('test_tab'));
 pg_size_pretty
----------------
 841 MB
(1 строка)

```
### Вывод
> Avtovacuum высвобождает пространство используемое "мертвыми" данными, для повторного использования под этот же объект бд, не отдавая это пространство ОС. Поэтому размер таблицы после vacuum не уменьшается. Для освобождения места на уровне ОС можно использовть vacuum full, тогда postgres пересоздаст таблицу физически только с актуальными строками.
```sql
postgres=# vacuum full test_tab;
VACUUM
postgres=# select pg_size_pretty(pg_table_size('test_tab'));                                                                                           pg_size_pretty
----------------
 81 MB
(1 строка)
```

### Дополнительное задание
```sql
DO
$body$
declare
p_loop_count int = 10;
p_table_name varchar(100) = 'test_tab';
p_field varchar(100) = 'f';
v_sql_stmt text;
i int;
BEGIN
FOR i IN 1..p_loop_count LOOP
RAISE NOTICE 'i = %', i;
v_sql_stmt = 'update ' || p_table_name || ' set ' || p_field || ' = ' || p_field || '||' || quote_literal(i::text);
execute v_sql_stmt;
END LOOP;
END
$body$;
```
