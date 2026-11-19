BEGIN;

-- 1. Пять подразделений
INSERT INTO department (department_code, department_name)
VALUES
    ('DEV', 'Разработка'),
    ('QA', 'Тестирование'),
    ('BI', 'Аналитика'),
    ('OPS', 'Эксплуатация'),
    ('SEC', 'Информационная безопасность');

-- 2. Двадцать пять сотрудников
INSERT INTO employee (department_id, employee_name, email)
SELECT
    d.department_id,
    'Сотрудник ' || n,
    'employee' || n || '@corp.ru'
FROM generate_series(1, 25) AS g(n)
JOIN department d
    ON d.department_code =
       (ARRAY['DEV', 'QA', 'BI', 'OPS', 'SEC'])[
           ((n - 1) % 5) + 1
       ];

-- 3. Десять проектов
INSERT INTO project (project_code, project_name, manager_id)
SELECT
    'P-' || LPAD(n::TEXT, 2, '0'),
    'Проект ' || n,
    e.employee_id
FROM generate_series(1, 10) AS g(n)
JOIN employee e
    ON e.email = 'employee' || n || '@corp.ru';

-- 4. Шестьдесят задач в девяти проектах.
-- Проект P-10 оставляем без задач для проверки запросов.
INSERT INTO task (project_id, task_code, task_title, task_status)
SELECT
    p.project_id,
    'T-' || n,
    'Задача ' || n,
    CASE
        WHEN n <= 10 THEN 'IN_PROGRESS'
        WHEN n % 3 = 0 THEN 'DONE'
        ELSE 'IN_PROGRESS'
    END
FROM generate_series(1, 60) AS g(n)
JOIN project p
    ON p.project_code =
       'P-' || LPAD((((n - 1) % 9) + 1)::TEXT, 2, '0');

-- 5. По два исполнителя на каждую задачу.
-- Всего 120 назначений.
INSERT INTO task_assignment (
    task_id, employee_id, assigned_at, role
)
SELECT
    t.task_id,
    e.employee_id,
    TIMESTAMP '2026-09-01 09:00:00',
    CASE
        WHEN a = 0 THEN 'Разработчик'
        ELSE 'Тестировщик'
    END
FROM generate_series(1, 60) AS g(n)
JOIN task t ON t.task_code = 'T-' || n
CROSS JOIN generate_series(0, 1) AS x(a)
JOIN employee e
    ON e.email =
       'employee' || (((n - 1 + a * 7) % 25) + 1) || '@corp.ru';

-- 6. Добавляем исполнителей в участники их проектов.
INSERT INTO project_member (project_id, employee_id)
SELECT DISTINCT
    t.project_id,
    a.employee_id
FROM task_assignment a
JOIN task t ON t.task_id = a.task_id;

-- Руководители также участвуют в своих проектах.
INSERT INTO project_member (project_id, employee_id)
SELECT project_id, manager_id
FROM project
ON CONFLICT (project_id, employee_id) DO NOTHING;

-- 7. Триста записей времени за сентябрь.
-- Проект P-09 оставляем без трудозатрат.
WITH assignments AS (
    SELECT
        a.task_id,
        a.employee_id,
        ROW_NUMBER() OVER (
            ORDER BY a.task_id, a.employee_id
        ) AS rn,
        COUNT(*) OVER () AS total
    FROM task_assignment a
    JOIN task t ON t.task_id = a.task_id
    JOIN project p ON p.project_id = t.project_id
    WHERE p.project_code <> 'P-09'
)
INSERT INTO time_entry (
    task_id, employee_id, work_date, hours
)
SELECT
    a.task_id,
    a.employee_id,
    DATE '2026-09-02' + ((n - 1) % 28),
    (1 + ((n - 1) % 8)) * 0.5
FROM generate_series(1, 300) AS g(n)
JOIN assignments a
    ON a.rn = ((n - 1) % a.total) + 1;

-- 8. Начальный статус каждой задачи: 60 событий.
INSERT INTO task_status_history (
    task_id, changed_by, changed_at, old_status, new_status
)
SELECT
    t.task_id,
    p.manager_id,
    TIMESTAMP '2026-09-01 09:00:00',
    NULL,
    'NEW'
FROM task t
JOIN project p ON p.project_id = t.project_id;

-- Первое изменение каждой задачи: ещё 60 событий.
INSERT INTO task_status_history (
    task_id, changed_by, changed_at, old_status, new_status
)
SELECT
    t.task_id,
    p.manager_id,
    TIMESTAMP '2026-09-02 10:00:00',
    'NEW',
    t.task_status
FROM task t
JOIN project p ON p.project_id = t.project_id;

-- У первых десяти задач добавляем ещё три изменения.
-- Всего получится 150 событий истории.
INSERT INTO task_status_history (
    task_id, changed_by, changed_at, old_status, new_status
)
SELECT
    t.task_id,
    p.manager_id,
    v.event_date,
    v.old_status,
    v.new_status
FROM generate_series(1, 10) AS g(n)
JOIN task t ON t.task_code = 'T-' || n
JOIN project p ON p.project_id = t.project_id
CROSS JOIN (
    VALUES
        (
            TIMESTAMP '2026-09-03 10:00:00',
            'IN_PROGRESS', 'REVIEW'
        ),
        (
            TIMESTAMP '2026-09-04 10:00:00',
            'REVIEW', 'DONE'
        ),
        (
            TIMESTAMP '2026-09-05 10:00:00',
            'DONE', 'IN_PROGRESS'
        )
) AS v(event_date, old_status, new_status);

COMMIT;

-- Проверяем количество записей.
SELECT 'department' AS table_name, COUNT(*) AS rows_count
FROM department
UNION ALL
SELECT 'employee', COUNT(*) FROM employee
UNION ALL
SELECT 'project', COUNT(*) FROM project
UNION ALL
SELECT 'task', COUNT(*) FROM task
UNION ALL
SELECT 'project_member', COUNT(*) FROM project_member
UNION ALL
SELECT 'task_assignment', COUNT(*) FROM task_assignment
UNION ALL
SELECT 'time_entry', COUNT(*) FROM time_entry
UNION ALL
SELECT 'task_status_history', COUNT(*) FROM task_status_history;