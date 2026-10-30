# 📊 SQL Data Analytics & Case Studies (PostgreSQL)

Коллекция прикладных аналитических задач и сквозных кейсов по SQL (PostgreSQL): от проектирования реляционных баз данных и витрин до построения сложных аналитических отчетов с оконными функциями, скользящими агрегатами и рекурсивными CTE.

---

## 🛠 Ключевой стек и освоенные концепции

* **СУБД:** PostgreSQL 14+
* **Аналитические конструкции:** Оконные функции (`DENSE_RANK`, `ROW_NUMBER`, `NTILE`, `LAG`/`LEAD`, фреймы `ROWS BETWEEN`), Common Table Expressions (CTE), Recursive CTE (обход графов и иерархий).
* **Сводные отчеты и группировки:** `FILTER (WHERE ...)`, `GROUPING SETS`, `ROLLUP`, `CUBE`, `CASE WHEN`.
* **Временной анализ:** Когортный анализ (Retention), скользящие показатели, работа с таймстемпами (`DATE_TRUNC`, `INTERVAL`, `AGE`, генерация рядов `generate_series`).
* **Моделирование и оптимизация:** Нормализация до 3НФ, построение ER-диаграмм, материализованные представления (`MATERIALIZED VIEW`), B-Tree индексы, анализ планов запросов (`EXPLAIN ANALYZE`).

---

## 📂 Проекты в репозитории

### 1. 🏗 [Аналитика строительного холдинга («Stroy»)](./Stroy)
**Сквозной итоговый проект** на базе сложной реляционной схемы: учет контрагентов, объектов строительства, бюджетов, окладов и многоуровневой структуры подразделений.

* **Архитектура базы:** 8 связанных таблиц со связями 1:M и M:M ([Схема БД](./Stroy/Stroy_diagram.png)).
* **Решенные бизнес-задачи:**
  * Анализ доходности объектов и кассовых разрывов по факту поступления траншей.
  * Рекурсивный обход организационной структуры компании (вычисление совокупных бюджетов по иерархии отделов через `WITH RECURSIVE`).
  * Построение витрины для финансового мониторинга и вычисление скользящих показателей освоения сметы.
* 🔗 **[Смотреть решения задач &rarr;](./Stroy/Final)**

---

### 2. 🎬 [Бизнес-аналитика сервиса медиапроката («DVD Rental»)](./DVD-rental)
Практические сценарии продуктовой и финансовой аналитики на базе классической реляционной модели:

* **Модуль 1–2: Базовые метрики и фильтрация.** Объединение сущностей (`INNER`/`LEFT JOIN`), расчет агрегатов по странам, магазинам и жанрам кино.
* **Модуль 3–4: Клиентская сегментация.** Расчет Lifetime Value (LTV), сегментация клиентской базы по квантилям активности (`NTILE`), классификация по среднему чеку.
* **Модуль 5–6: Продвинутая аналитика и окна.** Накопительные итоги выручки (Running Total), динамика месяц к месяцу (MoM Growth с помощью `LAG`), выявление аномалий и задержек возврата фильмов.

---

## 💡 Примеры аналитических решений

<details>
<summary><b>Пример 1: Анализ ранжирования проектов по доле от общей выручки (Оконные функции)</b></summary>

```sql
WITH project_revenue AS (
    SELECT 
        p.project_name,
        c.client_name,
        SUM(pay.amount) AS total_revenue
    FROM projects p
    JOIN payments pay ON p.project_id = pay.project_id
    JOIN clients c ON p.client_id = c.client_id
    GROUP BY p.project_name, c.client_name
)
SELECT 
    project_name,
    client_name,
    total_revenue,
    ROUND(total_revenue * 100.0 / SUM(total_revenue) OVER (), 2) AS revenue_share_pct,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS rank_by_revenue
FROM project_revenue
ORDER BY total_revenue DESC;
```
</details>

<details>
<summary><b>Пример 2: Рекурсивный расчет бюджета по дереву подразделений (Recursive CTE)</b></summary>

```sql
WITH RECURSIVE department_tree AS (
    -- Базовая часть: корневые департаменты (верхний уровень)
    SELECT 
        department_id, 
        parent_id, 
        department_name, 
        1 AS depth_level,
        department_name::TEXT AS hierarchy_path
    FROM departments
    WHERE parent_id IS NULL

    UNION ALL

    -- Рекурсивная часть: дочерние отделы
    SELECT 
        d.department_id, 
        d.parent_id, 
        d.department_name, 
        dt.depth_level + 1,
        dt.hierarchy_path || ' -> ' || d.department_name
    FROM departments d
    JOIN department_tree dt ON d.parent_id = dt.department_id
)
SELECT 
    depth_level,
    hierarchy_path,
    department_name
FROM department_tree
ORDER BY hierarchy_path;
```
</details>

<details>
<summary><b>Пример 3: Скользящее среднее и накопительный итог платежей (Фреймы строк)</b></summary>

```sql
SELECT 
    payment_date::DATE AS payment_day,
    amount,
    -- Накопительный итог с начала месяца
    SUM(amount) OVER (
        PARTITION BY DATE_TRUNC('month', payment_date) 
        ORDER BY payment_date
    ) AS running_monthly_total,
    -- 7-дневное скользящее среднее чека
    ROUND(AVG(amount) OVER (
        ORDER BY payment_date::DATE 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_7d
FROM payments
ORDER BY payment_date;
```
</details>

<details>
<summary><b>Пример 4: Динамика выручки Month-over-Month (LAG и относительные темпы роста)</b></summary>

```sql
WITH monthly_metrics AS (
    SELECT 
        DATE_TRUNC('month', payment_date)::DATE AS sales_month,
        SUM(amount) AS monthly_revenue
    FROM payments
    GROUP BY DATE_TRUNC('month', payment_date)
)
SELECT 
    sales_month,
    monthly_revenue,
    LAG(monthly_revenue) OVER (ORDER BY sales_month) AS prev_month_revenue,
    ROUND(
        (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY sales_month)) * 100.0 / 
        NULLIF(LAG(monthly_revenue) OVER (ORDER BY sales_month), 0), 
        2
    ) AS mom_growth_pct
FROM monthly_metrics
ORDER BY sales_month;
```
</details>

---

## ⚡ Оптимизация и производительность

В проектах реализованы базовые практики проектирования и ускорения аналитических запросов:
* **Индексация внешних ключей и дат:** построение B-Tree индексов по полям предикатов (`WHERE payment_date >= ...`) и ключам связывания для предотвращения Seq Scan на объемных таблицах.
* **Материализованные представления:** вынос «тяжелых» расчетных агрегаций в `MATERIALIZED VIEW` с регулярным обновлением (`REFRESH MATERIALIZED VIEW CONCURRENTLY`).
* **Контроль стоимости выполнения:** валидация узлов `Nested Loop` и `Hash Aggregate` с помощью утилиты `EXPLAIN (ANALYZE, BUFFERS)`.

---

## 📁 Структура репозитория

```text
├── Stroy/
│   ├── Stroy_diagram.png      # Физическая схема данных (ER-диаграмма)
│   ├── stroy.backup           # Дамп базы данных для локального развертывания
│   └── Final/              # SQL-скрипты с решениями сквозного кейса
├── DVD-rental/
│   ├── dvd_rental_schema.png  # Реляционная модель проката
│   └── solutions/             # Тематические модули: JOIN, агрегаты, оконные функции
└── README.md                  # Описание и витрина решений
```

---

## 🚀 Быстрый старт (локальный запуск)

1. Клонируйте репозиторий:
   ```bash
   git clone https://github.com/SpringBanana/sql-data-analytics.git
   cd sql-data-analytics
   ```
2. Разверните схему проекта «Stroy» в PostgreSQL:
   ```bash
   # Создайте базу данных
   createdb -U postgres stroy_db

   # Восстановите дамп
   pg_restore -U postgres -d stroy_db ./Stroy/stroy.backup
   ```
3. Откройте любой SQL-редактор (DBeaver, DataGrip, pgAdmin) и запустите проверочный скрипт из папки `Stroy/Final`.
