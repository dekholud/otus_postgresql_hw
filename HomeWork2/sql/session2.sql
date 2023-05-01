psql -U postgres
Пароль пользователя postgres:
psql (14.5)
Введите "help", чтобы получить справку.

postgres=# \set AUTOCOMMIT OFF
postgres=# select * from persons;
 id | first_name | second_name
----+------------+-------------
  1 | ivan       | ivanov
  2 | petr       | petrov
(2 строки)


postgres=*# select * from persons;
 id | first_name | second_name
----+------------+-------------
  1 | ivan       | ivanov
  2 | petr       | petrov
  3 | sergey     | sergeev
(3 строки)


postgres=!# commit;
ROLLBACK
postgres=# set transaction isolation level repeatable read;
SET
postgres=*# show transaction isolation level;
 transaction_isolation
-----------------------
 repeatable read
(1 строка)


postgres=*# select * from persons;
 id | first_name | second_name
----+------------+-------------
  1 | ivan       | ivanov
  2 | petr       | petrov
  3 | sergey     | sergeev
(3 строки)


postgres=*# select * from persons;
 id | first_name | second_name
----+------------+-------------
  1 | ivan       | ivanov
  2 | petr       | petrov
  3 | sergey     | sergeev
(3 строки)


postgres=*# rollback;                        
ROLLBACK
postgres=# select * from persons;
 id | first_name | second_name
----+------------+-------------
  1 | ivan       | ivanov
  2 | petr       | petrov
  3 | sergey     | sergeev
  4 | sveta      | svetova
(4 строки)


postgres=*# show transaction isolation level;
 transaction_isolation
-----------------------
 read committed
(1 строка)


postgres=*#