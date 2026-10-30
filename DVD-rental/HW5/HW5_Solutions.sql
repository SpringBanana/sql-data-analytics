--=============== МОДУЛЬ 5. POSTGRESQL =======================================
--= ПОМНИТЕ, ЧТО НЕОБХОДИМО УСТАНОВИТЬ ВЕРНОЕ СОЕДИНЕНИЕ И ВЫБРАТЬ СХЕМУ PUBLIC===========
SET search_path TO public;

--======== ОСНОВНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--Напишите SQL-запрос, который выводит всю информацию о фильмах со специальным атрибутом "Behind the Scenes".
--В результирующей таблице должны быть следующие столбцы: Название фильма, столбец со специальными атрибутами.

explain analyze -- 100.50 / 0.36
select *
from film
where special_features @> array['Behind the Scenes']


--ЗАДАНИЕ №2
--Напишите еще 2 варианта поиска фильмов с атрибутом "Behind the Scenes",
--используя другие функции или операторы языка SQL для поиска значения в массиве.
--В результирующей таблице должны быть следующие столбцы: Название фильма, столбец со специальными атрибутами.

explain analyze -- 103 / 0.28
select *
from film
where 'Behind the Scenes' = any(special_features)


explain analyze -- 103 / 0.29
select *
from film
where not 'Behind the Scenes' != all(special_features)

--ЗАДАНИЕ №3
--Для каждого покупателя посчитайте сколько он брал в аренду фильмов 
--со специальным атрибутом "Behind the Scenes.
--Обязательное условие для выполнения задания: используйте запрос из задания 1, 
--помещенный в CTE. CTE необходимо использовать для решения задания.
--В результирующей таблице должны быть следующие столбцы: Фамилия и имя пользователя в виде одного значения, 
--количество арендованных фильмов.

explain analyze -- 380 / 2.5
with cte as (select *
             from film
             where special_features @> array ['Behind the Scenes'])
select c.last_name || ' ' || c.first_name, count(f.film_id)
    from customer c
    join rental r on r.customer_id = c.customer_id
    join inventory i on r.inventory_id = i.inventory_id
    join cte f on f.film_id = i.film_id
group by c.customer_id


--ЗАДАНИЕ №4
--Для каждого покупателя посчитайте сколько он брал в аренду фильмов
-- со специальным атрибутом "Behind the Scenes".
--Обязательное условие для выполнения задания: используйте запрос из задания 1,
--помещенный в подзапрос, который необходимо использовать для решения задания.
--В результирующей таблице должны быть следующие столбцы: Фамилия и имя пользователя в виде одного значения, 
--количество арендованных фильмов.

explain analyze -- 380 / 2.7
select c.last_name || ' ' || c.first_name, count(f.film_id)
    from (select *
             from film
             where special_features @> array ['Behind the Scenes']) f
    join inventory i on i.film_id = f.film_id
    join rental r on r.inventory_id = i.inventory_id
    join customer c on c.customer_id = r.customer_id
    group by c.customer_id



--ЗАДАНИЕ №5
--Создайте материализованное представление с запросом из предыдущего задания
--и напишите запрос для обновления материализованного представления


create materialized view task_5 as
    (
        select c.last_name || ' ' || c.first_name, count(f.film_id)
            from (select *
                     from film
                     where special_features @> array ['Behind the Scenes']) f
            join inventory i on i.film_id = f.film_id
            join rental r on r.inventory_id = i.inventory_id
            join customer c on c.customer_id = r.customer_id
            group by c.customer_id
   )

refresh materialized view task_5

--ЗАДАНИЕ №6
--С помощью explain analyze проведите анализ стоимости выполнения запросов из предыдущих заданий и ответьте на вопросы:
--1. с каким оператором или функцией языка SQL, используемыми при выполнении домашнего задания:
--поиск значения в массиве затрачивает меньше ресурсов системы;
--2. какой вариант вычислений затрачивает меньше ресурсов системы: 
--с использованием CTE или с использованием подзапроса.


 1 - Поиск в массиве затрачивает меньше ресурсов с оператором @>

 2 - Так как CTE используется 1 раз, то разницы с подзапросом нет, что и видно по одинаковой стоимости




--======== ДОПОЛНИТЕЛЬНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--Задание 1. Откройте по ссылке SQL-запрос: https://letsdocode.ru/sql-main/sql-hw5.sql
--Сделайте explain analyze этого запроса.
--Основываясь на описании запроса, найдите узкие места и опишите их.
--Сравните с вашим решением из 4 задания.
--Сделайте построчное описание explain analyze на русском языке оптимизированного запроса. 
--Описание строк в explain можно посмотреть по ссылке: https://use-the-index-luke.com/sql/explain-plan/postgresql/operations

full outer join используется в запросе 3 раза, также используется оконная функция, unnest и distinct
из-за чего нам приходится делать Seq Scan 4 таблиц и hash join не отфильтрованных значений это раздувает цену и время запроса

Мое решение использует Seq Scan на меньших данных и использует index scan

План запроса:
    1 - Делаем Seq Scan таблицы film с фильтром @> 'Behind The Scenes'
    2 - Хешируем отфильтрованную таблицу film в 1024 бакета
    3 - Делаем Seq Scan по таблице inventory
    4 - Hash Join таблицы inventory и отсортированной таблице film по film_id
    5 - В Nested Loop делаем Index Scan по внешнему ключу inventory_id в таблице rental
    6 - Seq Scan таблицу customer
    7 - Хешируем customer в 1024 бакета
    8 - Hash Join таблицы rental по customer_id
    9 - Hash Aggregate по customer_id



--ЗАДАНИЕ №2
--Используя оконную функцию выведите для каждого сотрудника сведения о самой первой продаже этого сотрудника.
--В результирующей таблице должны быть следующие столбцы:Все столбцы из таблицы с платежами.

select *
    from payment p
    join (
        select  payment_id, row_number() over (partition by staff_id order by payment_date) as payment_count
        from payment
        ) first_payment on first_payment.payment_id = p.payment_id
    where first_payment.payment_count = 1




--ЗАДАНИЕ №3
--Для каждого магазина определите и выведите одним SQL-запросом следующие аналитические показатели:
-- 1. день, в который арендовали больше всего фильмов (день в формате год-месяц-день)
-- 2. количество фильмов взятых в аренду в этот день
-- 3. день, в который продали фильмов на наименьшую сумму (день в формате год-месяц-день)
-- 4. сумму продажи в этот день
--В результирующей таблице должны быть следующие столбцы: Идентификатор магазина, день аренды, количество фильмов, день продажи, сумма продаж.

-- Комментарий по решению:
-- Последнее задание нельзя выполнить без уточнения к связам в БД
-- В базе данных dvd-rental нет точной связи между таблицами store и payment
-- Здесь приведен вариант связи через таблицы store -> inventory -> rental -> payment

with daily_stats as (
    select
        s.store_id,
        date(r.rental_date) as rnt_day,
        count(r.rental_id) as rentals_count,
        coalesce(sum(p.amount), 0) as sales_sum
    from store s
    join inventory i on i.store_id = s.store_id
    join rental r on r.inventory_id = i.inventory_id
    left join payment p on p.rental_id = r.rental_id
    group by s.store_id, date(r.rental_date)
),
rental_max as (
    select
        store_id,
        rnt_day as max_rental_day,
        rentals_count as max_rentals_count
    from (
        select store_id, rnt_day, rentals_count,
               row_number() over (partition by store_id order by rentals_count desc, rnt_day desc) as rn
        from daily_stats
    ) ranked
    where rn = 1
),
sales_min as (
    select
        store_id,
        rnt_day as min_sales_day,
        sales_sum as min_sales_sum
    from (
        select store_id, rnt_day, sales_sum,
               row_number() over (partition by store_id order by sales_sum, rnt_day) as rn
        from daily_stats
    ) ranked
    where rn = 1
)
select
    rm.store_id as store_id,
    rm.max_rental_day as max_rentals_day,
    rm.max_rentals_count as rentals_count,
    sm.min_sales_day as min_sales_day,
    sm.min_sales_sum as sales_sum
from rental_max rm
join sales_min sm on rm.store_id = sm.store_id
order by rm.store_id

