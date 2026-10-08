-- =============================================================================
-- Tema 27: Banka
-- Cast 3: SQL skript pre vytvorenie objektov schemy databazy s dotazmi SELECT
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

-- -----------------------------------------------------------------------------
-- 3.2 CLIENT
-- -----------------------------------------------------------------------------
-- Tabulka CLIENT predstavuje klienta banky.
-- Nadvazuje na PERSON, pretoze klient je podtyp osoby.
-- -----------------------------------------------------------------------------
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
INSERT INTO CLIENT (client_id, client_code, ico, registration_date, client_status)
VALUES (1, 'CL0001', NULL,       DATE '2024-01-15', 'ACTIVE');

INSERT INTO CLIENT (client_id, client_code, ico, registration_date, client_status)
VALUES (2, 'CL0002', NULL,       DATE '2024-03-20', 'ACTIVE');

INSERT INTO CLIENT (client_id, client_code, ico, registration_date, client_status)
VALUES (5, 'CL0003', '12345678', DATE '2025-01-10', 'ACTIVE');

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
INSERT INTO AUTHORIZATION (authorization_id, account_id, client_id, authorization_type, authorized_limit, granted_on, created_by_employee_id)
VALUES (NULL, 2, 1, 'DISPONENT', 10000.00, DATE '2025-02-25', 3);

INSERT INTO AUTHORIZATION (authorization_id, account_id, client_id, authorization_type, authorized_limit, granted_on, created_by_employee_id)
VALUES (NULL, 2, 5, 'VIEW',      NULL,     DATE '2025-03-01', 3);

-- -----------------------------------------------------------------------------
-- 5.7 BANK_TRANSACTION
-- -----------------------------------------------------------------------------
-- Ukazkove transakcie
-- -----------------------------------------------------------------------------
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
-- 6. SELECT dotazy podla zadania
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Dotaz 1: Spojenie dvoch tabuliek (CLIENT, PERSON)
-- Funkcia:
-- Vypise zoznam vsetkych klientov banky spolu s ich osobnymi udajmi
-- (meno, priezvisko, e-mail) a aktualnym stavom klientskeho uctu.
-- V aplikacii sa tento dotaz pouzije napr. pri zobrazeni prehladu klientov
-- na pracovnej ploche zamestnanca banky alebo pri vyhladavani konkretnej osoby.
-- -----------------------------------------------------------------------------
SELECT
    c.client_id,
    c.client_code,
    p.first_name,
    p.last_name,
    p.email,
    c.client_status,
    c.registration_date
FROM CLIENT c
JOIN PERSON p
    ON p.person_id = c.client_id
ORDER BY c.client_id;


-- -----------------------------------------------------------------------------
-- Dotaz 2: Spojenie dvoch tabuliek (ACCOUNT, EMPLOYEE, PERSON)
-- Funkcia:
-- Vypise zoznam vsetkych bankovych uctov a pri kazdom ucte zobrazi, ktory
-- zamestnanec dany ucet zalozil (meno, priezvisko a interni kod zamestnanca).
-- V aplikacii sa pouzije napr. pri audite zalozenia uctov alebo na overenie
-- zodpovednosti za konkretny ucet (vztah "created" medzi Employee a Account).
-- -----------------------------------------------------------------------------
SELECT
    a.account_id,
    a.account_number,
    a.account_type,
    a.balance,
    a.currency_code,
    a.opened_on,
    e.employee_code,
    p.first_name || ' ' || p.last_name AS created_by_employee
FROM ACCOUNT a
JOIN EMPLOYEE e
    ON e.employee_id = a.created_by_employee_id
JOIN PERSON p
    ON p.person_id = e.employee_id
ORDER BY a.account_id;


-- -----------------------------------------------------------------------------
-- Dotaz 3: Spojenie troch tabuliek (CLIENT, ACCOUNT_OWNER, ACCOUNT, PERSON)
-- Funkcia:
-- Vypise, ktori klienti su vlastnikmi ktorych bankovych uctov, vratane
-- osobnych udajov klienta a zakladnych informacii o ucte (cislo, typ, zostatok).
-- V aplikacii sa pouzije pri zobrazeni portfolia uctov prihlaseneho klienta
-- alebo pri kontrole vlastnickych vztahov zo strany zamestnanca
-- (vztah "owns" medzi Person a Account realizovany tabulkou ACCOUNT_OWNER).
-- -----------------------------------------------------------------------------
SELECT
    c.client_id,
    p.first_name,
    p.last_name,
    a.account_id,
    a.account_number,
    a.account_type,
    a.balance
FROM ACCOUNT_OWNER ao
JOIN CLIENT c
    ON c.client_id = ao.client_id
JOIN PERSON p
    ON p.person_id = c.client_id
JOIN ACCOUNT a
    ON a.account_id = ao.account_id
ORDER BY c.client_id, a.account_id;


-- -----------------------------------------------------------------------------
-- Dotaz 4: GROUP BY + agregacna funkcia
-- Funkcia:
-- Pre kazdeho klienta vypocita, kolko bankovych uctov vlastni.
-- Klienti bez uctu sa tiez zobrazia (COUNT = 0) vdaka LEFT JOIN.
-- V aplikacii sa pouzije napr. pri sumarizacii klientov na urovni pobocky
-- alebo pri vyhladavani klientov bez aktivnych uctov.
-- -----------------------------------------------------------------------------
SELECT
    c.client_id,
    p.first_name,
    p.last_name,
    COUNT(ao.account_id) AS pocet_uctov
FROM CLIENT c
JOIN PERSON p
    ON p.person_id = c.client_id
LEFT JOIN ACCOUNT_OWNER ao
    ON ao.client_id = c.client_id
GROUP BY c.client_id, p.first_name, p.last_name
ORDER BY pocet_uctov DESC, c.client_id;


-- -----------------------------------------------------------------------------
-- Dotaz 5: GROUP BY + agregacna funkcia
-- Funkcia:
-- Pre kazdy bankovy ucet vypocita celkovy pocet odchadzajucich transakcii
-- a ich sumaru. Vychadzame zo zdrojoveho uctu transakcie (source_account_id),
-- pretoze prave ten reprezentuje ucet, z ktoreho bola transakcia iniciowana.
-- V aplikacii sa pouzije napr. na prehlad aktivity uctov alebo pri detekcii
-- uctov s neobvykle vysokym objemom transakcii (vztah "initiates" v ERD).
-- -----------------------------------------------------------------------------
SELECT
    a.account_id,
    a.account_number,
    COUNT(bt.transaction_id)    AS pocet_transakcii,
    SUM(bt.amount)              AS celkova_suma_transakcii
FROM ACCOUNT a
JOIN BANK_TRANSACTION bt
    ON bt.source_account_id = a.account_id
GROUP BY a.account_id, a.account_number
ORDER BY a.account_id;


-- -----------------------------------------------------------------------------
-- Dotaz 6: EXISTS
-- Funkcia:
-- Najde klientov, ktorym bolo udelene aspon jedno opravnenie k nejakemu uctu
-- (napr. typ DISPONENT alebo VIEW). Opravnenie reprezentuje vztah
-- "Authorization" medzi Person a Account z ERD.
-- V aplikacii sa pouzije napr. pri zobrazeni zoznamu disponentov alebo
-- pri kontrole, ktori klienti maju pristup k uctom inych osob.
-- -----------------------------------------------------------------------------
SELECT
    c.client_id,
    p.first_name,
    p.last_name,
    c.client_code
FROM CLIENT c
JOIN PERSON p
    ON p.person_id = c.client_id
WHERE EXISTS (
    SELECT 1
    FROM AUTHORIZATION au
    WHERE au.client_id = c.client_id
)
ORDER BY c.client_id;


-- -----------------------------------------------------------------------------
-- Dotaz 7: IN s vnorenym SELECTom
-- Funkcia:
-- Vypise bankove ucty, z ktorych bola vykonana aspon jedna transakcia
-- typu TRANSFER (prevod medzi uctami). Vnoreny SELECT vracia zoznam
-- zdrojovych uctov prevodnych transakcii z tabulky BANK_TRANSACTION.
-- V aplikacii sa pouzije napr. pri filtrovani uctov pouzivanych na prevody
-- alebo pri priprave podkladov pre bankovych auditorov.
-- -----------------------------------------------------------------------------
SELECT
    a.account_id,
    a.account_number,
    a.account_type,
    a.balance
FROM ACCOUNT a
WHERE a.account_id IN (
    SELECT bt.source_account_id
    FROM BANK_TRANSACTION bt
    WHERE bt.transaction_type = 'TRANSFER'
)
ORDER BY a.account_id;