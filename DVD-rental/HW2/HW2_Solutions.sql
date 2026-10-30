--=============== МОДУЛЬ 2. ОСНОВЫ SQL =======================================
--= ПОМНИТЕ, ЧТО НЕОБХОДИМО УСТАНОВИТЬ ВЕРНОЕ СОЕДИНЕНИЕ И ВЫБРАТЬ СХЕМУ PUBLIC===========
SET search_path TO public;

--======== ОСНОВНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--Выведите для каждого покупателя его адрес проживания, город и страну проживания.
--В результирующей таблице должны быть следующие столбцы: Имя пользователя, фамилия пользователя, адрес, город, страна.


SELECT first_name, last_name, address, city, country
    FROM customer cu
    JOIN address ad on ad.address_id = cu.address_id
    JOIN city ci on ci.city_id = ad.city_id
    JOIN country co on co.country_id = ci.country_id


--ЗАДАНИЕ №2
--С помощью SQL-запроса посчитайте для каждого магазина количество его покупателей.
--В результирующей таблице должны быть следующие столбцы: Идентификатор магазина, количество прикрепленных пользователей.


SELECT store_id, count(customer_id)
    FROM customer
    GROUP BY store_id


--Доработайте запрос и выведите только те магазины, 
--у которых количество покупателей больше 300-от.
--Для решения используйте фильтрацию по сгруппированным строкам с использованием функции агрегации.
--В результирующей таблице должны быть следующие столбцы: Идентификатор магазина, количество прикрепленных пользователей.


SELECT store_id, count(customer_id)
    FROM customer
    GROUP BY store_id
    HAVING count(customer_id) > 300


-- Доработайте запрос, добавив в него информацию о городе магазина, 
--а также фамилию и имя продавца, который работает в этом магазине.
--В результирующей таблице должны быть следующие столбцы: Фамилия и имя сотрудника в виде одного значения, идентификатор магазина, 
--город нахождения магазина, количество прикрепленных пользователей.


SELECT s2.last_name || ' ' || s2.first_name name, s1.store_id, city, customer_count
    FROM (
        SELECT s.store_id, s.address_id, count(c.customer_id) customer_count
            FROM store s
            JOIN customer c on c.store_id = s.store_id
            GROUP BY s.store_id
            HAVING COUNT(c.customer_id) > 300
         ) s1
    JOIN staff s2 on s1.store_id = s2.store_id
    JOIN address a on s1.address_id = a.address_id
    JOIN city ci on ci.city_id = a.city_id

--ЗАДАНИЕ №3
--Выведите ТОП-5 покупателей, которые взяли в аренду за всё время наибольшее количество фильмов
--В результирующей таблице должны быть следующие столбцы: Фамилия и имя пользователя в виде одного значения, количество арендованных фильмов.


SELECT first_name || ' ' || last_name, rc.rental_count
    FROM (
        SELECT customer_id ,count(rental_id) rental_count
            FROM rental
            group by customer_id
         ) rc
    JOIN customer c on c.customer_id = rc.customer_id
    ORDER BY rental_count desc
    LIMIT 5


--ЗАДАНИЕ №4
--Посчитайте для каждого покупателя 4 аналитических показателя:
--  1. количество фильмов, которые он взял в аренду
--  2. общую стоимость платежей за аренду всех фильмов (значение округлите до целого числа)
--  3. минимальное значение платежа за аренду фильма
--  4. максимальное значение платежа за аренду фильма
--В результирующей таблице должны быть следующие столбцы: Фамилия и имя пользователя в виде одного значения, 
--количество арендованных фильмов, округленная сумма платежей, минимальный и максимальный платеж.

explain analyze --11140 / 11654
SELECT first_name || ' ' || last_name name, count(r.rental_id), round(sum(p.amount)) sum, min(p.amount), max(p.amount)
    FROM customer c
    JOIN rental r on r.customer_id = c.customer_id
    JOIN payment p on r.rental_id = p.rental_id
    GROUP BY c.customer_id


--ЗАДАНИЕ №5
--Используя данные из таблицы городов, составьте все возможные пары городов так, чтобы 
--в результате не было пар с одинаковыми названиями городов. Решение должно быть через Декартово произведение.
--В результирующей таблице должны быть следующие столбцы: два столбца с названиями городов.


SELECT c1.city, c2.city
    FROM city c1
    CROSS JOIN city c2
    WHERE c1.city > c2.city


--ЗАДАНИЕ №6
--Используя данные из таблицы rental о дате выдачи фильма в аренду (поле rental_date) и дате возврата (поле return_date),
--вычислите для каждого покупателя среднее количество дней, за которые он возвращает фильмы, округленное до сотых. 
--В результирующей таблице должны быть следующие столбцы: Фамилия и имя пользователя в виде одного значения, 
--среднее количество дней с учетом округления 


SELECT first_name || ' ' || last_name, round(rd.average)
        FROM (
           SELECT customer_id, avg(return_date::date - rental_date::date) average
                FROM rental
                GROUP BY customer_id
            ) rd
        JOIN customer c on c.customer_id = rd.customer_id

--Я не уверен, нужно ли здесь делать проверку return_date is not null

--======== ДОПОЛНИТЕЛЬНАЯ ЧАСТЬ ==============

--ЗАДАНИЕ №1
--Посчитайте для каждого фильма сколько раз его брали в аренду и значение общей стоимости аренды фильма за всё время.
--В результирующей таблице должны быть следующие столбцы: Название фильма, рейтинг фильма, язык фильма, категория фильма, 
--количество аренд фильма, общий размер платежей по фильму.


--explain analyze


SELECT title, rating, lan.name language, string_agg(DISTINCT c.name, ', ') category_name, rental_count, payment_amount
    FROM film f
    JOIN language lan on lan.language_id = f.language_id
    JOIN film_category fc on fc.film_id = f.film_id
    JOIN category c on c.category_id = fc.category_id
    JOIN (
        SELECT film_id, count(r.rental_id) rental_count, sum(amount) payment_amount
            FROM inventory i
            JOIN rental r on r.inventory_id = i.inventory_id
            JOIN payment p on p.rental_id = r.rental_id
            GROUP BY film_id
        ) rent ON rent.film_id = f.film_id
    GROUP BY  f.title, f.rating, lan.name, rent.rental_count, rent.payment_amount

--ЗАДАНИЕ №2
--Доработайте запрос из предыдущего задания и выведите с помощью него фильмы, которые отсутствуют на dvd дисках.
--В результирующей таблице должны быть следующие столбцы: Название фильма, рейтинг фильма, язык фильма, категория фильма, 
--количество аренд фильма, общий размер платежей по фильму.


SELECT title, rating, lan.name language, string_agg(DISTINCT c.name, ', ') category_name, rental_count, payment_amount
    FROM film f
    JOIN language lan ON lan.language_id = f.language_id
    JOIN film_category fc ON fc.film_id = f.film_id
    JOIN category c ON c.category_id = fc.category_id
    LEFT JOIN (
        SELECT film_id, count(r.rental_id) rental_count, sum(p.amount) payment_amount
        FROM inventory i
        JOIN rental r ON r.inventory_id = i.inventory_id
        JOIN payment p ON p.rental_id = r.rental_id
        GROUP BY film_id
        ) rent ON rent.film_id = f.film_id
    WHERE NOT exists (SELECT 1 FROM inventory i WHERE i.film_id = f.film_id)
    GROUP BY  f.title, f.rating, lan.name, rent.rental_count, rent.payment_amount



--ЗАДАНИЕ №3
--Посчитайте количество продаж, выполненных каждым продавцом. Добавьте вычисляемую колонку "Премия".
--Если количество продаж превышает 7300, то значение в колонке будет "Да", иначе должно быть значение "Нет".
--В результирующей таблице должны быть следующие столбцы: Фамилия и имя сотрудника в виде одного значения, 
--количество продаж, столбец с указанием будет премия или нет.


SELECT s.last_name || ' ' || s.first_name name, count(payment_id), CASE WHEN sum(amount) > 7300 THEN 'Да' ELSE 'Нет' END bonus
    FROM payment p
    LEFT JOIN staff s on p.staff_id = s.staff_id
    GROUP BY s.staff_id







