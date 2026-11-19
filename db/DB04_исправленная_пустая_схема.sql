-- DB-04: исправленная пустая схема PostgreSQL
-- Новое правило: исполнитель задачи должен быть участником проекта этой задачи.
-- Скрипт создаёт структуру с нуля, без тестовых/исходных данных.
-- Выполнять в отдельной пустой базе данных.

BEGIN;

CREATE TABLE department (
    department_id BIGSERIAL PRIMARY KEY,
    department_code TEXT NOT NULL UNIQUE,
    department_name TEXT NOT NULL
);

CREATE TABLE employee (
    employee_id BIGSERIAL PRIMARY KEY,
    department_id BIGINT NOT NULL,
    employee_name TEXT NOT NULL,
    email TEXT NOT NULL,

    CONSTRAINT fk_employee_department
        FOREIGN KEY (department_id)
        REFERENCES department (department_id)
        ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_employee_email_lower
    ON employee (LOWER(email));

CREATE TABLE project (
    project_id BIGSERIAL PRIMARY KEY,
    project_code TEXT NOT NULL UNIQUE,
    project_name TEXT NOT NULL,
    manager_id BIGINT NOT NULL,

    CONSTRAINT fk_project_manager
        FOREIGN KEY (manager_id)
        REFERENCES employee (employee_id)
        ON DELETE RESTRICT
);

CREATE TABLE task (
    task_id BIGSERIAL PRIMARY KEY,
    project_id BIGINT NOT NULL,
    task_code TEXT NOT NULL,
    task_title TEXT NOT NULL,
    task_status TEXT NOT NULL DEFAULT 'NEW',

    CONSTRAINT fk_task_project
        FOREIGN KEY (project_id)
        REFERENCES project (project_id)
        ON DELETE RESTRICT,

    CONSTRAINT uq_task_code_in_project
        UNIQUE (project_id, task_code),

    -- Требуется для составного внешнего ключа из task_assignment.
    CONSTRAINT uq_task_project_task
        UNIQUE (project_id, task_id),

    CONSTRAINT chk_task_status
        CHECK (
            task_status IN (
                'NEW',
                'IN_PROGRESS',
                'REVIEW',
                'DONE',
                'BLOCKED'
            )
        )
);

CREATE TABLE project_member (
    project_id BIGINT NOT NULL,
    employee_id BIGINT NOT NULL,

    CONSTRAINT pk_project_member
        PRIMARY KEY (project_id, employee_id),

    CONSTRAINT fk_member_project
        FOREIGN KEY (project_id)
        REFERENCES project (project_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_member_employee
        FOREIGN KEY (employee_id)
        REFERENCES employee (employee_id)
        ON DELETE RESTRICT
);

CREATE TABLE task_assignment (
    task_id BIGINT NOT NULL,
    employee_id BIGINT NOT NULL,
    project_id BIGINT NOT NULL,
    assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    role TEXT NOT NULL,

    CONSTRAINT pk_task_assignment
        PRIMARY KEY (task_id, employee_id),

    -- Задача действительно относится к указанному проекту.
    CONSTRAINT fk_assignment_task_project
        FOREIGN KEY (project_id, task_id)
        REFERENCES task (project_id, task_id)
        ON DELETE RESTRICT,

    -- Исполнитель обязательно состоит в указанном проекте.
    CONSTRAINT fk_assignment_project_member
        FOREIGN KEY (project_id, employee_id)
        REFERENCES project_member (project_id, employee_id)
        ON DELETE RESTRICT
);

CREATE TABLE time_entry (
    time_entry_id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL,
    employee_id BIGINT NOT NULL,
    work_date DATE NOT NULL,
    hours NUMERIC(8, 2) NOT NULL,

    CONSTRAINT fk_time_task
        FOREIGN KEY (task_id)
        REFERENCES task (task_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_time_employee
        FOREIGN KEY (employee_id)
        REFERENCES employee (employee_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_time_hours
        CHECK (hours > 0 AND hours <> 'NaN'::NUMERIC)
);

CREATE TABLE task_status_history (
    history_id BIGSERIAL PRIMARY KEY,
    task_id BIGINT NOT NULL,
    changed_by BIGINT NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    old_status TEXT,
    new_status TEXT NOT NULL,

    CONSTRAINT fk_history_task
        FOREIGN KEY (task_id)
        REFERENCES task (task_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_history_author
        FOREIGN KEY (changed_by)
        REFERENCES employee (employee_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_history_old_status
        CHECK (
            old_status IS NULL
            OR old_status IN (
                'NEW',
                'IN_PROGRESS',
                'REVIEW',
                'DONE',
                'BLOCKED'
            )
        ),

    CONSTRAINT chk_history_new_status
        CHECK (
            new_status IN (
                'NEW',
                'IN_PROGRESS',
                'REVIEW',
                'DONE',
                'BLOCKED'
            )
        ),

    CONSTRAINT chk_history_status_change
        CHECK (
            old_status IS NULL
            OR old_status <> new_status
        )
);

COMMIT;
