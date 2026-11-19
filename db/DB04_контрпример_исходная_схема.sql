BEGIN;

WITH candidate AS (
    SELECT t.task_id, e.employee_id
    FROM task AS t
    CROSS JOIN employee AS e
    WHERE NOT EXISTS (
        SELECT 1 FROM project_member AS pm
        WHERE pm.project_id = t.project_id
          AND pm.employee_id = e.employee_id
    )
      AND NOT EXISTS (
        SELECT 1 FROM task_assignment AS ta
        WHERE ta.task_id = t.task_id
          AND ta.employee_id = e.employee_id
    )
    ORDER BY t.task_id, e.employee_id
    LIMIT 1
)
INSERT INTO task_assignment (task_id, employee_id, role)
SELECT task_id, employee_id, 'Тестовый исполнитель'
FROM candidate
RETURNING task_id, employee_id, role;

ROLLBACK;
