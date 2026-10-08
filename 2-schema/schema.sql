-- =============================================================================
-- Tema 27: Banka
-- Cast 2: SQL skript pre vytvorenie objektov schemy databazy
-- Autori: xgulasa00, xfackas00
-- SRBD: Oracle 12c
-- Kodovanie: UTF-8
--
-- Skript sa da spustit opakovane.
-- Na zaciatku odstranime existujuce objekty a potom ich vytvorime znova.
-- =============================================================================
--
--
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
-- Tato cast je potrebna na to, aby bol skrip spustitelny viac krat za sebou.
-- Ak objekt neexistuje, chyba sa ignoruje a pokracuje sa dalej.
-- Niektore DROP prikazy su tu zanechane kvoli predchadzajucim verziam.
-- =============================================================================

-- Stare tabulky z predchadzajucich pokusov
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE TRANSACTION_ CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE ACCOUNTOWNER CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE TRANSAKCE CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE UCET CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE KLIENT CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE POBOCKA CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TRIGGER trg_bank_transaction_bi';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TRIGGER trg_person_bi';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TRIGGER trg_account_bi';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TRIGGER trg_authorization_bi';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE ACCOUNT_OWNER CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE BANK_TRANSACTION CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE AUTHORIZATION CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE ACCOUNT CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE CLIENT CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE EMPLOYEE CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE PERSON CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_person';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_account';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_authorization';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_bank_transaction';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/


-- =============================================================================
-- 2. Sekvencie
-- =============================================================================
-- Sekvencie pre generovanie identifikatorov.
-- Neskor na ne nadviazu triggre, ktore doplnia ID automaticky pri vkladani,
-- ak nebude zadane manualne.
-- =============================================================================
CREATE SEQUENCE seq_person              START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_account             START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_authorization       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE seq_bank_transaction    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;


-- =============================================================================
-- 3. Tabulky
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 3.1 PERSON
-- -----------------------------------------------------------------------------
-- Tabulka PERSON predstavuje vseobecnu osobu v systeme.
-- Ukladaju sa sem udaje, ktore su spolocne pre klientov aj zamestnancov.
-- -----------------------------------------------------------------------------
CREATE TABLE PERSON (
    person_id       NUMBER          NOT NULL,
    first_name      VARCHAR2(50)    NOT NULL,
    last_name       VARCHAR2(50)    NOT NULL,
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
    CONSTRAINT chk_person_email -- Kontrola zakladneho formatu e-mailu
        CHECK (email IS NULL OR REGEXP_LIKE(email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')),
    CONSTRAINT chk_person_phone -- Telefon moze obsahovat aj znak + a medzery
        CHECK (phone IS NULL OR REGEXP_LIKE(phone, '^\+?[0-9 ]{9,20}$')),
    CONSTRAINT chk_person_postal_code -- PSC vo formate 60200 alebo 602 00
        CHECK (postal_code IS NULL OR REGEXP_LIKE(postal_code, '^[0-9]{3} ?[0-9]{2}$'))
);

-- -----------------------------------------------------------------------------
-- 3.2 CLIENT
-- -----------------------------------------------------------------------------
-- Tabulka CLIENT predstavuje klienta banky.
-- Nadvazuje na PERSON, pretoze klient je podtyp osoby.
-- -----------------------------------------------------------------------------
CREATE TABLE CLIENT (
    client_id           NUMBER          NOT NULL,
    client_code         VARCHAR2(20)    NOT NULL,
    registration_date   DATE            NOT NULL,
    client_status       VARCHAR2(20)    DEFAULT 'ACTIVE' NOT NULL,

    CONSTRAINT pk_client
        PRIMARY KEY (client_id),
    CONSTRAINT fk_client_person
        FOREIGN KEY (client_id) REFERENCES PERSON(person_id) ON DELETE CASCADE,
    CONSTRAINT uq_client_code
        UNIQUE (client_code),
    CONSTRAINT chk_client_status
        CHECK (client_status IN ('ACTIVE', 'SUSPENDED', 'CLOSED'))
);

-- -----------------------------------------------------------------------------
-- 3.3 EMPLOYEE
-- -----------------------------------------------------------------------------
-- Tabulka EMPLOYEE predstavuje zamestnanca banky.
-- Tiez ide o specializaciu tabulky PERSON.
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- 3.4 ACCOUNT
-- -----------------------------------------------------------------------------
-- Tabulka ACCOUNT reprezentuje bankovy ucet.
-- Obsahuje zakladne informacie o danom ucte, jeho mene, zostatku a o tom,
-- ktory zamestnanec ucet vytvoril.
--
-- Cislo uctu ma obmedzeny format.
-- Povoleny tvar je [prefix-]cislo/kodbanky.
-- Tento CHECK sme pridali, aby databaza nepovolila lubovolny retazec.
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- 3.5 ACCOUNT_OWNER
-- -----------------------------------------------------------------------------
-- Tabulka ACCOUNT_OWNER vyjadruje vztah vlastnictva medzi klientom a uctom.
-- Zvolili sme samostatnu tabulku, pretoze ide o vztah M:N.
-- Jeden klient moze mat viac uctov a jeden ucet moze mat aj viac vlastnikov.
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- 3.6 AUTHORIZATION
-- -----------------------------------------------------------------------------
-- Tabulka AUTHORIZATION uchovava opravnenia klientov k uctom.
-- Ide napriklad o vlastnika, disponenta alebo iba pravo na nahliadanie.
-- Zaroven sa eviduje, ktory zamestnanec dane opravnenie vytvoril.
--
-- Jeden klient moze mat k jednemu uctu len jedno opravnenie
-- -----------------------------------------------------------------------------
CREATE TABLE AUTHORIZATION (
    authorization_id        NUMBER          NOT NULL,
    account_id              NUMBER          NOT NULL,
    client_id               NUMBER          NOT NULL,
    authorization_type      VARCHAR2(20)    NOT NULL,
    granted_on              DATE            NOT NULL,
    created_by_employee_id  NUMBER          NOT NULL,

    CONSTRAINT pk_authorization
        PRIMARY KEY (authorization_id),
    CONSTRAINT uq_authorization
        UNIQUE (account_id, client_id),
    CONSTRAINT chk_authorization_type
        CHECK (authorization_type IN ('OWNER', 'DISPONENT', 'VIEW')),
    CONSTRAINT fk_authorization_account
        FOREIGN KEY (account_id)  REFERENCES ACCOUNT(account_id),
    CONSTRAINT fk_authorization_client
        FOREIGN KEY (client_id)   REFERENCES CLIENT(client_id),
    CONSTRAINT fk_authorization_employee
        FOREIGN KEY (created_by_employee_id) REFERENCES EMPLOYEE(employee_id)
);

-- -----------------------------------------------------------------------------
-- 3.7 BANK_TRANSACTION
-- -----------------------------------------------------------------------------
-- Tabulka BANK_TRANSACTION uchovava jednotlive transakcie.
-- Ku kazdej transakcii sa eviduje typ, suma, datum, zdrojovy ucet.
-- Dalej cielovy ucet, osobu, ktora transakciu iniciovala, a zamestnanca,
-- ktory ju vykonal.
--
-- Pomocou CHECK obmedzenia sa rozlisuje:
--   - vklad a vyber - potom cielovy ucet je NULL,
--   - prevod - potom cielovy ucet musi byt zadany a musi byt iny ako zdrojovy.
-- -----------------------------------------------------------------------------
CREATE TABLE BANK_TRANSACTION (
    transaction_id              NUMBER          NOT NULL,
    transaction_type            VARCHAR2(20)    NOT NULL,
    amount                      NUMBER(15,2)    NOT NULL,
    transaction_date            DATE            NOT NULL,
    description                 VARCHAR2(200),
    source_account_id           NUMBER          NOT NULL,
    target_account_id           NUMBER,
    initiated_by_person_id      NUMBER          NOT NULL,
    executed_by_employee_id     NUMBER          NOT NULL,

    CONSTRAINT pk_bank_transaction
        PRIMARY KEY (transaction_id),
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
    CONSTRAINT fk_transaction_source
        FOREIGN KEY (source_account_id)       REFERENCES ACCOUNT(account_id),
    CONSTRAINT fk_transaction_target
        FOREIGN KEY (target_account_id)       REFERENCES ACCOUNT(account_id),
    CONSTRAINT fk_transaction_initiated_by
        FOREIGN KEY (initiated_by_person_id)  REFERENCES PERSON(person_id),
    CONSTRAINT fk_transaction_executed_by
        FOREIGN KEY (executed_by_employee_id) REFERENCES EMPLOYEE(employee_id)
);


-- =============================================================================
-- 4. Triggre pre automaticke generovanie primarnych klucov
-- =============================================================================
-- Ak pri INSERTe nebude zadane ID, trigger doplni hodnotu zo sekvencie.
-- Tuto poziadavku ma zadanie explicitne uvedenu aspon pre jednu tabulku,
-- my ju takto riesime pre viacero tabuliek.
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
BEGIN
    IF :NEW.transaction_id IS NULL THEN
        :NEW.transaction_id := seq_bank_transaction.NEXTVAL;
    END IF;
END;
/


-- =============================================================================
-- 5. Ukazkove data
-- =============================================================================
-- Vkladame zakladne testovacie data, aby bolo mozne overit funkcnost vytvarania
-- tabuliek, vztahov a integritnych obmedzeni.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 5.1 PERSON
-- -----------------------------------------------------------------------------
-- Osoby 1 a 2 budu klienti, osoby 3 a 4 budu zamestnanci.
-- Osoba 5 bude dalsi klient.
-- ------------------------------------------------------------------------------
INSERT INTO PERSON (person_id, first_name, last_name, birth_date, street, city, postal_code, phone, email)
VALUES (1, 'Jan',    'Novak',      DATE '1985-04-12', 'Masarykova 12', 'Brno',    '602 00', '+420777111222', 'jan.novak@example.com');

INSERT INTO PERSON (person_id, first_name, last_name, birth_date, street, city, postal_code, phone, email)
VALUES (2, 'Petra',  'Svobodova',  DATE '1992-09-03', 'Ceska 5',      'Praha',   '110 00', '+420777333444', 'petra.svobodova@example.com');

INSERT INTO PERSON (person_id, first_name, last_name, birth_date, street, city, postal_code, phone, email)
VALUES (3, 'Eva',    'Kralova',    DATE '1980-02-01', 'Hlavni 18',    'Brno',    '616 00', '+420777555666', 'eva.kralova@banka.cz');

INSERT INTO PERSON (person_id, first_name, last_name, birth_date, street, city, postal_code, phone, email)
VALUES (4, 'Martin', 'Dvorak',     DATE '1978-11-21', 'Pionyrska 44', 'Ostrava', '700 30', '+420777888999', 'martin.dvorak@banka.cz');

INSERT INTO PERSON (person_id, first_name, last_name, birth_date, street, city, postal_code, phone, email)
VALUES (5, 'Lucie',  'Horakova',   DATE '1995-07-15', 'Lipova 3',     'Brno',    '603 00', '+420777000111', 'lucie.horakova@example.com');

-- -----------------------------------------------------------------------------
-- 5.2 EMPLOYEE
-- -----------------------------------------------------------------------------
-- Zamestnanci banky
-- -----------------------------------------------------------------------------
INSERT INTO EMPLOYEE (employee_id, employee_code, job_title, branch_name, employment_date)
VALUES (3, 'EMP0001', 'BANKER',        'Brno-stred',      DATE '2020-05-01');

INSERT INTO EMPLOYEE (employee_id, employee_code, job_title, branch_name, employment_date)
VALUES (4, 'EMP0002', 'SENIOR_BANKER', 'Ostrava-centrum', DATE '2018-09-10');

-- -----------------------------------------------------------------------------
-- 5.3 CLIENT
-- -----------------------------------------------------------------------------
-- Klienti banky
-- -----------------------------------------------------------------------------
INSERT INTO CLIENT (client_id, client_code, registration_date, client_status)
VALUES (1, 'CL0001', DATE '2024-01-15', 'ACTIVE');

INSERT INTO CLIENT (client_id, client_code, registration_date, client_status)
VALUES (2, 'CL0002', DATE '2024-03-20', 'ACTIVE');

INSERT INTO CLIENT (client_id, client_code, registration_date, client_status)
VALUES (5, 'CL0003', DATE '2025-01-10', 'ACTIVE');

-- -----------------------------------------------------------------------------
-- 5.4 ACCOUNT
-- -----------------------------------------------------------------------------
-- Ukazkove ucty v roznych menach a typoch
-- -----------------------------------------------------------------------------
INSERT INTO ACCOUNT (account_id, account_number, account_type, balance, currency_code, opened_on, created_by_employee_id)
VALUES (1, '19-2000145399/0800', 'CURRENT',  25000.00, 'CZK', DATE '2025-01-10', 3);

INSERT INTO ACCOUNT (account_id, account_number, account_type, balance, currency_code, opened_on, created_by_employee_id)
VALUES (2, '123456789/0300',     'SAVINGS',  80000.00, 'CZK', DATE '2025-02-05', 3);

INSERT INTO ACCOUNT (account_id, account_number, account_type, balance, currency_code, opened_on, created_by_employee_id)
VALUES (3, '43-9876543210/5500', 'BUSINESS', 150000.00, 'EUR', DATE '2025-02-20', 4);

INSERT INTO ACCOUNT (account_id, account_number, account_type, balance, currency_code, opened_on, created_by_employee_id)
VALUES (4, '987654321/0800',     'CURRENT',   5000.00, 'CZK', DATE '2025-03-01', 4);

-- -----------------------------------------------------------------------------
-- 5.5 ACCOUNT_OWNER
-- -----------------------------------------------------------------------------
-- Vlastnictvo uctov
-- Klient 1 vlastni ucty 1 a 4
-- Klient 2 vlastni ucty 2 a 3
-- Klient 5 je spoluvlastnik uctu 4
-- -----------------------------------------------------------------------------
INSERT INTO ACCOUNT_OWNER (client_id, account_id) VALUES (1, 1);
INSERT INTO ACCOUNT_OWNER (client_id, account_id) VALUES (1, 4);

INSERT INTO ACCOUNT_OWNER (client_id, account_id) VALUES (2, 2);
INSERT INTO ACCOUNT_OWNER (client_id, account_id) VALUES (2, 3);

INSERT INTO ACCOUNT_OWNER (client_id, account_id) VALUES (5, 4);

-- -----------------------------------------------------------------------------
-- 5.6 AUTHORIZATION
-- -----------------------------------------------------------------------------
-- Opravnenia klientov k uctom
-- Klient 1 moze disponovat s uctom klienta 2
-- Klient 5 ma k uctu 2 iba pravo nahliadania
-- ----------------------------------------------------------------------------
INSERT INTO AUTHORIZATION (authorization_id, account_id, client_id, authorization_type, granted_on, created_by_employee_id)
VALUES (NULL, 1, 1, 'OWNER',     DATE '2025-01-10', 3);

INSERT INTO AUTHORIZATION (authorization_id, account_id, client_id, authorization_type, granted_on, created_by_employee_id)
VALUES (NULL, 2, 2, 'OWNER',     DATE '2025-02-05', 3);

INSERT INTO AUTHORIZATION (authorization_id, account_id, client_id, authorization_type, granted_on, created_by_employee_id)
VALUES (NULL, 3, 2, 'OWNER',     DATE '2025-02-20', 4);

INSERT INTO AUTHORIZATION (authorization_id, account_id, client_id, authorization_type, granted_on, created_by_employee_id)
VALUES (NULL, 2, 1, 'DISPONENT', DATE '2025-02-25', 3);

INSERT INTO AUTHORIZATION (authorization_id, account_id, client_id, authorization_type, granted_on, created_by_employee_id)
VALUES (NULL, 2, 5, 'VIEW',      DATE '2025-03-01', 3);

-- -----------------------------------------------------------------------------
-- 5.7 BANK_TRANSACTION
-- -----------------------------------------------------------------------------
-- Ukazkove transakcie
-- -----------------------------------------------------------------------------
INSERT INTO BANK_TRANSACTION (transaction_id, transaction_type, amount, transaction_date, description, source_account_id, target_account_id, initiated_by_person_id, executed_by_employee_id)
VALUES (NULL, 'DEPOSIT',    5000.00, DATE '2025-02-01', 'Hotovostny vklad na pobocke', 1, NULL, 1, 3);

INSERT INTO BANK_TRANSACTION (transaction_id, transaction_type, amount, transaction_date, description, source_account_id, target_account_id, initiated_by_person_id, executed_by_employee_id)
VALUES (NULL, 'WITHDRAWAL', 2000.00, DATE '2025-02-12', 'Vyber hotovosti',             1, NULL, 1, 3);

INSERT INTO BANK_TRANSACTION (transaction_id, transaction_type, amount, transaction_date, description, source_account_id, target_account_id, initiated_by_person_id, executed_by_employee_id)
VALUES (NULL, 'TRANSFER',   3500.00, DATE '2025-03-01', 'Prevod medzi klientmi',       2, 1,    2, 4);

INSERT INTO BANK_TRANSACTION (transaction_id, transaction_type, amount, transaction_date, description, source_account_id, target_account_id, initiated_by_person_id, executed_by_employee_id)
VALUES (NULL, 'DEPOSIT',   10000.00, DATE '2025-03-05', 'Vklad na firemny ucet',       3, NULL, 2, 4);

INSERT INTO BANK_TRANSACTION (transaction_id, transaction_type, amount, transaction_date, description, source_account_id, target_account_id, initiated_by_person_id, executed_by_employee_id)
VALUES (NULL, 'TRANSFER',   1000.00, DATE '2025-03-10', 'Prevod na spolocny ucet',     1, 4,    1, 3);

COMMIT;

-- =============================================================================
-- 6. Kontrolne SELECTy
-- =============================================================================
-- Tieto dotazy sluzia len na rychle overenie, ci sa data vlozili spravne.
-- Ak netreba vypisovat obsah tabuliek, mozu sa pri odovzdani zakomentovat.
-- =============================================================================
SELECT * FROM PERSON;
SELECT * FROM CLIENT;
SELECT * FROM EMPLOYEE;
SELECT * FROM ACCOUNT;
SELECT * FROM ACCOUNT_OWNER;
SELECT * FROM AUTHORIZATION;
SELECT * FROM BANK_TRANSACTION;