## Урок 20

### Подготовка бд
> Стягиваем файл демо бд
```bash
dekholud@ubuntu1:/mnt/data/temp$ wget https://edu.postgrespro.ru/demo-big.zip
--2023-08-19 21:38:26--  https://edu.postgrespro.ru/demo-big.zip
Resolving edu.postgrespro.ru (edu.postgrespro.ru)... 213.171.56.196
Connecting to edu.postgrespro.ru (edu.postgrespro.ru)|213.171.56.196|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 243203214 (232M) [application/zip]
Saving to: ‘demo-big.zip’

demo-big.zip                          100%[=======================================================================>] 231,94M  10,9MB/s    in 30s

2023-08-19 21:38:56 (7,73 MB/s) - ‘demo-big.zip’ saved [243203214/243203214]

dekholud@ubuntu1:/mnt/data/temp$ unzip demo-big.zip
Archive:  demo-big.zip
  inflating: demo-big-20170815.sql
dekholud@ubuntu1:/mnt/data/temp$ rm -rf demo-big.zip
dekholud@ubuntu1:/mnt/data/temp$ sudo -u postgres psql -f demo-big-20170815.sql

```
### Создание секционированной таблицы
> Напишем анонимный блок для создания основной таблицы и ее секций на основании данных таблицы flights.
```sql
DO $$
DECLARE 
v_min_date date;
v_max_date date;
v_cur_date date;
v_sql_stmt text;
c_main_table_name varchar(50) = 'flights_part';
begin
	v_sql_stmt = 'create table '|| quote_ident(c_main_table_name) ||' (like flights) partition by range (scheduled_departure)';
	execute v_sql_stmt;
	v_sql_stmt = 'create table default_partition_'|| quote_ident(c_main_table_name) ||' partition of '|| quote_ident(c_main_table_name) || ' default';
	execute v_sql_stmt;
	select date_trunc('month', min(scheduled_departure)), date_trunc('month', max(scheduled_departure)) + interval '1 month'
	into v_min_date, v_max_date
	from flights;
	v_cur_date = v_min_date;
	loop
    	v_sql_stmt = 'create table ' || quote_ident(c_main_table_name || '_' || to_char(v_cur_date, 'yyyy_mm')) || ' partition of '
    	|| quote_ident(c_main_table_name) || ' for values from (''' || 
    	to_char(v_cur_date, 'yyyy-mm-dd')|| ''') to (''' || to_char(v_cur_date+ interval '1 month', 'yyyy-mm-dd')|| ''')';
    	IF v_cur_date >= v_max_date THEN
        	EXIT;
    	END IF;
    	execute v_sql_stmt;
    	--raise notice '%', v_sql_stmt;
    	v_cur_date = v_cur_date + interval '1 month';
	END LOOP;

end $$;
```
> Сделаем insert в нашу новую таблицу
```sql
insert into flights_part (select * from flights);
```
> Проверим размер наших партиций и основной таблицы.
```sql
SELECT nspname || '.' || relname AS "relation",
    pg_size_pretty(pg_relation_size(C.oid)) AS "size"
  FROM pg_class C
  LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
  WHERE nspname = 'bookings'
  and relname like '%flights_part%'
  ORDER BY pg_relation_size(C.oid) DESC;

                relation                 |  size
-----------------------------------------+---------
 bookings.flights_part_2016_10           | 1672 kB
 bookings.flights_part_2017_07           | 1672 kB
 bookings.flights_part_2016_12           | 1664 kB
 bookings.flights_part_2017_01           | 1664 kB
 bookings.flights_part_2017_03           | 1664 kB
 bookings.flights_part_2017_05           | 1664 kB
 bookings.flights_part_2016_11           | 1616 kB
 bookings.flights_part_2017_04           | 1616 kB
 bookings.flights_part_2017_06           | 1608 kB
 bookings.flights_part_2016_09           | 1608 kB
 bookings.flights_part_2017_08           | 1592 kB
 bookings.flights_part_2017_02           | 1504 kB
 bookings.flights_part_2016_08           | 912 kB
 bookings.flights_part_2017_09           | 696 kB
 bookings.flights_part                   | 0 bytes
 bookings.default_partition_flights_part | 0 bytes
(16 строк)

```