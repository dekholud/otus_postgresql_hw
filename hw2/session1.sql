psql -U postgres
Пароль пользователя postgres:
psql (14.5)
Введите "help", чтобы получить справку.

postgres=# \set AUTOCOMMIT OFF
postgres=# create table persons(id serial, first_name text, second_name text);
CREATE TABLE
postgres=*# insert into persons(first_name, second_name) values('ivan', 'ivanov');
INSERT 0 1
postgres=*# insert into persons(first_name, second_name) values('petr', 'petrov');
INSERT 0 1
postgres=*# commit;
COMMIT
postgres=# show transaction isolation level;
 transaction_isolation
-----------------------
 read committed
(1 строка)


postgres=*# insert into persons(first_name, second_name) values('sergey', 'sergeev');
INSERT 0 1
postgres=*# commit;
COMMIT
postgres=# set transaction isolation level repeatable read;
SET
postgres=*# show transaction isolation level;
 transaction_isolation
-----------------------
 repeatable read
(1 строка)


postgres=*# insert into persons(first_name, second_name) values('sveta', 'svetova');
INSERT 0 1
postgres=*# commit;
COMMIT
postgres=#