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