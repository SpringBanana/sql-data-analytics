--=============== МОДУЛЬ 4. РАБОТА С POSTGRESQL =======================================
--= ПОМНИТЕ, ЧТО НЕОБХОДИМО УСТАНОВИТЬ ВЕРНОЕ СОЕДИНЕНИЕ И ВЫБРАТЬ СХЕМУ PUBLIC===========
SET search_path TO public;

--======== ОСНОВНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--Сделайте запрос к таблице payment и с помощью оконных функций добавьте вычисляемые колонки согласно условиям:
--1.1 Пронумеруйте все платежи от 1 до N по дате платежа
--1.2 Пронумеруйте платежи для каждого покупателя, сортировка платежей должна быть по дате платежа
--1.3 Посчитайте нарастающим итогом сумму всех платежей для каждого покупателя, сортировка должна быть 
--сперва по дате платежа, а затем по размеру платежа от наименьшей к большей
--1.4 Пронумеруйте платежи для каждого покупателя по размеру платежа от наибольшего к меньшему так, 
--чтобы платежи с одинаковым значением имели одинаковое значение номера.
--В результирующей таблице должны быть следующие столбцы: Идентификатор платежа, дата платежа, 
--идентификатор пользователя, размер платежа, 4 столбца с результатами оконных функций.


select  payment_id,
        payment_date,
        customer_id,
        amount,
        row_number() over (order by payment_date) payment_num_by_date,
        row_number() over (partition by customer_id order by payment_date) payment_num_by_user,
        sum(amount) over (partition by customer_id order by payment_date, amount) running_sum_by_customer,
        dense_rank() over (partition by customer_id order by amount desc) customer_payment_rank_by_amount
    from payment


--ЗАДАНИЕ №2
--С помощью оконной функции выведите для каждого покупателя стоимость платежа и стоимость 
--платежа из предыдущей строки со значением по умолчанию 0.0 с сортировкой по дате платежа.
--В результирующей таблице должны быть следующие столбцы: Идентификатор платежа, дата платежа, 
--идентификатор пользователя, текущий размер платежа, размер платежа из предыдущей строки.


select  payment_id,
        payment_date,
        customer_id,
        amount,
        lag(amount, 1, 0.0) over (partition by customer_id order by payment_date) as prev_amount
    from payment


--ЗАДАНИЕ №3
--С помощью оконной функции определите, на сколько каждый следующий платеж покупателя больше или меньше текущего.
--В результирующей таблице должны быть следующие столбцы: Идентификатор платежа, дата платежа, идентификатор пользователя, 
--текущий размер платежа, следующий размер платежа, разница между текущим и следующим платежами.


select payment_id,
       payment_date,
       customer_id,
       amount,
       lead(amount, 1 , 0.0) over (partition by customer_id order by payment_date) as next_amount,
       amount - lead(amount, 1 , 0.0) over (partition by customer_id order by payment_date) as diff
    from payment


--ЗАДАНИЕ №4
--С помощью оконной функции для каждого покупателя выведите данные о его последней оплате аренды.
--В результирующей таблице должны быть следующие столбцы: Все столбцы из таблицы с платежами.

select *
    from (
        select *,
               max(payment_date) over (partition by customer_id) as max_payment_date
            from payment p
         ) t
    where payment_date = max_payment_date




--======== ДОПОЛНИТЕЛЬНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--С помощью оконной функции выведите для каждого сотрудника сумму продаж за август 2005 года 
--с нарастающим итогом по каждому сотруднику и по каждой дате продажи (без учёта времени) 
--с сортировкой по дате.
--В результирующей таблице должны быть следующие столбцы: Фамилия и имя сотрудника в виде 
--одного значения, сумма продаж на каждый день, накопительный итог.


with cte as (
    select
        p.staff_id,
        first_name || ' ' || last_name as name,
        date_trunc('day', p.payment_date)::date as payment_day,
        sum(p.amount) as sum_per_day
    from payment p
    join staff s on s.staff_id = p.staff_id
    where p.payment_date between '2005-08-01' and '2005-08-31'
    group by 1,2,3
)
select
    name,
    sum_per_day,
    sum(sum_per_day) over (partition by staff_id order by payment_day) as running_sum_per_day
from cte
order by payment_day


--ЗАДАНИЕ №2
--20 августа 2005 года в магазинах проходила акция: покупатель каждого сотого платежа получал
--дополнительную скидку на следующую аренду. С помощью оконной функции выведите всех покупателей,
--которые в день проведения акции получили скидку
--В результирующей таблице должны быть следующие столбцы: Идентификатор пользователя, 
--фамилия и имя пользователя в виде одного значения.

with cte as (
    select payment_date::date as payment_day,
           customer_id,
           row_number() over (order by payment_date) rn
    from payment
    where payment_date::date = '2005-08-20'
)
select c.customer_id, first_name || ' ' || last_name as name
    from customer c
    join cte ct on c.customer_id = ct.customer_id
    where rn % 100 = 0

--ЗАДАНИЕ №3
--Для каждой страны определите и выведите одним SQL-запросом покупателей, которые попадают под условия:
-- 1. покупатель, арендовавший наибольшее количество фильмов
-- 2. покупатель, арендовавший фильмов на самую большую сумму
-- 3. покупатель, который последним арендовал фильм
--В результирующей таблице должны быть следующие столбцы: Название страны, фамилия и имя пользователя в
--виде одного значения лучшего по количеству, фамилия и имя пользователя в виде одного значения лучшего
--по сумме платежей, фамилия и имя пользователя в виде одного значения последним арендовавшим фильм.
--Есть два варианта решения: получать одного случайного, если в топ 1 попадает несколько пользователей,
--выводить всех пользователей, попавших в топ 1. Выбор варианта остается за вами.

explain analyze
with cte1 as (
        select  co.country,
                co.country_id,
                c.customer_id,
                last_name || ' ' || first_name as name,
                count(r.rental_id) as rental_cnt,
                coalesce(sum(p.amount), 0) as sum_amount,
                max(r.rental_date) as last_rental
            from customer c
            join address a on a.address_id = c.address_id
            join city ci on ci.city_id = a.city_id
            join country co on ci.country_id = co.country_id
            join rental r on r.customer_id = c.customer_id
            join payment p on p.customer_id = c.customer_id
            group by co.country_id, c.customer_id
    ),
    cte2 as (
        select country,
               name,
               row_number() over (partition by country order by rental_cnt desc) as rn_cnt,
               row_number() over (partition by country order by sum_amount desc) as rn_sum,
               row_number() over (partition by country order by last_rental desc) as rn_last
            from cte1
    )
select country,
       max(case when rn_cnt = 1 then name end) as most_rentals,
       max(case when rn_sum = 1 then name end) as most_payments_by_rentals,
       max(case when rn_last = 1 then name end) as last_rented
from cte2
group by country







