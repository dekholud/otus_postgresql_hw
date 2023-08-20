## Урок 18

### Подготовка таблицы
> Создаем таблицу и наполняем данными
```sql
CREATE TABLE index_test
(
    id    integer GENERATED ALWAYS AS IDENTITY,
    name  varchar(200),
    creation_date  timestamp DEFAULT now(),
    account_id bigint
);

insert into index_test (name, account_id)
select md5(random()::text), (random() * 100)::int
from generate_series(1, 300000);
```

### Создание индексов и планы запросов
> Создаем b-tree индекс

```sql
create index index_test_1ix on index_test(account_id);

explain analyze
select * from index_test it where account_id between 30 and 60;

Bitmap Heap Scan on index_test it  (cost=1282.41..5771.49 rows=93072 width=53) (actual time=7.791..21.750 rows=93091 loops=1)
  Recheck Cond: ((account_id >= 30) AND (account_id <= 60))
  Heap Blocks: exact=3093
  ->  Bitmap Index Scan on index_test_1ix  (cost=0.00..1259.14 rows=93072 width=0) (actual time=7.487..7.488 rows=93091 loops=1)
        Index Cond: ((account_id >= 30) AND (account_id <= 60))
Planning Time: 0.640 ms
Execution Time: 24.634 ms
```

> Создаем GIN индекс для полнотекстового поиска

```sql
alter table index_test add column name_tsv tsvector;
update index_test set name_tsv=to_tsvector(name);
create index index_test_2ix on index_test using gin(name_tsv) with (fastupdate = true);

explain analyze
select * from index_test it
where it.name_tsv @@ to_tsquery('1e06'); 
Bitmap Heap Scan on index_test it  (cost=20.33..61.89 rows=10 width=98) (actual time=0.022..0.029 rows=4 loops=1)
  Recheck Cond: (name_tsv @@ to_tsquery('1e06'::text))
  Heap Blocks: exact=4
  ->  Bitmap Index Scan on index_test_2ix  (cost=0.00..20.33 rows=10 width=0) (actual time=0.016..0.017 rows=4 loops=1)
        Index Cond: (name_tsv @@ to_tsquery('1e06'::text))
Planning Time: 0.107 ms
Execution Time: 0.045 ms
```

> Создаем B-tree индекс для части таблицы
```sql
CREATE INDEX index_test_3ix ON index_test (id)
    WHERE id > 30;

explain analyze
select * from index_test it
where it.id = 41;

Index Scan using index_test_3ix on index_test it  (cost=0.42..8.44 rows=1 width=98) (actual time=0.070..0.071 rows=1 loops=1)
  Index Cond: (id = 41)
Planning Time: 0.704 ms
Execution Time: 0.084 ms

explain analyze
select * from index_test it
where it.id = 22;

Gather  (cost=1000.00..10573.60 rows=1 width=98) (actual time=0.362..19.666 rows=1 loops=1)
  Workers Planned: 2
  Workers Launched: 2
  ->  Parallel Seq Scan on index_test it  (cost=0.00..9573.50 rows=1 width=98) (actual time=3.290..7.974 rows=0 loops=3)
        Filter: (id = 22)
        Rows Removed by Filter: 100000
Planning Time: 0.093 ms
Execution Time: 19.692 ms
```
> Как видим это работает и план для первого запроса используем наш индекс, а для второго запроса - нет.

> Создадим индекс на несколько полей таблицы

```sql
CREATE INDEX index_test_4ix ON index_test (id,account_id);


explain analyze
select * from index_test it
where it.id = 4
and it.account_id >= 62;

Index Scan using index_test_4ix on index_test it  (cost=0.42..8.44 rows=1 width=98) (actual time=0.010..0.010 rows=0 loops=1)
  Index Cond: ((id = 4) AND (account_id >= 62))
Planning Time: 0.131 ms
Execution Time: 0.021 ms
```

### Соединения таблиц
> Для работы будем использовать следующие структуры таблиц
```sql
CREATE TABLE bookings.flights (
	flight_id serial4 NOT NULL,
	flight_no bpchar(6) NOT NULL,
	scheduled_departure timestamptz NOT NULL,
	scheduled_arrival timestamptz NOT NULL,
	departure_airport bpchar(3) NOT NULL,
	arrival_airport bpchar(3) NOT NULL,
	status varchar(20) NOT NULL,
	aircraft_code bpchar(3) NOT NULL,
	actual_departure timestamptz NULL,
	actual_arrival timestamptz NULL
);
CREATE TABLE bookings.airports_data (
	airport_code bpchar(3) NOT NULL,
	airport_name jsonb NOT NULL,
	city jsonb NOT NULL,
	coordinates point NOT NULL,
	timezone text NOT NULL,
	CONSTRAINT airports_data_pkey PRIMARY KEY (airport_code)
);
CREATE TABLE bookings.ticket_flights (
	ticket_no bpchar(13) NOT NULL,
	flight_id int4 NOT NULL,
	fare_conditions varchar(10) NOT NULL,
	amount numeric(10, 2) NOT NULL
);
CREATE TABLE bookings.boarding_passes (
	ticket_no bpchar(13) NOT NULL,
	flight_id int4 NOT NULL,
	boarding_no int4 NOT NULL,
	seat_no varchar(4) NOT NULL,

);

```
> Прямое соединение таблиц
```sql
select flight_no, scheduled_departure, scheduled_arrival,
	a.airport_name ->> lang() as arrival_airport, b.airport_name ->> lang() as departure_airport
from flights f
join airports_data a
on a.airport_code = f.arrival_airport 
join airports_data b
on b.airport_code = f.departure_airport;
```
> Левостороннее соединение таблиц
```sql
-- билеты которые были куплены, но посадка не состоялась
select tf.*
from ticket_flights tf 
left join boarding_passes bp 
on tf.flight_id = bp.flight_id and tf.ticket_no = bp.ticket_no
where bp.flight_id is null;
```
> Кросс соединение таблиц
```sql
select bp.*, f.* 
from boarding_passes bp 
cross join flights f;
```
> Полное соединение таблиц
```sql
select bp.ticket_no, bp.seat_no, f.flight_no, f.scheduled_departure, f.scheduled_arrival 
from boarding_passes bp 
full join flights f 
on f.flight_id = bp.flight_id;
```
> Разные типы соединений
```sql
select bp.flight_id, bp.seat_no, s.fare_conditions, tf.amount 
from seats s 
left join boarding_passes bp 
on s.seat_no = bp.seat_no
join ticket_flights tf on tf.flight_id = bp.flight_id 
and tf.ticket_no = bp.ticket_no
where bp.flight_id > 40;
```
