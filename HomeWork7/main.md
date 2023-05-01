## Урок 7

### Подготовка инфраструктуры
> Создан кластер PostgresSQL 14 в Docker контейнере

### Создание схемы, таблицы, роли, пользователя
> Ниже привожу блок команд. 
Можно заметить, что вначале я создал таблицу в public, а затем через alter сменил схему.

```sql
root@ubuntu1:~# docker exec -it pg-client2 psql -h pg-server2 -U postgres
Password for user postgres:
psql (14.7 (Debian 14.7-1.pgdg110+1))
Type "help" for help.

postgres=# CREATE DATABASE testdb;
CREATE DATABASE
postgres=# \c te
template0  template1  testdb
postgres=# \c testdb;
You are now connected to database "testdb" as user "postgres".
testdb=# CREATE SCHEMA testnm;
CREATE SCHEMA
testdb=# CREATE TABLE t1(c1 integer);
CREATE TABLE
testdb=# INSERT INTO t1 values(1);
INSERT 0 1
testdb=# select * from pg_tables where table
tablename   tableowner  tablespace
testdb=# select * from pg_tables where tablename = 't1';
 schemaname | tablename | tableowner | tablespace | hasindexes | hasrules | hastriggers | rowsecurity
------------+-----------+------------+------------+------------+----------+-------------+-------------
 public     | t1        | postgres   |            | f          | f        | f           | f
(1 row)

testdb=# ALTER TABLE t1 set schema testnm;
ALTER TABLE
testdb=# select * from pg_tables where tablename = 't1';
 schemaname | tablename | tableowner | tablespace | hasindexes | hasrules | hastriggers | rowsecurity
------------+-----------+------------+------------+------------+----------+-------------+-------------
 testnm     | t1        | postgres   |            | f          | f        | f           | f
(1 row)

testdb=# CREATE ROLE readonly;
CREATE ROLE
testdb=# grant connect on DATABASE testdb TO readonly;
GRANT
testdb=# grant usage on SCHEMA testnm to readonly;
GRANT
testdb=# grant select on all tables in SCHEMA testnm TO readonly;
GRANT
testdb=# create user testread with password 'test123';
CREATE ROLE
testdb=# grant readonly to testread;
GRANT ROLE
```
### Запрос к созданной таблице через нового пользователя

> Было понимание, что в search_path не будет нашей схемы testnm, а он будет равен "$user", public
поэтому запрос без указания схемы закономерно свалился, т.к. таблицу я уже перенес. Запрос же с указанием схемы отлично отработал.
```sql
testdb=# \c testdb testread;
Password for user testread:
You are now connected to database "testdb" as user "testread".
testdb=> select * from testnm.t1;
 c1
----
  1
(1 row)

testdb=> select * from t1;
ERROR:  relation "t1" does not exist
LINE 1: select * from t1;
```
### Пересоздание таблицы и default privelegies

> Понимание, что ALTER default privileges не затрагивает старые объекты было, а также было понимание, что пересоздание таблицы через drop - это уже новый объект бд и наш грант будет потерян.

```sql
testdb=> \c testdb postgres
Password for user postgres:
You are now connected to database "testdb" as user "postgres".
testdb=# drop TABLE t1;
ERROR:  table "t1" does not exist
testdb=# drop TABLE testnm.t1;
DROP TABLE
testdb=# CREATE TABLE testnm.t1(c1 integer);
CREATE TABLE
testdb=# INSERT INTO testnm.t1 values(1);
INSERT 0 1
testdb=# \c testdb testread
Password for user testread:
You are now connected to database "testdb" as user "testread".
testdb=> select * from testnm.t1;
ERROR:  permission denied for table t1
testdb=> \c testdb postgres
Password for user postgres:
You are now connected to database "testdb" as user "postgres".
testdb=# ALTER default privileges in SCHEMA testnm grant SELECT on TABLES to readonly;
ALTER DEFAULT PRIVILEGES
testdb=# grant select on testnm.t1 to readonly;
GRANT
testdb=# \c testdb testread
Password for user testread:
You are now connected to database "testdb" as user "testread".
testdb=> select * from testnm.t1;
 c1
----
  1
(1 row)

```
### Create и insert из под тестового пользователя

> Т.к. search_path мы так и не меняли по ходу выполнения д.з, то закономерно что и isnert и create попытались выполниться на схеме public. 

По умолчанию пользователи создаются с ролью public, которая позволяет на схеме public как создавать объекты, так и наполнять таблицы. Поэтому наши команды выполнились на схеме public беспрепятственно

```sql
testdb=# \c testdb testread
Password for user testread:
You are now connected to database "testdb" as user "testread".
testdb=> create table t2(c1 integer);
CREATE TABLE
testdb=> insert into t2 values (2);
INSERT 0 1
```

> Отбираем у роли public права на схеме public, оставляем лишь право на select.
```sql
testdb=> \c testdb postgres;
Password for user postgres:
You are now connected to database "testdb" as user "postgres".
testdb=# revoke CREATE on SCHEMA public FROM public;
REVOKE
testdb=# revoke all on DATABASE testdb FROM public;
REVOKE
testdb=# grant select on all tables in SCHEMA public TO public;
GRANT
```

> Ну и после этого, запрос на создание на схеме public падает c недостатоком прав

```sql
testdb=# \c testdb testread
Password for user testread:
You are now connected to database "testdb" as user "testread".
testdb=> create table t3(c1 integer);
ERROR:  permission denied for schema public
LINE 1: create table t3(c1 integer);
```
> Однако insert проходит по причине того, что наш пользователь является owner-ом объекта и роль public в данном случае не важна.
```sql
testdb=> insert into t2 values (2);
INSERT 0 1
testdb=> select * from pg_tables where tablename = 't2';
 schemaname | tablename | tableowner | tablespace | hasindexes | hasrules | hastriggers | rowsecurity
------------+-----------+------------+------------+------------+----------+-------------+-------------
 public     | t2        | testread   |            | f          | f        | f           | f
(1 row)

```
