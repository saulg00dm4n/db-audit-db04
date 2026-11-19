BEGIN;

DO $$
DECLARE
    v_dept_id     BIGINT;
    v_member_id   BIGINT;
    v_outsider_id BIGINT;
    v_p1          BIGINT;
    v_p2          BIGINT;
    v_task_id     BIGINT;
BEGIN
    INSERT INTO department (department_code, department_name)
    VALUES ('TEST_DEPT', 'Тестовый отдел')
    RETURNING department_id INTO v_dept_id;

    INSERT INTO employee (department_id, employee_name, email)
    VALUES (v_dept_id, 'Участник проекта', 'member@test.local')
    RETURNING employee_id INTO v_member_id;

    INSERT INTO employee (department_id, employee_name, email)
    VALUES (v_dept_id, 'Посторонний сотрудник', 'outsider@test.local')
    RETURNING employee_id INTO v_outsider_id;

    INSERT INTO project (project_code, project_name, manager_id)
    VALUES ('TEST_P1', 'Тестовый проект 1', v_member_id)
    RETURNING project_id INTO v_p1;

    INSERT INTO project_member (project_id, employee_id)
    VALUES (v_p1, v_member_id);

    INSERT INTO task (project_id, task_code, task_title, task_status)
    VALUES (v_p1, 'TEST_T1', 'Тестовая задача 1', 'NEW')
    RETURNING task_id INTO v_task_id;

    BEGIN
        INSERT INTO task_assignment (task_id, employee_id, project_id, role)
        VALUES (v_task_id, v_outsider_id, v_p1, 'Тестовый исполнитель');
        RAISE EXCEPTION 'FAIL: назначение постороннего сотрудника разрешено';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'PASS: назначение постороннего сотрудника отклонено FK';
    END;

    BEGIN
        INSERT INTO task_assignment (task_id, employee_id, project_id, role)
        VALUES (v_task_id, v_member_id, v_p1, 'Тестовый исполнитель');
        RAISE NOTICE 'PASS: назначение участника проекта принято';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'FAIL: назначение участника проекта отклонено';
    END;

    INSERT INTO project (project_code, project_name, manager_id)
    VALUES ('TEST_P2', 'Тестовый проект 2', v_member_id)
    RETURNING project_id INTO v_p2;

    INSERT INTO project_member (project_id, employee_id)
    VALUES (v_p2, v_member_id);

    BEGIN
        INSERT INTO task_assignment (task_id, employee_id, project_id, role)
        VALUES (v_task_id, v_member_id, v_p2, 'Тестовый исполнитель');
        RAISE EXCEPTION 'FAIL: несоответствие project_id и task_id разрешено';
    EXCEPTION WHEN foreign_key_violation THEN
        RAISE NOTICE 'PASS: несоответствие project_id и task_id отклонено FK';
    END;

    RAISE NOTICE 'ALL TESTS PASSED';
END $$;

ROLLBACK;
