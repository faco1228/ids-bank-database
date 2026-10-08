-- =============================================================================
-- Tema 27: Banka
-- Cast 4: SQL skript pre vytvorenie pokrocilych objektov schemy databazy
-- Autori: xgulasa00, xfackas00
-- SRBD: Oracle 12c
-- Kodovanie: UTF-8
--
-- Skript sa da spustit opakovane.
-- Na zaciatku odstranime existujuce objekty a potom ich vytvorime znova.
-- =============================================================================


-- =============================================================================
-- Gneralizacia / specializacia
-- =============================================================================
-- V navrhu sa vyskytuje generalizacia/specializacia:
-- PERSON je nadtyp a CLIENT, EMPLOYEE su podtypy.
--
-- Prevod:
--   - spolocne atributy su v tabulke PERSON,
--   - specificke atributy klienta su v tabulke CLIENT,
--   - specificke atributy zamestnanca su v tabulke EMPLOYEE.
--
-- Tabulky CLIENT a EMPLOYEE maju PK, ktory je zaroven aj cudzim klucom na 
-- tabulku PERSON.
--
-- Tento sposob:
--   - neuklada duplicitne spolocne udaje,
--   - model je prehladny,
--   - sa da jednoducho rozlisit, ci ide o klienta alebo zamestnanca.
-- =============================================================================


-- =============================================================================
-- 1. Odstranenie existujucich objektov
-- =============================================================================

-- Materializovany pohlad
BEGIN EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW mv_client_account_summary'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Triggre (pokrocile)
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_check_balance_before_withdrawal'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_log_client_status_change'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Stare triggre zo zakladnej casti
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_bank_transaction_bi'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_person_bi'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_account_bi'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_authorization_bi'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Procedury
BEGIN EXECUTE IMMEDIATE 'DROP PROCEDURE proc_client_report'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP PROCEDURE proc_transfer_money'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Log tabulka
BEGIN EXECUTE IMMEDIATE 'DROP TABLE CLIENT_STATUS_LOG CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Stare tabulky z predchadzajucich pokusov
BEGIN EXECUTE IMMEDIATE 'DROP TABLE TRANSACTION_ CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE ACCOUNTOWNER CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE TRANSAKCE CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE UCET CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE KLIENT CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE POBOCKA CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Zakladne tabulky
BEGIN EXECUTE IMMEDIATE 'DROP TABLE ACCOUNT_OWNER CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE BANK_TRANSACTION CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE AUTHORIZATION CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE ACCOUNT CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE CLIENT CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE EMPLOYEE CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE PERSON CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Sekvencie
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_person'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_account'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_authorization'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE seq_log'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Indexy
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_transaction_date'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_transaction_source'; EXCEPTION WHEN OTHERS THEN NULL; END;
/


-- =============================================================================
-- 2. Sekvencie
-- =============================================================================
CREATE SEQUENCE seq_person              START WITH 100 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_account             START WITH 100 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_authorization       START WITH 100 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_log                 START WITH 1   INCREMENT BY 1 NOCACHE NOCYCLE;


-- =============================================================================
-- 3. Tabulky (rovnake ako v casti 2 a 3)
-- =============================================================================

-- 3.1 PERSON
CREATE TABLE PERSON (
    person_id       NUMBER          NOT NULL,
    first_name      VARCHAR2(50)    NOT NULL,
    last_name       VARCHAR2(50)    NOT NULL,
    gender          CHAR(1),
    birth_date      DATE            NOT NULL,
    street          VARCHAR2(100),
    city            VARCHAR2(60),
    postal_code     VARCHAR2(10),
    phone           VARCHAR2(20),
    email           VARCHAR2(100),

    CONSTRAINT pk_person
        PRIMARY KEY (person_id),
    CONSTRAINT uq_person_email
        UNIQUE (email),
    CONSTRAINT chk_person_gender
        CHECK (gender IS NULL OR gender IN ('M', 'F')),
    CONSTRAINT chk_person_email
        CHECK (email IS NULL OR REGEXP_LIKE(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')),
    CONSTRAINT chk_person_phone
        CHECK (phone IS NULL OR REGEXP_LIKE(phone, '^\+?[0-9 ]{9,20}$')),
    CONSTRAINT chk_person_postal_code
        CHECK (postal_code IS NULL OR REGEXP_LIKE(postal_code, '^[0-9]{3} ?[0-9]{2}$'))
);

-- 3.2 CLIENT
CREATE TABLE CLIENT (
    client_id           NUMBER          NOT NULL,
    client_code         VARCHAR2(20)    NOT NULL,
    ico                 VARCHAR2(8),
    registration_date   DATE            NOT NULL,
    client_status       VARCHAR2(20)    DEFAULT 'ACTIVE' NOT NULL,

    CONSTRAINT pk_client
        PRIMARY KEY (client_id),
    CONSTRAINT fk_client_person
        FOREIGN KEY (client_id) REFERENCES PERSON(person_id) ON DELETE CASCADE,
    CONSTRAINT uq_client_code
        UNIQUE (client_code),
    CONSTRAINT chk_client_status
        CHECK (client_status IN ('ACTIVE', 'SUSPENDED', 'CLOSED')),
    CONSTRAINT chk_client_ico
        CHECK (ico IS NULL OR REGEXP_LIKE(ico, '^[0-9]{8}$'))
);

-- 3.3 EMPLOYEE
CREATE TABLE EMPLOYEE (
    employee_id         NUMBER          NOT NULL,
    employee_code       VARCHAR2(20)    NOT NULL,
    job_title           VARCHAR2(50)    NOT NULL,
    branch_name         VARCHAR2(100)   NOT NULL,
    employment_date     DATE            NOT NULL,

    CONSTRAINT pk_employee
        PRIMARY KEY (employee_id),
    CONSTRAINT fk_employee_person
        FOREIGN KEY (employee_id) REFERENCES PERSON(person_id) ON DELETE CASCADE,
    CONSTRAINT uq_employee_code
        UNIQUE (employee_code)
);

-- 3.4 ACCOUNT
CREATE TABLE ACCOUNT (
    account_id              NUMBER          NOT NULL,
    account_number          VARCHAR2(20)    NOT NULL,
    account_type            VARCHAR2(20)    NOT NULL,
    balance                 NUMBER(15,2)    DEFAULT 0 NOT NULL,
    currency_code           CHAR(3)         DEFAULT 'CZK' NOT NULL,
    opened_on               DATE            NOT NULL,
    created_by_employee_id  NUMBER          NOT NULL,

    CONSTRAINT pk_account
        PRIMARY KEY (account_id),
    CONSTRAINT uq_account_number
        UNIQUE (account_number),
    CONSTRAINT chk_account_number
        CHECK (REGEXP_LIKE(account_number, '^([0-9]{1,6}-)?[0-9]{2,10}/[0-9]{4}$')),
    CONSTRAINT chk_account_type
        CHECK (account_type IN ('CURRENT', 'SAVINGS', 'BUSINESS')),
    CONSTRAINT chk_account_balance
        CHECK (balance >= 0),
    CONSTRAINT chk_account_currency
        CHECK (currency_code IN ('CZK', 'EUR', 'USD')),
    CONSTRAINT fk_account_created_by
        FOREIGN KEY (created_by_employee_id) REFERENCES EMPLOYEE(employee_id)
);

-- 3.5 ACCOUNT_OWNER (M:N vztah medzi CLIENT a ACCOUNT)
CREATE TABLE ACCOUNT_OWNER (
    client_id       NUMBER  NOT NULL,
    account_id      NUMBER  NOT NULL,

    CONSTRAINT pk_account_owner
        PRIMARY KEY (client_id, account_id),
    CONSTRAINT fk_ao_client
        FOREIGN KEY (client_id)  REFERENCES CLIENT(client_id)   ON DELETE CASCADE,
    CONSTRAINT fk_ao_account
        FOREIGN KEY (account_id) REFERENCES ACCOUNT(account_id) ON DELETE CASCADE
);

-- 3.6 AUTHORIZATION
CREATE TABLE AUTHORIZATION (
    authorization_id        NUMBER          NOT NULL,
    account_id              NUMBER          NOT NULL,
    client_id               NUMBER          NOT NULL,
    authorization_type      VARCHAR2(20)    NOT NULL,
    authorized_limit        NUMBER(15,2),
    granted_on              DATE            NOT NULL,
    created_by_employee_id  NUMBER          NOT NULL,

    CONSTRAINT pk_authorization
        PRIMARY KEY (authorization_id),
    CONSTRAINT uq_authorization
        UNIQUE (account_id, client_id),
    CONSTRAINT chk_authorization_type
        CHECK (authorization_type IN ('DISPONENT', 'VIEW')),
    CONSTRAINT fk_authorization_account
        FOREIGN KEY (account_id)  REFERENCES ACCOUNT(account_id),
    CONSTRAINT fk_authorization_client
        FOREIGN KEY (client_id)   REFERENCES CLIENT(client_id),
    CONSTRAINT fk_authorization_employee
        FOREIGN KEY (created_by_employee_id) REFERENCES EMPLOYEE(employee_id)
);

-- 3.7 BANK_TRANSACTION
CREATE TABLE BANK_TRANSACTION (
    transaction_id              NUMBER          NOT NULL,
    transaction_type            VARCHAR2(20)    NOT NULL,
    amount                      NUMBER(15,2)    NOT NULL,
    transaction_date            DATE            NOT NULL,
    description                 VARCHAR2(200),
    iban                        VARCHAR2(34),
    source_account_id           NUMBER          NOT NULL,
    target_account_id           NUMBER,
    initiated_by_person_id      NUMBER          NOT NULL,
    executed_by_employee_id     NUMBER          NOT NULL,

    CONSTRAINT pk_bank_transaction
        PRIMARY KEY (source_account_id, transaction_id),
    CONSTRAINT chk_transaction_type
        CHECK (transaction_type IN ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER')),
    CONSTRAINT chk_transaction_amount
        CHECK (amount > 0),
    CONSTRAINT chk_transaction_accounts
        CHECK (
            (transaction_type IN ('DEPOSIT', 'WITHDRAWAL') AND target_account_id IS NULL)
            OR
            (transaction_type = 'TRANSFER'
                AND target_account_id IS NOT NULL
                AND target_account_id <> source_account_id)
        ),
    CONSTRAINT chk_transaction_iban
        CHECK (iban IS NULL OR REGEXP_LIKE(iban, '^[A-Z]{2}[0-9]{2}[A-Z0-9]{1,30}$')),
    CONSTRAINT fk_transaction_source
        FOREIGN KEY (source_account_id)       REFERENCES ACCOUNT(account_id),
    CONSTRAINT fk_transaction_target
        FOREIGN KEY (target_account_id)       REFERENCES ACCOUNT(account_id),
    CONSTRAINT fk_transaction_initiated_by
        FOREIGN KEY (initiated_by_person_id)  REFERENCES PERSON(person_id),
    CONSTRAINT fk_transaction_executed_by
        FOREIGN KEY (executed_by_employee_id) REFERENCES EMPLOYEE(employee_id)
);

-- 3.8 CLIENT_STATUS_LOG (nova tabulka pre logovaci trigger)
-- Uchovava historiu zmien statusu klienta.
CREATE TABLE CLIENT_STATUS_LOG (
    log_id          NUMBER          NOT NULL,
    client_id       NUMBER          NOT NULL,
    old_status      VARCHAR2(20),
    new_status      VARCHAR2(20)    NOT NULL,
    changed_on      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,

    CONSTRAINT pk_client_status_log
        PRIMARY KEY (log_id)
);


-- =============================================================================
-- 4. Triggre pre automaticke generovanie primarnych klucov
-- =============================================================================
CREATE OR REPLACE TRIGGER trg_person_bi
    BEFORE INSERT ON PERSON
    FOR EACH ROW
BEGIN
    IF :NEW.person_id IS NULL THEN
        :NEW.person_id := seq_person.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_account_bi
    BEFORE INSERT ON ACCOUNT
    FOR EACH ROW
BEGIN
    IF :NEW.account_id IS NULL THEN
        :NEW.account_id := seq_account.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_authorization_bi
    BEFORE INSERT ON AUTHORIZATION
    FOR EACH ROW
BEGIN
    IF :NEW.authorization_id IS NULL THEN
        :NEW.authorization_id := seq_authorization.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_bank_transaction_bi
    BEFORE INSERT ON BANK_TRANSACTION
    FOR EACH ROW
DECLARE
    v_next_id NUMBER;
BEGIN
    IF :NEW.transaction_id IS NULL THEN
        SELECT NVL(MAX(transaction_id), 0) + 1
        INTO v_next_id
        FROM BANK_TRANSACTION
        WHERE source_account_id = :NEW.source_account_id;
        :NEW.transaction_id := v_next_id;
    END IF;
END;
/


-- =============================================================================
-- 5. Ukazkove data (rovnake ako v casti 2 a 3)
-- =============================================================================

-- 5.1 PERSON
INSERT INTO PERSON (person_id, first_name, last_name, gender, birth_date, street, city, postal_code, phone, email)
VALUES (1, 'Jan',    'Novak',      'M', DATE '1985-04-12', 'Masarykova 12', 'Brno',    '602 00', '+420777111222', 'jan.novak@example.com');
INSERT INTO PERSON (person_id, first_name, last_name, gender, birth_date, street, city, postal_code, phone, email)
VALUES (2, 'Petra',  'Svobodova',  'F', DATE '1992-09-03', 'Ceska 5',      'Praha',   '110 00', '+420777333444', 'petra.svobodova@example.com');
INSERT INTO PERSON (person_id, first_name, last_name, gender, birth_date, street, city, postal_code, phone, email)
VALUES (3, 'Eva',    'Kralova',    'F', DATE '1980-02-01', 'Hlavni 18',    'Brno',    '616 00', '+420777555666', 'eva.kralova@banka.cz');
INSERT INTO PERSON (person_id, first_name, last_name, gender, birth_date, street, city, postal_code, phone, email)
VALUES (4, 'Martin', 'Dvorak',     'M', DATE '1978-11-21', 'Pionyrska 44', 'Ostrava', '700 30', '+420777888999', 'martin.dvorak@banka.cz');
INSERT INTO PERSON (person_id, first_name, last_name, gender, birth_date, street, city, postal_code, phone, email)
VALUES (5, 'Lucie',  'Horakova',   'F', DATE '1995-07-15', 'Lipova 3',     'Brno',    '603 00', '+420777000111', 'lucie.horakova@example.com');

-- 5.2 EMPLOYEE
INSERT INTO EMPLOYEE (employee_id, employee_code, job_title, branch_name, employment_date)
VALUES (3, 'EMP0001', 'BANKER',        'Brno-stred',      DATE '2020-05-01');
INSERT INTO EMPLOYEE (employee_id, employee_code, job_title, branch_name, employment_date)
VALUES (4, 'EMP0002', 'SENIOR_BANKER', 'Ostrava-centrum', DATE '2018-09-10');

-- 5.3 CLIENT
INSERT INTO CLIENT (client_id, client_code, ico, registration_date, client_status)
VALUES (1, 'CL0001', NULL,       DATE '2024-01-15', 'ACTIVE');
INSERT INTO CLIENT (client_id, client_code, ico, registration_date, client_status)
VALUES (2, 'CL0002', NULL,       DATE '2024-03-20', 'ACTIVE');
INSERT INTO CLIENT (client_id, client_code, ico, registration_date, client_status)
VALUES (5, 'CL0003', '12345678', DATE '2025-01-10', 'ACTIVE');

-- 5.4 ACCOUNT
INSERT INTO ACCOUNT (account_id, account_number, account_type, balance, currency_code, opened_on, created_by_employee_id)
VALUES (1, '19-2000145399/0800', 'CURRENT',  25000.00, 'CZK', DATE '2025-01-10', 3);
INSERT INTO ACCOUNT (account_id, account_number, account_type, balance, currency_code, opened_on, created_by_employee_id)
VALUES (2, '123456789/0300',     'SAVINGS',  80000.00, 'CZK', DATE '2025-02-05', 3);
INSERT INTO ACCOUNT (account_id, account_number, account_type, balance, currency_code, opened_on, created_by_employee_id)
VALUES (3, '43-9876543210/5500', 'BUSINESS', 150000.00, 'EUR', DATE '2025-02-20', 4);
INSERT INTO ACCOUNT (account_id, account_number, account_type, balance, currency_code, opened_on, created_by_employee_id)
VALUES (4, '987654321/0800',     'CURRENT',   5000.00, 'CZK', DATE '2025-03-01', 4);

-- 5.5 ACCOUNT_OWNER
INSERT INTO ACCOUNT_OWNER (client_id, account_id) VALUES (1, 1);
INSERT INTO ACCOUNT_OWNER (client_id, account_id) VALUES (1, 4);
INSERT INTO ACCOUNT_OWNER (client_id, account_id) VALUES (2, 2);
INSERT INTO ACCOUNT_OWNER (client_id, account_id) VALUES (2, 3);
INSERT INTO ACCOUNT_OWNER (client_id, account_id) VALUES (5, 4);

-- 5.6 AUTHORIZATION
INSERT INTO AUTHORIZATION (authorization_id, account_id, client_id, authorization_type, authorized_limit, granted_on, created_by_employee_id)
VALUES (NULL, 2, 1, 'DISPONENT', 10000.00, DATE '2025-02-25', 3);
INSERT INTO AUTHORIZATION (authorization_id, account_id, client_id, authorization_type, authorized_limit, granted_on, created_by_employee_id)
VALUES (NULL, 2, 5, 'VIEW',      NULL,     DATE '2025-03-01', 3);

-- 5.7 BANK_TRANSACTION
INSERT INTO BANK_TRANSACTION (transaction_id, transaction_type, amount, transaction_date, description, iban, source_account_id, target_account_id, initiated_by_person_id, executed_by_employee_id)
VALUES (NULL, 'DEPOSIT',    5000.00, DATE '2025-02-01', 'Hotovostny vklad na pobocke', NULL,                   1, NULL, 1, 3);
INSERT INTO BANK_TRANSACTION (transaction_id, transaction_type, amount, transaction_date, description, iban, source_account_id, target_account_id, initiated_by_person_id, executed_by_employee_id)
VALUES (NULL, 'WITHDRAWAL', 2000.00, DATE '2025-02-12', 'Vyber hotovosti',             NULL,                   1, NULL, 1, 3);
INSERT INTO BANK_TRANSACTION (transaction_id, transaction_type, amount, transaction_date, description, iban, source_account_id, target_account_id, initiated_by_person_id, executed_by_employee_id)
VALUES (NULL, 'TRANSFER',   3500.00, DATE '2025-03-01', 'Prevod medzi klientmi',       'CZ6508000000192000145399', 2, 1,    2, 4);
INSERT INTO BANK_TRANSACTION (transaction_id, transaction_type, amount, transaction_date, description, iban, source_account_id, target_account_id, initiated_by_person_id, executed_by_employee_id)
VALUES (NULL, 'DEPOSIT',   10000.00, DATE '2025-03-05', 'Vklad na firemny ucet',       NULL,                   3, NULL, 2, 4);
INSERT INTO BANK_TRANSACTION (transaction_id, transaction_type, amount, transaction_date, description, iban, source_account_id, target_account_id, initiated_by_person_id, executed_by_employee_id)
VALUES (NULL, 'TRANSFER',   1000.00, DATE '2025-03-10', 'Prevod na spolocny ucet',     'CZ6508000000192000145399', 1, 4,    1, 3);

COMMIT;


-- =============================================================================
-- =============================================================================
--
--   POKROCILE OBJEKTY SCHEMY DATABAZY  (4. cast projektu)
--
-- =============================================================================
-- =============================================================================


-- =============================================================================
-- 6. Netrivialne databazove triggre
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 6.1 Trigger: trg_check_balance_before_withdrawal
-- -----------------------------------------------------------------------------
-- Pred vlozenim transakcie typu WITHDRAWAL alebo TRANSFER skontroluje,
-- ci na zdrojovom ucte je dostatocny zostatok. Ak nie, vyhlasi chybu
-- a transakciu nedovoli vlozit.
--
-- Toto je netrivialny trigger, pretoze:
--   - pristupuje k inej tabulke (ACCOUNT),
--   - obsahuje podmienenu logiku (rozlisenie typu transakcie),
--   - aktivne brani vlozeniu zaznamu pri nesplneni obchodneho pravidla.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_check_balance_before_withdrawal
    BEFORE INSERT ON BANK_TRANSACTION
    FOR EACH ROW
DECLARE
    v_balance ACCOUNT.balance%TYPE;
BEGIN
    -- Kontrolujeme iba vybery a prevody (vklady zostatok neznizuju)
    IF :NEW.transaction_type IN ('WITHDRAWAL', 'TRANSFER') THEN
        SELECT balance
        INTO   v_balance
        FROM   ACCOUNT
        WHERE  account_id = :NEW.source_account_id;

        IF v_balance < :NEW.amount THEN
            RAISE_APPLICATION_ERROR(-20001,
                'Nedostatocny zostatok na ucte ' || :NEW.source_account_id
                || '. Pozadovana suma: ' || :NEW.amount
                || ', dostupny zostatok: ' || v_balance);
        END IF;
    END IF;
END;
/


-- -----------------------------------------------------------------------------
-- 6.2 Trigger: trg_log_client_status_change
-- -----------------------------------------------------------------------------
-- Po zmene stlpca client_status v tabulke CLIENT automaticky vlozi zaznam
-- do logovacej tabulky CLIENT_STATUS_LOG.
--
-- Toto je netrivialny trigger, pretoze:
--   - reaguje na UPDATE konkretneho stlpca,
--   - zapisuje do inej tabulky (CLIENT_STATUS_LOG),
--   - pouziva :OLD a :NEW pre porovnanie hodnot.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_log_client_status_change
    AFTER UPDATE OF client_status ON CLIENT
    FOR EACH ROW
BEGIN
    IF :OLD.client_status <> :NEW.client_status THEN
        INSERT INTO CLIENT_STATUS_LOG (log_id, client_id, old_status, new_status, changed_on)
        VALUES (seq_log.NEXTVAL, :NEW.client_id, :OLD.client_status, :NEW.client_status, SYSTIMESTAMP);
    END IF;
END;
/


-- -----------------------------------------------------------------------------
-- 6.3 Predvedenie triggerov
-- -----------------------------------------------------------------------------

-- 6.3.1 Predvedenie trg_check_balance_before_withdrawal
-- Pokus o vyber 999999 CZK z uctu 1 (zostatok 25000) – musi zlyhat
-- Predtym zapneme SERVEROUTPUT na zobrazenie hlasok
SET SERVEROUTPUT ON;

BEGIN
    INSERT INTO BANK_TRANSACTION (transaction_id, transaction_type, amount, transaction_date,
        description, iban, source_account_id, target_account_id,
        initiated_by_person_id, executed_by_employee_id)
    VALUES (NULL, 'WITHDRAWAL', 999999.00, DATE '2025-04-01',
        'Pokus o prilis velky vyber', NULL, 1, NULL, 1, 3);

    DBMS_OUTPUT.PUT_LINE('CHYBA: Transakcia bola vlozena, ale nemala byt!');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('OK: Trigger zablokovol transakciu: ' || SQLERRM);
END;
/

-- Overenie: vyber 100 CZK z uctu 1 – musi prejst (zostatok je dostatocny)
INSERT INTO BANK_TRANSACTION (transaction_id, transaction_type, amount, transaction_date,
    description, iban, source_account_id, target_account_id,
    initiated_by_person_id, executed_by_employee_id)
VALUES (NULL, 'WITHDRAWAL', 100.00, DATE '2025-04-02',
    'Bezny vyber hotovosti', NULL, 1, NULL, 1, 3);


-- 6.3.2 Predvedenie trg_log_client_status_change
-- Zmenime status klienta 1 z ACTIVE na SUSPENDED
UPDATE CLIENT SET client_status = 'SUSPENDED' WHERE client_id = 1;
-- Zmenime spat na ACTIVE
UPDATE CLIENT SET client_status = 'ACTIVE'    WHERE client_id = 1;

-- Zobrazenie logu zmien
SELECT * FROM CLIENT_STATUS_LOG ORDER BY log_id;


-- =============================================================================
-- 7. Netrivialne ulozene procedury
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 7.1 Procedura: proc_client_report
-- -----------------------------------------------------------------------------
-- Vypise prehlad vsetkych klientov a ich uctov.
-- Pre kazdeho klienta vypise meno, status, pocet uctov a celkovy zostatok.
--
-- Pouzite prvky:
--   - kurzor (CURSOR) – iterujeme cez zoznam klientov,
--   - %TYPE  – premenna v_client_id je naviazana na typ stlpca CLIENT.client_id,
--   - %ROWTYPE – premenna v_person je naviazana na riadok tabulky PERSON,
--   - osetrenie vynimky (EXCEPTION) – ak sa nenajde osoba k danemu klientovi.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE proc_client_report
AS
    CURSOR cur_clients IS
        SELECT client_id, client_code, client_status
        FROM   CLIENT
        ORDER BY client_id;

    v_client_id     CLIENT.client_id%TYPE;
    v_client_code   CLIENT.client_code%TYPE;
    v_client_status CLIENT.client_status%TYPE;
    v_person        PERSON%ROWTYPE;
    v_pocet_uctov   NUMBER;
    v_celkovy_zost  NUMBER(15,2);
BEGIN
    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('        PREHLAD KLIENTOV BANKY          ');
    DBMS_OUTPUT.PUT_LINE('========================================');

    OPEN cur_clients;
    LOOP
        FETCH cur_clients INTO v_client_id, v_client_code, v_client_status;
        EXIT WHEN cur_clients%NOTFOUND;

        -- Nacitame osobne udaje klienta z tabulky PERSON
        BEGIN
            SELECT * INTO v_person
            FROM   PERSON
            WHERE  person_id = v_client_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                DBMS_OUTPUT.PUT_LINE('Klient ' || v_client_id || ': osobne udaje nenajdene!');
                CONTINUE;
        END;

        -- Pocet uctov a celkovy zostatok klienta
        SELECT COUNT(a.account_id), NVL(SUM(a.balance), 0)
        INTO   v_pocet_uctov, v_celkovy_zost
        FROM   ACCOUNT_OWNER ao
        JOIN   ACCOUNT a ON a.account_id = ao.account_id
        WHERE  ao.client_id = v_client_id;

        DBMS_OUTPUT.PUT_LINE('----------------------------------------');
        DBMS_OUTPUT.PUT_LINE('Klient:  ' || v_person.first_name || ' ' || v_person.last_name
                             || ' (' || v_client_code || ')');
        DBMS_OUTPUT.PUT_LINE('Status:  ' || v_client_status);
        DBMS_OUTPUT.PUT_LINE('Email:   ' || NVL(v_person.email, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Uctov:   ' || v_pocet_uctov);
        DBMS_OUTPUT.PUT_LINE('Zostatok: ' || TO_CHAR(v_celkovy_zost, '999G999G999D00'));
    END LOOP;
    CLOSE cur_clients;

    DBMS_OUTPUT.PUT_LINE('========================================');
    DBMS_OUTPUT.PUT_LINE('             Koniec reportu.            ');
    DBMS_OUTPUT.PUT_LINE('========================================');
END;
/

-- Predvedenie procedury proc_client_report
SET SERVEROUTPUT ON;
EXEC proc_client_report;


-- -----------------------------------------------------------------------------
-- 7.2 Procedura: proc_transfer_money
-- -----------------------------------------------------------------------------
-- Realizuje prevod penazi medzi dvoma uctami.
-- Skontroluje existenciu uctov, dostatocny zostatok, aktualizuje zostatky
-- a vlozi zaznam do tabulky BANK_TRANSACTION.
--
-- Pouzite prvky:
--   - %TYPE – parametre a lokalne premenne su naviazane na typy stlpcov,
--   - osetrenie vynimky (EXCEPTION) – zachytava neexistujuci ucet, nedostatok,
--   - kurzor (implicitny SELECT INTO).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE proc_transfer_money (
    p_source_id     IN ACCOUNT.account_id%TYPE,
    p_target_id     IN ACCOUNT.account_id%TYPE,
    p_amount        IN BANK_TRANSACTION.amount%TYPE,
    p_description   IN BANK_TRANSACTION.description%TYPE,
    p_person_id     IN PERSON.person_id%TYPE,
    p_employee_id   IN EMPLOYEE.employee_id%TYPE
)
AS
    v_source_balance ACCOUNT.balance%TYPE;
    v_target_balance ACCOUNT.balance%TYPE;
    e_insufficient   EXCEPTION;
    e_same_account   EXCEPTION;
BEGIN
    -- Kontrola: zdrojovy a cielovy ucet nesmie byt rovnaky
    IF p_source_id = p_target_id THEN
        RAISE e_same_account;
    END IF;

    -- Nacitame zostatok zdrojoveho uctu
    BEGIN
        SELECT balance INTO v_source_balance
        FROM   ACCOUNT
        WHERE  account_id = p_source_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20010, 'Zdrojovy ucet ' || p_source_id || ' neexistuje.');
    END;

    -- Nacitame zostatok cieloveho uctu (overenie existencie)
    BEGIN
        SELECT balance INTO v_target_balance
        FROM   ACCOUNT
        WHERE  account_id = p_target_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20011, 'Cielovy ucet ' || p_target_id || ' neexistuje.');
    END;

    -- Kontrola dostatocneho zostatku
    IF v_source_balance < p_amount THEN
        RAISE e_insufficient;
    END IF;

    -- Aktualizacia zostatkov
    UPDATE ACCOUNT SET balance = balance - p_amount WHERE account_id = p_source_id;
    UPDATE ACCOUNT SET balance = balance + p_amount WHERE account_id = p_target_id;

    -- Vlozenie zaznamu o transakcii
    INSERT INTO BANK_TRANSACTION (transaction_id, transaction_type, amount, transaction_date,
        description, iban, source_account_id, target_account_id,
        initiated_by_person_id, executed_by_employee_id)
    VALUES (NULL, 'TRANSFER', p_amount, SYSDATE,
        p_description, NULL, p_source_id, p_target_id, p_person_id, p_employee_id);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Prevod ' || p_amount || ' z uctu ' || p_source_id
                         || ' na ucet ' || p_target_id || ' bol uspesny.');

EXCEPTION
    WHEN e_insufficient THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('CHYBA: Nedostatocny zostatok na ucte ' || p_source_id
                             || '. Zostatok: ' || v_source_balance || ', pozadovana suma: ' || p_amount);
    WHEN e_same_account THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('CHYBA: Zdrojovy a cielovy ucet su rovnake (' || p_source_id || ').');
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('CHYBA: ' || SQLERRM);
END;
/

-- Predvedenie procedury proc_transfer_money

-- Uspesny prevod 500 CZK z uctu 1 na ucet 4
SET SERVEROUTPUT ON;
EXEC proc_transfer_money(1, 4, 500, 'Testovaci prevod cez proceduru', 1, 3);

-- Overenie zostatkov po prevode
SELECT account_id, account_number, balance FROM ACCOUNT WHERE account_id IN (1, 4);

-- Neuspesny prevod – nedostatocny zostatok
EXEC proc_transfer_money(4, 1, 999999, 'Pokus o velky prevod', 1, 3);

-- Neuspesny prevod – rovnaky ucet
EXEC proc_transfer_money(1, 1, 100, 'Prevod sam na seba', 1, 3);


-- =============================================================================
-- 8. EXPLAIN PLAN a Index
-- =============================================================================
-- Dotaz: Pre kazdy zdrojovy ucet spocitame pocet transakcii a celkovu sumu
-- za urcite obdobie. Spojenie BANK_TRANSACTION a ACCOUNT, GROUP BY, SUM, COUNT.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 8.1 EXPLAIN PLAN – BEZ indexu
-- -----------------------------------------------------------------------------
-- Najprv spustime EXPLAIN PLAN na dotaz bez akehokolvek doplnujuceho indexu.
-- Cielom je vidiet, ako Oracle pristupuje k datam (typicky FULL TABLE SCAN).
-- -----------------------------------------------------------------------------
EXPLAIN PLAN FOR
    SELECT
        a.account_id,
        a.account_number,
        COUNT(bt.transaction_id)    AS pocet_transakcii,
        SUM(bt.amount)              AS celkova_suma
    FROM BANK_TRANSACTION bt
    JOIN ACCOUNT a
        ON a.account_id = bt.source_account_id
    WHERE bt.transaction_date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
    GROUP BY a.account_id, a.account_number;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);


-- -----------------------------------------------------------------------------
-- 8.2 Vytvorenie indexu
-- -----------------------------------------------------------------------------
-- Vytvarame kompozitny index na stlpcoch (source_account_id, transaction_date)
-- v tabulke BANK_TRANSACTION. Tento index pomaha:
--   1. Rychlejsie najst transakcie podla zdrojoveho uctu (JOIN podmienka),
--   2. Rychlejsie filtrovat podla datumu (WHERE podmienka),
--   3. Potencialne umoznit INDEX RANGE SCAN namiesto FULL TABLE SCAN.
--
-- Poradie stlpcov v indexe je dolezite:
--   - source_account_id je na prvom mieste, lebo je pouzity v JOIN podmienke,
--   - transaction_date je na druhom mieste pre dodatocne filtrovanie.
-- -----------------------------------------------------------------------------
CREATE INDEX idx_transaction_source_date ON BANK_TRANSACTION(source_account_id, transaction_date);


-- -----------------------------------------------------------------------------
-- 8.3 EXPLAIN PLAN – S indexom
-- -----------------------------------------------------------------------------
-- Zopakujeme EXPLAIN PLAN na rovnaky dotaz a porovname s predchadzajucim.
-- Ocakavame, ze Oracle namiesto FULL TABLE SCAN pouzije INDEX RANGE SCAN
-- na novovytvoreny index idx_transaction_source_date.
-- -----------------------------------------------------------------------------
EXPLAIN PLAN FOR
    SELECT
        a.account_id,
        a.account_number,
        COUNT(bt.transaction_id)    AS pocet_transakcii,
        SUM(bt.amount)              AS celkova_suma
    FROM BANK_TRANSACTION bt
    JOIN ACCOUNT a
        ON a.account_id = bt.source_account_id
    WHERE bt.transaction_date BETWEEN DATE '2025-01-01' AND DATE '2025-12-31'
    GROUP BY a.account_id, a.account_number;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);


-- =============================================================================
-- 9. Pristupove prava pre druheho clena tymu
-- =============================================================================
-- Prvy clen tymu (xgulasa00) udeluje pristupove prava druhemu clenovi
-- tymu (xfackas00) k tabulkam definovanym prvym clenom.
--
-- Prava zahrnaju SELECT (citanie), INSERT, UPDATE a DELETE na zakladne tabulky.
-- =============================================================================

GRANT ALL ON PERSON           TO xfackas00;
GRANT ALL ON CLIENT           TO xfackas00;
GRANT ALL ON EMPLOYEE         TO xfackas00;
GRANT ALL ON ACCOUNT          TO xfackas00;
GRANT ALL ON ACCOUNT_OWNER    TO xfackas00;
GRANT ALL ON AUTHORIZATION    TO xfackas00;
GRANT ALL ON BANK_TRANSACTION TO xfackas00;
GRANT ALL ON CLIENT_STATUS_LOG TO xfackas00;

-- Udelenie prava na sekvencie
GRANT SELECT ON seq_person        TO xfackas00;
GRANT SELECT ON seq_account       TO xfackas00;
GRANT SELECT ON seq_authorization TO xfackas00;
GRANT SELECT ON seq_log           TO xfackas00;


-- =============================================================================
-- 10. Materializovany pohlad
-- =============================================================================
-- Materializovany pohlad patri druhemu clenovi tymu (xfackas00) a pouziva
-- tabulky definovane prvym clenom tymu (xgulasa00).
--
-- Pohlad zobrazuje prehlad klientov: meno, pocet uctov, celkovy zostatok
-- a pocet transakcii. Toto je uzitocne pre rychle analyticky dotazy,
-- pretoze data su predpocitane a netreba ich vzdy pocitat cez JOINy.
--
-- POZNAMKA: Tento prikaz musi spustit xfackas00 na svojom ucte,
-- pripadne moze byt spusteny prvym clenom s komentarom.
-- =============================================================================

-- Ak sa skript spusta pod xgulasa00, nasledujuci prikaz vytvori MV pod jeho uctom.
-- Na obhajobe sa da predviest, ze xfackas00 pristupuje k datam cez tento pohlad.
CREATE MATERIALIZED VIEW mv_client_account_summary
BUILD IMMEDIATE
REFRESH ON DEMAND
AS
    SELECT
        c.client_id,
        p.first_name || ' ' || p.last_name  AS client_name,
        c.client_status,
        COUNT(DISTINCT ao.account_id)        AS pocet_uctov,
        NVL(SUM(DISTINCT a.balance), 0)      AS celkovy_zostatok,
        COUNT(bt.transaction_id)             AS pocet_transakcii
    FROM CLIENT c
    JOIN PERSON p
        ON p.person_id = c.client_id
    LEFT JOIN ACCOUNT_OWNER ao
        ON ao.client_id = c.client_id
    LEFT JOIN ACCOUNT a
        ON a.account_id = ao.account_id
    LEFT JOIN BANK_TRANSACTION bt
        ON bt.source_account_id = a.account_id
    GROUP BY c.client_id, p.first_name, p.last_name, c.client_status;

-- Zobrazenie dat z materializovaneho pohladu
SELECT * FROM mv_client_account_summary ORDER BY client_id;

-- Priklad: Po vlozeni novych dat sa MV neaktualizuje automaticky (REFRESH ON DEMAND).
-- Musime ho explicitne obnovit:
-- (Najprv vlozime novy ucet pre existujuceho klienta)
INSERT INTO ACCOUNT (account_id, account_number, account_type, balance, currency_code, opened_on, created_by_employee_id)
VALUES (50, '111222333/0800', 'SAVINGS', 42000.00, 'CZK', DATE '2025-04-01', 3);

INSERT INTO ACCOUNT_OWNER (client_id, account_id) VALUES (1, 50);

-- MV este ukazuje stare data (pred pridanim uctu):
SELECT client_name, pocet_uctov, celkovy_zostatok
FROM mv_client_account_summary WHERE client_id = 1;

-- Obnovime materializovany pohlad
BEGIN
    DBMS_MVIEW.REFRESH('mv_client_account_summary');
END;
/

-- Teraz MV ukazuje aktualne data (pocet_uctov a celkovy_zostatok sa zvysili):
SELECT client_name, pocet_uctov, celkovy_zostatok
FROM mv_client_account_summary WHERE client_id = 1;


-- =============================================================================
-- 11. Komplexny SELECT s WITH a CASE
-- =============================================================================
-- Dotaz ziskava prehlad klientov banky s kategorizaciou podla celkoveho
-- zostatku na ich uctoch. Kazdy klient je zaradeny do kategorie:
--   - 'VIP'       ak je celkovy zostatok >= 100 000,
--   - 'STANDARD'  ak je celkovy zostatok >= 10 000 a < 100 000,
--   - 'BASIC'     ak je celkovy zostatok < 10 000,
--   - 'ZIADNE_UCTY' ak klient nema ziaden ucet.
--
-- CTE (WITH) pouzivame na vypocet agregovanych udajov o uctoch klienta,
-- CASE pouzivame na kategorizaciu klienta podla zostatku.
-- =============================================================================
WITH client_balances AS (
    SELECT
        c.client_id,
        p.first_name || ' ' || p.last_name AS client_name,
        c.client_status,
        COUNT(ao.account_id)               AS pocet_uctov,
        NVL(SUM(a.balance), 0)             AS celkovy_zostatok
    FROM CLIENT c
    JOIN PERSON p
        ON p.person_id = c.client_id
    LEFT JOIN ACCOUNT_OWNER ao
        ON ao.client_id = c.client_id
    LEFT JOIN ACCOUNT a
        ON a.account_id = ao.account_id
    GROUP BY c.client_id, p.first_name, p.last_name, c.client_status
)
SELECT
    client_id,
    client_name,
    client_status,
    pocet_uctov,
    celkovy_zostatok,
    CASE
        WHEN pocet_uctov = 0               THEN 'ZIADNE_UCTY'
        WHEN celkovy_zostatok >= 100000    THEN 'VIP'
        WHEN celkovy_zostatok >= 10000     THEN 'STANDARD'
        ELSE                                    'BASIC'
    END AS kategoria_klienta
FROM client_balances
ORDER BY celkovy_zostatok DESC;


-- =============================================================================
-- Koniec skriptu (4. cast)
-- =============================================================================