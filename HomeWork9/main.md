## Урок 9

### Настройка логирования блокировок
> Включаем логирование и выставляем timeout deadlock.
```sql
postgres=# alter system set log_lock_waits=on;
ALTER SYSTEM
postgres=# alter system set deadlock_timeout=200;
ALTER SYSTEM
postgres=# select pg_reload_conf();
 pg_reload_conf
----------------
 t
(1 строка)

```
#### Выгрузка из лога
>2023-08-06 18:13:02.300 UTC [53726] postgres@postgres СООБЩЕНИЕ:  процесс 53726 продолжает ожидать в режиме ExclusiveLock блокировку "кортеж (0,3) отношения 24650 базы данных 5" в течение 200.983 мс
2023-08-06 18:13:02.300 UTC [53726] postgres@postgres ПОДРОБНОСТИ:  Process holding the lock: 53724. Wait queue: 53726.
2023-08-06 18:13:02.300 UTC [53726] postgres@postgres ОПЕРАТОР:  UPDATE lock_table
        SET a = a - 1
        WHERE b = 'c'

### Update строки с блокировкой в 3х сессиях

> Сессия 1
```sql
BEGIN;
SELECT txid_current(), pg_backend_pid(); -- 1750827	6568
UPDATE lock_table 
SET a = a + 3
WHERE b = 'c';
```
> Сессия 2
```sql
BEGIN;
SELECT txid_current(), pg_backend_pid(); -- 1750828	6569
UPDATE lock_table 
SET a = a + 6
WHERE b = 'c';
```
> Сессия 3
```sql
BEGIN;
SELECT txid_current(), pg_backend_pid(); -- 1750829	6570
UPDATE lock_table 
SET a = a - 1
WHERE b = 'c';
```
> Список блокировок

```sql
postgres=# select locktype, relation::REGCLASS, virtualxid, transactionid, virtualtransaction, mode, granted, pid
postgres-# FROM pg_locks
postgres-# where pid in (6568, 6569, 6570)
postgres-# order by pid, locktype;
   locktype    |  relation  | virtualxid | transactionid | virtualtransaction |       mode       | granted | pid
---------------+------------+------------+---------------+--------------------+------------------+---------+------
 relation      | lock_table |            |               | 5/159              | RowExclusiveLock | t       | 6568
 transactionid |            |            |       1750827 | 5/159              | ExclusiveLock    | t       | 6568
 virtualxid    |            | 5/159      |               | 5/159              | ExclusiveLock    | t       | 6568
 relation      | lock_table |            |               | 6/44658            | RowExclusiveLock | t       | 6569
 transactionid |            |            |       1750827 | 6/44658            | ShareLock        | f       | 6569
 transactionid |            |            |       1750828 | 6/44658            | ExclusiveLock    | t       | 6569
 tuple         | lock_table |            |               | 6/44658            | ExclusiveLock    | t       | 6569
 virtualxid    |            | 6/44658    |               | 6/44658            | ExclusiveLock    | t       | 6569
 relation      | lock_table |            |               | 7/43228            | RowExclusiveLock | t       | 6570
 transactionid |            |            |       1750829 | 7/43228            | ExclusiveLock    | t       | 6570
 tuple         | lock_table |            |               | 7/43228            | ExclusiveLock    | f       | 6570
 virtualxid    |            | 7/43228    |               | 7/43228            | ExclusiveLock    | t       | 6570
(12 строк)

```

#### 1 сессия pid = 6568

> Фактически уже на моменте select-а SELECT txid_current(), pg_backend_pid(); 
образуется ExclusiveLock исключительная блокировка настоящего номера транзакции transactionid=1750827, а также ExclusiveLock на виртуальном идентификаторе транзакции virtualxid=5/159.
При попытке операции update под этой же виртуальной транзакцией возникает блокировка отношения lock_table уровня RowExclusiveLock.

#### 2 сессия pid = 6569

> Ведет себя аналогично первой сесси на моменте селекта начиная транзакцию как фактическую так и виртуальную.Но есть отличия
в момент update:
- создает блокировку уровня ExclusiveLock на изменяемый tuple,
- создает блокировку уровня ShareLock на транзакции transactionid=1750827, но ей это не удается  сделать из за сессии 1 (granted = false)

#### 3 сессия pid=6570
> Ведет себя аналогично второй сессии, но в момент update
- создает блокировку уровня ExclusiveLock на tuple и у нас это не получается из за блокировки второй сессии (granted = false)

### Взаимоблокировка
```sql
-- Сессия 1
UPDATE lock_table 
SET a = a - 1
WHERE b = 'a';
-- Сессия 2
UPDATE lock_table 
SET a = a + 1
WHERE b = 'b';
-- Сессия 3
UPDATE lock_table 
SET a = a + 1
WHERE b = 'c';
-- Сессия 1
UPDATE lock_table 
SET a = a - 1
WHERE b = 'c';
-- Сессия 2
UPDATE lock_table 
SET a = a + 1
WHERE b = 'a';
-- Сессия 3
UPDATE lock_table 
SET a = a + 1
WHERE b = 'b';
```
> По логу теоретически можно разобраться, что именно произошло. Но вероятно это будет трудоемко.

```
2023-08-22 22:00:23.943 UTC [6568] postgres@postgres СООБЩЕНИЕ:  процесс 6568 продолжает ожидать в режиме ShareLock блокировку "транзакция 1750830" в течение 201.132 мс
2023-08-22 22:00:23.943 UTC [6568] postgres@postgres ПОДРОБНОСТИ:  Process holding the lock: 6570. Wait queue: 6568.
2023-08-22 22:00:23.943 UTC [6568] postgres@postgres КОНТЕКСТ:  при изменении кортежа (0,1) в отношении "lock_table"
2023-08-22 22:00:23.943 UTC [6568] postgres@postgres ОПЕРАТОР:  UPDATE lock_table
        SET a = a + 1
        WHERE b = 'a'
2023-08-22 22:00:29.641 UTC [908] СООБЩЕНИЕ:  начата контрольная точка: time
2023-08-22 22:00:29.752 UTC [6569] postgres@postgres СООБЩЕНИЕ:  процесс 6569 обнаружил взаимоблокировку, ожидая в режиме ShareLock блокировку "транзакция 1750831" в течение 200.935 мс
2023-08-22 22:00:29.752 UTC [6569] postgres@postgres ПОДРОБНОСТИ:  Process holding the lock: 6568. Wait queue: .
2023-08-22 22:00:29.752 UTC [6569] postgres@postgres КОНТЕКСТ:  при изменении кортежа (0,2) в отношении "lock_table"
2023-08-22 22:00:29.752 UTC [6569] postgres@postgres ОПЕРАТОР:  UPDATE lock_table
        SET a = a + 1
        WHERE b = 'b'
2023-08-22 22:00:29.753 UTC [6569] postgres@postgres ОШИБКА:  обнаружена взаимоблокировка
2023-08-22 22:00:29.753 UTC [6569] postgres@postgres ПОДРОБНОСТИ:  Процесс 6569 ожидает в режиме ShareLock блокировку "транзакция 1750831"; заблокирован процессом 6568.
        Процесс 6568 ожидает в режиме ShareLock блокировку "транзакция 1750830"; заблокирован процессом 6570.
        Процесс 6570 ожидает в режиме ShareLock блокировку "транзакция 1750832"; заблокирован процессом 6569.
        Процесс 6569: UPDATE lock_table
        SET a = a + 1
        WHERE b = 'b'
        Процесс 6568: UPDATE lock_table
        SET a = a + 1
        WHERE b = 'a'
        Процесс 6570: UPDATE lock_table
        SET a = a - 1
        WHERE b = 'c'

2023-08-22 22:00:29.753 UTC [6569] postgres@postgres ПОДСКАЗКА:  Подробности запроса смотрите в протоколе сервера.
2023-08-22 22:00:29.753 UTC [6569] postgres@postgres КОНТЕКСТ:  при изменении кортежа (0,2) в отношении "lock_table"
2023-08-22 22:00:29.753 UTC [6569] postgres@postgres ОПЕРАТОР:  UPDATE lock_table
        SET a = a + 1
        WHERE b = 'b'
2023-08-22 22:00:29.755 UTC [6570] postgres@postgres СООБЩЕНИЕ:  процесс 6570 получил в режиме ShareLock блокировку "транзакция 1750832" через 14387.408 мс
2023-08-22 22:00:29.755 UTC [6570] postgres@postgres КОНТЕКСТ:  при изменении кортежа (0,3) в отношении "lock_table"
2023-08-22 22:00:29.755 UTC [6570] postgres@postgres ОПЕРАТОР:  UPDATE lock_table
        SET a = a - 1
        WHERE b = 'c'

```
### Блокировка транзакций с update без where
> Могут ли две транзакции, выполняющие единственную команду UPDATE одной и той же таблицы (без where), заблокировать друг друга?

> Вероятно это возможно если 2 сессии делают update по таблице но с разной сортировкой этой самой таблицы. Если смотреть синтаксис команды update, то вероятно для воспроизведения такой ситуации мы должны либо использовать вложенный select на саму эту таблицу с разной сортировкой, либо должны использовать в SET = "выражение", такое выражение, которое заставило бы оптимизатор в разном порядке идти по таблице.
Живой пример к сожалению не получилось подобрать, постгрес успешно справлялся с моими попытками.
