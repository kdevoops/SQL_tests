/*
-- obsolete:
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'BookShop1';
DROP DATABASE "BookShop1";
DROP ROLE student;
SELECT * FROM pg_roles WHERE rolname = 'student';
*/



    
DO
$role$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'student')
    THEN
        CREATE ROLE student LOGIN
          ENCRYPTED PASSWORD 'md550d9482e20934ce6df0bf28941f885bc'
          NOSUPERUSER INHERIT CREATEDB CREATEROLE NOREPLICATION;
    END IF;
END;    
$role$;

DO
$role$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_database WHERE datname = 'BookShop1')
    THEN
	ALTER DATABASE "BookShop1" WITH IS_TEMPLATE = FALSE;
    END IF;
END;    
$role$;

DROP DATABASE IF EXISTS "BookShop1" WITH (FORCE);

CREATE DATABASE "BookShop1"
  WITH OWNER = student
       CONNECTION LIMIT = -1;

COMMENT ON DATABASE "BookShop1" IS
'Demo-DB для курсов 
    PostgreSQL: Уровень 1. Основы SQL
    PostgreSQL: Уровень 2. Продвинутые возможности
- рассматриваются возможности Pg на примере книжного ИМ';

\connect BookShop1
-----------------------------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------------------------
CREATE EXTENSION ltree          SCHEMA public;
CREATE EXTENSION isn            SCHEMA public;
CREATE EXTENSION postgres_fdw   SCHEMA public;
-----------------------------------------------------------------------------------------------------------------------------



-- DROP SCHEMA IF EXISTS book_store;
CREATE SCHEMA book_store AUTHORIZATION student;

COMMENT ON SCHEMA book_store IS 'Книги, авторы, тематический рубрикатор и всё прочее, связанное с книгами';
-----------------------------------------------------------------------------------------------------------------------------

-- DROP TABLE IF EXISTS book_store.genre;
CREATE TABLE book_store.genre
(
    genre_id    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent      integer NOT NULL DEFAULT currval('book_store.genre_genre_id_seq'::regclass)
                        REFERENCES book_store.genre (genre_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    -- genre_code  ltree   NOT NULL,
    genre_name  varchar(511) NOT NULL UNIQUE
);
ALTER TABLE book_store.genre OWNER TO student;

CREATE INDEX ix1_genre ON book_store.genre USING btree (parent);

COMMENT ON TABLE book_store.genre
IS 'Список жанров (этакий условный тематический рубрикатор)
Дата создания:  30.04.2020 (Admin)
Дата изменения: 
';

COMMENT ON COLUMN book_store.genre.genre_id         IS 'Собственный идентификатор жанра';
COMMENT ON COLUMN book_store.genre.parent           IS 'Жанр-родитель';
-- COMMENT ON COLUMN book_store.genre.genre_code       IS 'Код жанра';
COMMENT ON COLUMN book_store.genre.genre_name       IS 'Наименование жанра';

-----------------------------------------------------------------------------------------------------------------------------





-----------------------------------------------------------------------------------------------------------------------------

-- DROP TABLE IF EXISTS book_store.book;
CREATE TABLE book_store.book
(
    book_id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    book_name   varchar(255)    NOT NULL,
    isbn      	varchar(18) UNIQUE,
    published   smallint,
    genre_id    integer     NOT NULL REFERENCES book_store.genre (genre_id) ON UPDATE CASCADE ON DELETE RESTRICT
);
ALTER TABLE book_store.book OWNER TO student;

CREATE INDEX ix1_book ON book_store.book USING btree (genre_id);

COMMENT ON TABLE book_store.book

IS 'Rеквизиты книги
Дата создания:  30.04.2020 (Admin)
Дата изменения: 
';

COMMENT ON COLUMN book_store.book.book_id   IS 'Собственный идентификатор книги';
COMMENT ON COLUMN book_store.book.book_name IS 'Наименование книги';
COMMENT ON COLUMN book_store.book.isbn      IS 'ISBN - International Standart Book Number';
COMMENT ON COLUMN book_store.book.published IS 'Год издания';
COMMENT ON COLUMN book_store.book.genre_id  IS 'Жанр';
-----------------------------------------------------------------------------------------------------------------------------



-- DROP TABLE IF EXISTS book_store.author;
CREATE TABLE book_store.author
(
    author_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    author_name varchar(127) NOT NULL UNIQUE,
    biography   text
);
ALTER TABLE book_store.author OWNER TO student;

COMMENT ON TABLE book_store.author
IS 'Авторы книг
поле author_name не разбито на "имя - фамилия-отчество" по следующим причинам:
- у автора может отсутствовать не только отчество, но и деление на имя-фамилию (Сунь-Цзы, Геродот, etc)
- имени и фамилии может быть недостаточно, а отчества при этом может не быть (Александр Дюма отец и Александр Дюма сын)
- авторам мы ничего не выплачиваем (т.к. не издательство), нет формирования официальных (платёжных) документов - нет необходимости в официальном именовании 

Дата создания:  30.04.2020 (Admin)
Дата изменения: 
';


COMMENT ON COLUMN book_store.author.author_id       IS 'Идентификатор автора';
COMMENT ON COLUMN book_store.author.author_name     IS 'Имя автора (полное!)';
COMMENT ON COLUMN book_store.author.biography       IS 'Краткая биография автора';
-----------------------------------------------------------------------------------------------------------------------------




-- DROP TABLE IF EXISTS book_store.book_author;
CREATE TABLE book_store.book_author
(
    book_id     integer NOT NULL REFERENCES book_store.book (book_id)       ON UPDATE CASCADE ON DELETE CASCADE,
    author_id   integer NOT NULL REFERENCES book_store.author (author_id)   ON UPDATE CASCADE ON DELETE RESTRICT,
    /*
    Каскадное удаление при удалении книги разрешено - в результате удалится книга, автор останется
    Удаление автора, с которым связана хотя бы одна книга - запрещено.
    */
    CONSTRAINT pk_book_author PRIMARY KEY (book_id, author_id)
);

ALTER TABLE book_store.book_author OWNER TO student;

COMMENT ON TABLE book_store.book_author
IS 'Кросс-таблица для привязки авторов к книгам
Дата создания:  30.04.2020 (Admin)
Дата изменения: 
';

COMMENT ON COLUMN book_store.book_author.book_id    IS 'Книга';
COMMENT ON COLUMN book_store.book_author.author_id  IS 'Автор';
-----------------------------------------------------------------------------------------------------------------------------


-- DROP TABLE IF EXISTS book_store.price;
CREATE TABLE book_store.price
(
    price_id            integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    book_id             integer NOT NULL REFERENCES book_store.book (book_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    price_value         numeric (8, 2) NOT NULL CHECK (price_value > 0),
    price_expired       date
);

ALTER TABLE book_store.price OWNER TO student;

CREATE INDEX ix1_price ON book_store.price USING btree (book_id);
-- CREATE UNIQUE INDEX uqix_price ON book_store.price USING btree (book_id, COALESCE(price_expired, '2221-01-01'::date));
CREATE UNIQUE INDEX uq1_price ON book_store.price USING btree (book_id, price_expired) NULLS NOT DISTINCT;

COMMENT ON TABLE book_store.price
IS 'Цены
Дата создания:  30.04.2020 (Admin)
Дата изменения: 
';

COMMENT ON COLUMN book_store.price.price_id         IS 'Идентификатор цены';
COMMENT ON COLUMN book_store.price.book_id          IS 'Книга, для которой определяется цена';
COMMENT ON COLUMN book_store.price.price_value      IS 'Собственно цена';
COMMENT ON COLUMN book_store.price.price_expired    IS 'Дата окончания срока действия цены, для актуальной цены - NULL';
-----------------------------------------------------------------------------------------------------------------------------



-----------------------------------------------------------------------------------------------------------------------------

-- DROP SCHEMA IF EXISTS shop
CREATE SCHEMA shop AUTHORIZATION student;

COMMENT ON SCHEMA shop IS 'Клиенты и заказы';

-- DROP TABLE IF EXISTS shop.client;
CREATE TABLE shop.client
(
    client_login    varchar(31) PRIMARY KEY,
    firstname       varchar(63) NOT NULL,
    lastname        varchar(63) NOT NULL,
    patronymic      varchar(63),
    email           varchar(511),
    phone           char(10),
    delivery_addr   varchar(767) NOT NULL,

    CONSTRAINT chk_client_attributes CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

ALTER TABLE shop.client OWNER TO student;

COMMENT ON TABLE shop.client
IS 'Список клиентов
    При регистрации клиент может не указывать отчество, имя и фамилия - обязательны.
    В реальной системе delivery_addr и phone скорее всего были бы вынесены в отдельные таблицы и бизнес-логика предусматривала бы
    возможность привязки к лиенту нескольких телефонных номеров (а может, и email) и нескольких адресов доставки (домашний, офисный, ...).

    Учебную базу упрощаем - только один телефон, только один адрес доставки.

    В реальной системе скорее всего был бы введён суррогатный ключ (см. закомментированный client_id), в учебной используем естественный,
    исключительно для демонстрации такой возможности. 
Дата создания:  30.04.2020 (Admin)
Дата изменения: 
';



COMMENT ON COLUMN shop.client.client_login  IS 'Login клиента';
COMMENT ON COLUMN shop.client.firstname     IS 'Имя клиента';
COMMENT ON COLUMN shop.client.lastname      IS 'Фамилия клиента';
COMMENT ON COLUMN shop.client.patronymic    IS 'Отчество клиента';
COMMENT ON COLUMN shop.client.email         IS 'Адрес e-mail клиента';
COMMENT ON COLUMN shop.client.phone         IS 'Контактный телефон клиента';
COMMENT ON COLUMN shop.client.delivery_addr IS 'Адрес доставки';

COMMENT ON CONSTRAINT chk_client_attributes ON shop.client IS 'Хотя бы одно поле - email или phone должно быть заполнено';
-----------------------------------------------------------------------------------------------------------------------------



-- DROP TABLE IF EXISTS shop.order_main;
CREATE TABLE shop.order_main
(
    order_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_login    varchar(31) NOT NULL REFERENCES shop.client (client_login) ON UPDATE CASCADE ON DELETE RESTRICT,
    order_no        char(14)    NOT NULL UNIQUE,
    order_date      date        DEFAULT current_date
);
ALTER TABLE shop.order_main OWNER TO student;

CREATE INDEX ix1_order_main ON shop.order_main USING btree (client_login);

COMMENT ON TABLE shop.order_main
IS 'Заказы
    Название "order_main" а не "order" выбрано, чтобы избежать совпадений с ключевым словом языка SQL. 
Дата создания:  30.04.2020 (Admin)
Дата изменения: 
';  



COMMENT ON COLUMN shop.order_main.order_id      IS 'Идентификатор заказа';
COMMENT ON COLUMN shop.order_main.client_login  IS 'Клиент, создавший заказ';
COMMENT ON COLUMN shop.order_main.order_no      IS 'Строковый номер заказа для печатных форм';
COMMENT ON COLUMN shop.order_main.order_date    IS 'Дата размещения заказа';
-----------------------------------------------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------------------------------------------
-- DROP TABLE IF EXISTS shop.order_detail;
CREATE TABLE shop.order_detail
(
    order_id    integer NOT NULL REFERENCES shop.order_main (order_id) ON UPDATE CASCADE ON DELETE CASCADE,
    book_id     integer NOT NULL REFERENCES book_store.book (book_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    qty         integer NOT NULL CHECK (qty > 0),

    CONSTRAINT pk_order_detail PRIMARY KEY (order_id, book_id)
);
ALTER TABLE shop.order_detail OWNER TO student;

COMMENT ON TABLE shop.order_detail
IS 'Детализация заказа
Дата создания:  30.04.2020 (Admin)
Дата изменения: 
';



COMMENT ON COLUMN shop.order_detail.order_id            IS 'Идентификатор заказа';
COMMENT ON COLUMN shop.order_detail.book_id             IS 'Книга';
COMMENT ON COLUMN shop.order_detail.qty                 IS 'Количество экземпляров';
-----------------------------------------------------------------------------------------------------------------------------



-- Заполнение тематического рубрикатора, перечня авторов, каталога книг
/*
TRUNCATE TABLE book RESTART IDENTITY CASCADE;
TRUNCATE TABLE genre RESTART IDENTITY CASCADE;
TRUNCATE TABLE author RESTART IDENTITY CASCADE;
TRUNCATE TABLE price RESTART IDENTITY CASCADE;
TRUNCATE TABLE price_category RESTART IDENTITY CASCADE;
*/


SET search_path = book_store, public;

COPY book_store.genre (genre_id, parent, genre_name) FROM STDIN;
1	1	Историческая литература
2	1	Мемуары и биографии
3	1	Исторические очерки
4	3	Очерки об анитчной истории
5	3	Очерки о средневековье
6	3	Очерки об истории эпохи возрождения
7	3	Очерки о новейшей истории
8	1	Исторические романы
9	1	Историческая фантастика
10	2	Биографии художников и музыкантов
11	2	Биографии путешественников
12	2	Биографии инженеров и ученых
13	12	Биографии авиакострукторов
14	14	Художественная литература
15	14	Поэзия
16	14	Проза
17	17	Техническая литература
18	17	Компьютеры и программирования
19	18	Языки программирования
20	18	Базы данных
\.
 
SELECT pg_catalog.setval(pg_get_serial_sequence('book_store.genre', 'genre_id'), COALESCE(max(genre_id), 1), true) FROM book_store.genre;


COPY book_store.author (author_id, author_name, biography) FROM STDIN;
1	Роберт Уолтерс	\N
2	Майкл Коулс	\N
3	Фабио Клаудио Феррачати	\N
4	Роберт Рей	\N
5	Дональд Фармер	\N
6	Кристофер Дж. Дейт	\N
8	В.Р.Михеев	\N
10	Феликс Чуев	\N
11	А.Н.Пономарев	\N
12	Леонид Анциелович	\N
13	Мартин Фаулер	\N
7	Бьёрн Страуструп	программист и писатель, доктор философии, создатель языка программирования C++.\r\nРодился 30 декабря 1950 года в городе Орхус, Дания. В 1975 году окончил отделение информатики Орхусского университета, став магистром математики в области вычислительной техники. Затем поступил в Кембриджский университет.\r\nВ 1979 году Страуструп защитил диссертацию и получил звание доктора философии. После этого вместе с семьёй переехал в Нью-Джерси. Там он стал работать в компьютерном научно-исследовательском центре Bell Telephone Laboratories.\r\nСтрауструп написал несколько книг, в том числе издания: «Программирование. Принципы и практика использования C++»; «Дизайн и эволюция языка С++».\r\nС 2014 года он — приглашенный профессор Колумбийского университета, а также сотрудник компании Morgan Stanley. С января 2021 года Страуструп — технологический консультант Metaspex, компании, которая предлагает прямой перевод спецификаций в высокопроизводительные полнофункциональные облачные приложения.\r\nБьёрн и его жена живут в Нью-Йорке.
9	Г.И.Катышев	Геннадий Иванович Катышев — авиационный инженер, мастер спорта СССР, в прошлом член сборной страны по высшему пилотажу. Ему принадлежит ряд рекордов скорости и дальности полетов на самолетах. В 1986 г. издательство «Наука» выпустила его первую книгу «Создатель автожира Хуан-де ла Сьерва», которая пользовалась большой популярностью не только среди специалистов-вертолетчиков. В дальнейшем он написал несколько книг по истории авиации.
14	Джеффри Фридл	\N
15	Вадим Сергеевич Шефнер	\N
16	Карл вон Клаузевиц	\N
17	Аркадий Натанович Стругацкий	\N
18	Борис Натанович Стругацкий	\N
\.

SELECT pg_catalog.setval(pg_get_serial_sequence('book_store.author', 'author_id'), COALESCE(max(author_id), 1), true) FROM book_store.author;

COPY book_store.book (book_id, book_name, isbn, published, genre_id) FROM STDIN;
1	SQL Server 2008. Ускоренный курс для профессионалов	978-5-8459-1481-1	\N	19
2	Введение в системы баз данных	5-8459-0788-8	\N	19
3	Язык программирования С++. Специальное издание	978-5-7989-0226-2	\N	19
4	Сикорский	5-7325-0564-4	\N	13
5	Ильюшин	978-5-235-03285-9	\N	13
6	Конструктор С.В.Ильюшин	5-203-00139-1	\N	13
7	Неизвестный Хейнкель	978-5-699-49800-0	\N	13
8	Неизвестный Юнкерс	978-5-699-58507-6	\N	13
9	Рефакторинг. Улучшение существующего кода	5-93286-045-6	\N	18
10	Создатель автожира Хуан де ла Сьерва	\N	1986	13
11	Регулярные выражения	978-5-93286-121-9	2008	18
12	Лачуга должника и другие сказки для умных	978-5-386-15145-1	2021	16
13	1812 год	5-8159-0407-4	\N	3
14	Волны гасят ветер	5-7515-0249-3	1992	9
\.

SELECT pg_catalog.setval(pg_get_serial_sequence('book_store.book', 'book_id'), COALESCE(max(book_id), 1), true) FROM book_store.book;

COPY book_store.book_author (book_id, author_id) FROM STDIN;
1	1
1	2
1	3
1	4
1	5
2	6
3	7
4	8
4	9
5	10
6	11
7	12
8	12
9	13
10	9
11	14
12	15
13	16
14	17
14	18
\.

COPY book_store.price (book_id, price_value, price_expired) FROM STDIN;
1	2150.00	2010-01-10
1	3000.00	2012-05-31
1	4250.00	2016-02-20
1	4150.00	2018-12-30
1	4200.00	\N
2	2510.00	2010-10-01
2	3250.00	2012-05-31
2	4125.50	2016-02-20
2	4300.50	2021-01-10
2	4200.50	\N
3	2500.00	2018-12-30
3	3990.00	\N
4	2190.90	2010-01-10
4	3000.00	2011-01-10
4	3250.50	2012-05-31
4	3100.00	2014-01-10
4	3825.00	2016-02-20
4	3990.00	\N
5	1850.00	2010-01-10
5	2010.00	2016-02-20
5	2450.00	2020-01-10
5	3350.00	\N
6	1750.00	2010-01-10
6	2020.00	2016-02-20
6	2550.00	2020-01-10
6	3300.00	\N
7	1600.00	2018-12-30
7	1820.00	\N
8	1600.00	2018-12-30
8	1820.00	\N
9	2200.00	2010-01-10
9	2450.00	2012-04-01
9	2650.00	2014-06-01
9	3200.00	2015-01-10
9	3875.00	2018-01-10
9	3550.00	2020-01-10
9	4200.00	2023-01-10
9	4350.00	\N
10	855.00	\N
11	1250.00	2012-04-01
11	1300.00	2014-06-01
11	1650.00	2015-01-10
11	1600.00	2018-01-10
11	1825.00	2020-01-10
11	1800.00	\N
12	3500.00	\N
13	2400.00	2015-01-10
13	2400.00	2020-01-10
13	2400.00	\N
14	950.00	2010-01-10
14	2150.00	2012-04-01
14	2300.00	2018-12-01
14	2200.00	\N
\.

ALTER DATABASE "BookShop1" WITH IS_TEMPLATE = TRUE;

