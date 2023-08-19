## Урок 23

### Подготовка схемы бд
> Создаем объекты согласно приложенному файлу
```sql
DROP SCHEMA IF EXISTS pract_functions CASCADE;
CREATE schema pract_functions;

SET search_path = pract_functions, publ

-- товары:
CREATE TABLE goods
(
    goods_id    integer PRIMARY KEY,
    good_name   varchar(63) NOT NULL,
    good_price  numeric(12, 2) NOT NULL CHECK (good_price > 0.0)
);
INSERT INTO goods (goods_id, good_name, good_price)
VALUES 	(1, 'Спички хозайственные', .50),
		(2, 'Автомобиль Ferrari FXX K', 185000000.01);

-- Продажи
CREATE TABLE sales
(
    sales_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    good_id     integer REFERENCES goods (goods_id),
    sales_time  timestamp with time zone DEFAULT now(),
    sales_qty   integer CHECK (sales_qty > 0)
);

INSERT INTO sales (good_id, sales_qty) VALUES (1, 10), (1, 1), (1, 120), (2, 1);

-- отчет:
SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name;

-- с увеличением объёма данных отчет стал создаваться медленно
-- Принято решение денормализовать БД, создать таблицу
CREATE TABLE good_sum_mart
(
	good_name   varchar(63) NOT NULL,
	sum_sale	numeric(16, 2)NOT NULL
);
```
#### Создание триггерной функции
```sql
CREATE OR REPLACE FUNCTION add_mart_goods() RETURNS TRIGGER AS $$

DECLARE
	v_sales_qty int;
	v_good_id int;
	-- v_sum_sale numeric(16, 2);
BEGIN

	-- В зависимости от операции в исходной таблице редактируем количество товара в витрине
	IF (TG_OP = 'INSERT') THEN
		v_sales_qty = NEW.sales_qty;
		v_good_id = NEW.good_id;
	ELSIF (TG_OP = 'UPDATE' and NEW.sales_qty != OLD.sales_qty) THEN
		v_sales_qty = NEW.sales_qty - OLD.sales_qty;
	 	v_good_id = OLD.good_id;
	ELSIF (TG_OP = 'DELETE') THEN
		v_sales_qty = -1 * OLD.sales_qty;
		v_good_id = OLD.good_id;
	END IF;
	
	-- Кладем данные в витрину
	INSERT INTO good_sum_mart
	SELECT good_name, good_price * v_sales_qty
	FROM goods WHERE goods_id = v_good_id;
	
	RETURN null;
END;
$$ LANGUAGE plpgsql;
```

#### Создание триггера
```sql
CREATE TRIGGER good_sum_mart_tr
AFTER INSERT OR UPDATE OR DELETE ON sales
FOR EACH ROW EXECUTE FUNCTION add_mart_goods();
```
### Проверка работоспособности
> Зальем данные по продажам заново, чтобы тригер отработал.

```sql
truncate table sales;
truncate table good_sum_mart;
INSERT INTO sales (good_id, sales_qty) VALUES (1, 10), (1, 1), (1, 120), (2, 1);
```
> Сравним проверочный запрос с нашей витриной
```sql
SELECT G.good_name, sum(G.good_price * S.sales_qty)
FROM goods G
INNER JOIN sales S ON S.good_id = G.goods_id
GROUP BY G.good_name;

        good_name         |     sum
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        65.50
(2 строки)
```

```sql
select good_name, sum(sum_sale)
from good_sum_mart
group by good_name;

        good_name         |     sum
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        65.50
(2 строки)
```
> Сделаем все 3 типа операций, чтобы проверить работу триггера и изменим цену товара и будем продавать Ferrari за 100 млн.
```sql
update goods
set good_price = 100000000
where goods_id = 2;
```
> Продаем 2 Ferrari клиенту
```sql
INSERT INTO sales (good_id, sales_qty) VALUES (2, 2);

select good_name, sum(sum_sale)
from good_sum_mart
group by good_name;
        good_name         |     sum
--------------------------+--------------
 Автомобиль Ferrari FXX K | 385000000.01
 Спички хозайственные     |        65.50
(2 строки)

```
> Клиент передумал и решил взять только 1 Ferrari
```sql
update sales
set sales_qty = 1
where sales_id = 25;

select good_name, sum(sum_sale)
from good_sum_mart
group by good_name;
        good_name         |     sum
--------------------------+--------------
 Автомобиль Ferrari FXX K | 285000000.01
 Спички хозайственные     |        65.50
(2 строки)

```
> Клиент снова передумал и нужно отменить продажу
```sql
delete from sales
where sales_id = 25;

select good_name, sum(sum_sale)
from good_sum_mart
group by good_name;
        good_name         |     sum
--------------------------+--------------
 Автомобиль Ferrari FXX K | 185000000.01
 Спички хозайственные     |        65.50
(2 строки)

```

### Чем такая схема (витрина+триггер) предпочтительнее отчета, создаваемого "по требованию" (кроме производительности)?

> Фиксируем цену именно на момент продажи, а не берем из справочника товаров.