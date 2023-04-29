# Домашние задания по курсу PostgreSQL для администраторов баз данных и разработчиков от Otus

## Урок 2
### __Select с transaction isolation level = read commited до коммита первой сесиии__
> В данном случае вторая сессия не видит в таблице новую запись до фиксации транзакции, т.к уровень изоляции read commited
не подразумевает "грязное" чтение, то есть чтение не зафиксированных изменений.
### __Select с transaction isolation level = read commited после коммита первой сессии__
> В данном случае вторая сессия видит в таблице новую запись после фиксации транзакции, т.к уровень изоляции read commited подразумевает неповторяющееся чтение, то есть один и тот же селект может возвращать разные результаты сессии 2, если сессия 1 внозит изменения в таблицу и фиксирует их через commit.
### __Select с transaction isolation level = repeatable read до коммита первой сессии__
> Ответ аналогичный первому вопросу. Уровень изоляции транзакции repeatable read не подразумевает чтение не зафиксированных изменений.
### __Select с transaction isolation level = repeatable read после коммита первой сессии__
> Результат select у сессии 2 не меняется, т.к. уровень изоляции транзакции repeatable read не подразумевает ни 
non-repeatable read, ни phantom read. То есть в рамках этого уровня изоляции внутри одной транзакции select вернет одинаковый набор значений на всем протяжении транзакции.
### __Select после завершения транзакции второй сесии__
> В данном случае зафиксированная запись первой сесии становится видна второй сессии, т.к. после выхода из транзакции второй сессии уровень изоляции транзакции меняется на дефолтный read committed.

Приложены результаты вывода консоль psql в текстовом виде.

## Урок 3

### Подготовка инфраструктуры
> Создана ВМ с Ubuntu 20.04 через Oracle Virtualbox.
  На ВМ установлены средства docker engine.
  Сеть настроена следующим образом:

![Virtualbox настройки сети](/hw3/virtualbox.png "Virtualbox настройки сети")

### Разворачивание контейнеров
> Ниже привожу блок команд вместе с выводом

```bash
root@ubuntu1:/home/dekholud# mkdir /var/lib/postgres
root@ubuntu1:/home/dekholud# docker network create pg-net
2fdc55350d2859fc75417559ac1e576fc0461bfea8276f54c7ac29bae1129fd8
root@ubuntu1:/home/dekholud# docker run --name pg-server --network pg-net -e POSTGRES_PASSWORD=postgres -d -p 5432:5432 -v /var/lib/postgres:/var/lib/postgresql/data postgres:15
c195ab43df621740ceab2cca4a5ad65b307f8e461ed5164ef1e2ad4bf6450445
root@ubuntu1:/home/dekholud# docker run -dit --network pg-net --name pg-client -e POSTGRES_PASSWORD=postgres postgres:15 bash
20c26b492d6acf0dcfe760c92f093c40c28afa0b4b4d04cd73313cc59526fcfb
root@ubuntu1:/home/dekholud# docker ps -a
CONTAINER ID   IMAGE         COMMAND                  CREATED          STATUS          PORTS                                       NAMES
20c26b492d6a   postgres:15   "docker-entrypoint.s…"   7 seconds ago    Up 5 seconds    5432/tcp                                    pg-client
c195ab43df62   postgres:15   "docker-entrypoint.s…"   31 seconds ago   Up 29 seconds   0.0.0.0:5432->5432/tcp, :::5432->5432/tcp   pg-server
```
### Подключение, наполнение
> Ниже привожу блок команд вместе с выводом

```sql
root@ubuntu1:/home/dekholud# docker exec -it pg-client psql -h pg-server -U postgres
Password for user postgres:
psql (15.2 (Debian 15.2-1.pgdg110+1))
Type "help" for help.

postgres=# CREATE DATABASE test_db;
CREATE DATABASE
postgres=# \c test_db
You are now connected to database "test_db" as user "postgres".
test_db=# \l+
                                                                                  List of databases
   Name    |  Owner   | Encoding |  Collate   |   Ctype    | ICU Locale | Locale Provider |   Access privileges   |  Size   | Tablespace |
    Description
-----------+----------+----------+------------+------------+------------+-----------------+-----------------------+---------+------------+------------
--------------------------------
 postgres  | postgres | UTF8     | en_US.utf8 | en_US.utf8 |            | libc            |                       | 7453 kB | pg_default | default adm
inistrative connection database
 template0 | postgres | UTF8     | en_US.utf8 | en_US.utf8 |            | libc            | =c/postgres          +| 7297 kB | pg_default | unmodifiabl
e empty database
           |          |          |            |            |            |                 | postgres=CTc/postgres |         |            |
 template1 | postgres | UTF8     | en_US.utf8 | en_US.utf8 |            | libc            | =c/postgres          +| 7369 kB | pg_default | default tem
plate for new databases
           |          |          |            |            |            |                 | postgres=CTc/postgres |         |            |
 test_db   | postgres | UTF8     | en_US.utf8 | en_US.utf8 |            | libc            |                       | 7525 kB | pg_default |
(4 rows)

test_db=# CREATE SCHEMA test_schema;
CREATE SCHEMA
test_db=# CREATE TABLE test_schema.test_table (id int, text_f varchar(50));
CREATE TABLE
test_db=# INSERT INTO test_schema.test_table (id, text_f) VALUES (1, 'Cheese'), (2, 'Bread'), (3, 'Milk');
INSERT 0 3
test_db=# select count(1) from test_schema.test_table;
 count
-------
     3
(1 row)

test_db=#
```
### Подключение извне
> Привожу скриншоты из dbeaver

![Настройки подключения](/hw3/connect.png "Настройки подключения")

![Запрос к таблице](/hw3/dbeaver.png "Запрос к таблице")

### Пересоздание контейнера с сервером бд
> Ниже привожу блок команд вместе с выводом

```bash
root@ubuntu1:/home/dekholud# docker ps -a
CONTAINER ID   IMAGE         COMMAND                  CREATED       STATUS       PORTS                                       NAMES
20c26b492d6a   postgres:15   "docker-entrypoint.s…"   2 hours ago   Up 2 hours   5432/tcp                                    pg-client
c195ab43df62   postgres:15   "docker-entrypoint.s…"   2 hours ago   Up 2 hours   0.0.0.0:5432->5432/tcp, :::5432->5432/tcp   pg-server
root@ubuntu1:/home/dekholud# docker rm -f pg-server
pg-server
root@ubuntu1:/home/dekholud# docker ps -a
CONTAINER ID   IMAGE         COMMAND                  CREATED       STATUS       PORTS      NAMES
20c26b492d6a   postgres:15   "docker-entrypoint.s…"   2 hours ago   Up 2 hours   5432/tcp   pg-client
root@ubuntu1:/home/dekholud# docker run --name pg-server --network pg-net -e POSTGRES_PASSWORD=postgres -d -p 5432:5432 -v /var/lib/postgres:/var/lib/postgresql/data postgres:15
cc732ffe0c239b467d3a9294b006312268d5b165c59b41821080b14ef27c1d32
root@ubuntu1:/home/dekholud# docker ps -a
CONTAINER ID   IMAGE         COMMAND                  CREATED         STATUS         PORTS                                       NAMES
cc732ffe0c23   postgres:15   "docker-entrypoint.s…"   4 seconds ago   Up 2 seconds   0.0.0.0:5432->5432/tcp, :::5432->5432/tcp   pg-server
20c26b492d6a   postgres:15   "docker-entrypoint.s…"   2 hours ago     Up 2 hours     5432/tcp                                    pg-client
root@ubuntu1:/home/dekholud# docker exec -it pg-client psql -h pg-server -U postgres
Password for user postgres:
psql (15.2 (Debian 15.2-1.pgdg110+1))
Type "help" for help.

postgres=# \c test_db
You are now connected to database "test_db" as user "postgres".
test_db=# select count(1) from test_schema.test_table;
 count
-------
     3
(1 row)

test_db=#
```