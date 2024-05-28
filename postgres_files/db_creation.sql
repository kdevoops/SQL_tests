/*
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'BookShop';
DROP DATABASE "BookShop";
DROP ROLE student;
SELECT * FROM pg_roles WHERE rolname = 'student';
*/


-- Создать роль в общем хранилище СУБД (БД postgres - в ROLES - SELECT * FROM pg_user)
	
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


DROP DATABASE IF EXISTS "BookShop";

CREATE DATABASE "BookShop"
  WITH OWNER = student
       CONNECTION LIMIT = -1;

COMMENT ON DATABASE "BookShop" IS
'Demo-DB для курсов "PostgreSQL: Уровень 1. Основы SQL"
и PostgreSQL: Уровень 2. Продвинутые возможности
- рассматриваются возможности Pg на примере книжного ИМ';

\connect BookShop
-----------------------------------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------------------------------------------------------
CREATE EXTENSION ltree SCHEMA public;
-----------------------------------------------------------------------------------------------------------------------------



-- DROP SCHEMA IF EXISTS book_store;
CREATE SCHEMA book_store AUTHORIZATION student;

COMMENT ON SCHEMA book_store IS 'Книги, авторы, тематический рубрикатор и всё прочее, связанное с книгами';
-----------------------------------------------------------------------------------------------------------------------------

-- DROP TABLE IF EXISTS book_store.genre;
CREATE TABLE book_store.genre
(
	genre_id	serial	PRIMARY KEY, -- идентификатор
	parent		integer NOT NULL DEFAULT currval('book_store.genre_genre_id_seq'::regclass) -- родитель. Для родителя сам на себя
				-- если родитель не указан в поле, то DEFAULT = currval сделает его равным айди текущего элемента, то есть сам на себя (и станет родителем)
				-- regclass - преобразовать значение
						REFERENCES book_store.genre (genre_id) ON UPDATE CASCADE ON DELETE RESTRICT, 
						-- при создании внешнего ключа запретить удаление а при обновлении ключа менять и связанные записи (тк в них ссылка)
	-- поле будет добавлено во 2-й части курса
	-- genre_code	ltree	NOT NULL,
	genre_name	varchar(511) NOT NULL UNIQUE
);

ALTER TABLE book_store.genre OWNER TO student;

CREATE INDEX i1_genre ON book_store.genre USING btree (parent); -- создадим btree индекс для parent для ускорения поиска

COMMENT ON TABLE book_store.genre
IS 'Список жанров (этакий условный тематический рубрикатор)
Дата создания:	30.04.2020 (Admin)
Дата изменения:	
';


COMMENT ON COLUMN book_store.genre.genre_id		IS 'Собственный идентификатор жанра';
COMMENT ON COLUMN book_store.genre.parent		IS 'Жанр-родитель';
--COMMENT ON COLUMN book_store.genre.genre_code		IS 'Код жанра';
COMMENT ON COLUMN book_store.genre.genre_name		IS 'Наименование жанра';

-----------------------------------------------------------------------------------------------------------------------------





-----------------------------------------------------------------------------------------------------------------------------

-- DROP TABLE IF EXISTS book_store.book;
CREATE TABLE book_store.book
(
	book_id		serial 		PRIMARY KEY,
	book_name	varchar(255) 	NOT NULL,
	isbn		varchar(18) 	UNIQUE,
	published	smallint,
	genre_id	integer 	NOT NULL REFERENCES book_store.genre (genre_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

ALTER TABLE book_store.book OWNER TO student;

CREATE INDEX i1_book ON book_store.book USING btree (genre_id);

COMMENT ON TABLE book_store.book

IS 'Rеквизиты книги
Дата создания:	30.04.2020 (Admin)
Дата изменения:	
';

COMMENT ON COLUMN book_store.book.book_id	IS 'Собственный идентификатор книги';
COMMENT ON COLUMN book_store.book.book_name	IS 'Наименование книги';
COMMENT ON COLUMN book_store.book.isbn		IS 'ISBN - International Standart Book Number';
COMMENT ON COLUMN book_store.book.published	IS 'Год издания';
COMMENT ON COLUMN book_store.book.genre_id	IS 'Жанр';
-----------------------------------------------------------------------------------------------------------------------------



-- DROP TABLE IF EXISTS book_store.author;
CREATE TABLE book_store.author
(
	author_id	serial PRIMARY KEY,
	author_name	varchar(127) NOT NULL UNIQUE,
	biography	text
);
ALTER TABLE book_store.author OWNER TO student;

COMMENT ON TABLE book_store.author
IS 'Авторы книг
поле author_name не разбито на "имя - фамилия-отчество" по следующим причинам:
- у автора может отсутствовать не только отчество, но и деление на имя-фамилию (Сунь-Цзы, Геродот, etc)
- имени и фамилии может быть недостаточно, а отчества при этом может не быть (Александр Дюма отец и Александр Дюма сын)
- авторам мы ничего не выплачиваем (т.к. не издательство), нет формирования официальных (платёжных) документов - нет необходимости в официальном именовании 

Дата создания:	30.04.2020 (Admin)
Дата изменения:	
';


COMMENT ON COLUMN book_store.author.author_id		IS 'Идентификатор автора';
COMMENT ON COLUMN book_store.author.author_name	IS 'Имя автора (полное!)';
COMMENT ON COLUMN book_store.author.biography		IS 'Краткая биография автора';
-----------------------------------------------------------------------------------------------------------------------------





-- DROP TABLE IF EXISTS book_store.book_author;
CREATE TABLE book_store.book_author
(
	book_id	integer NOT NULL REFERENCES book_store.book (book_id) ON UPDATE CASCADE ON DELETE CASCADE,
	author_id	integer NOT NULL REFERENCES book_store.author (author_id) ON UPDATE CASCADE ON DELETE RESTRICT,
	/*
	Каскадное удаление при удалении книги разрешено - в результате удалится книга, автор останется
	Удаление автора, с которым связана хотя бы одна книга - запрещено.
	*/
	CONSTRAINT pk_book_author PRIMARY KEY (book_id, author_id)
);

ALTER TABLE book_store.book_author OWNER TO student;

COMMENT ON TABLE book_store.book_author
IS 'Кросс-таблица для привязки авторов к книгам
Дата создания:	30.04.2020 (Admin)
Дата изменения:	
';

COMMENT ON COLUMN book_store.book_author.book_id	IS 'Книга';
COMMENT ON COLUMN book_store.book_author.author_id	IS 'Автор';
-----------------------------------------------------------------------------------------------------------------------------

-- DROP TABLE IF EXISTS book_store.price_category;
CREATE TABLE book_store.price_category
(
	price_category_no	integer		PRIMARY KEY,
	category_name		varchar (63) NOT NULL UNIQUE
);

ALTER TABLE book_store.price_category OWNER TO student;

COMMENT ON TABLE book_store.price_category
IS 'Категории цен
	price_category_no - задаётся "руками"
Дата создания:	30.04.2020 (Admin)
Дата изменения:	
';

COMMENT ON COLUMN book_store.price_category.price_category_no	IS 'Идентификатор (код) ценовой категории';

COMMENT ON COLUMN book_store.price_category.category_name	IS 'Наименование ценовой категории';
-----------------------------------------------------------------------------------------------------------------------------


-- DROP TABLE IF EXISTS book_store.price;
CREATE TABLE book_store.price
(
	price_id			serial PRIMARY KEY,
	book_id				integer NOT NULL REFERENCES book_store.book (book_id) ON UPDATE CASCADE ON DELETE RESTRICT,
	price_category_no	integer NOT NULL REFERENCES book_store.price_category (price_category_no) ON UPDATE CASCADE ON DELETE RESTRICT,
	price_value			numeric (8, 2) NOT NULL CHECK (price_value > 0),
	price_expired		date
	, CONSTRAINT uq_price UNIQUE (book_id, price_category_no)		-- временное решение!
);

ALTER TABLE book_store.price OWNER TO student;

CREATE INDEX i1_price ON book_store.price USING btree (book_id);
CREATE INDEX i2_price ON book_store.price USING btree (price_category_no);
CREATE UNIQUE INDEX uqix_price ON book_store.price USING btree (book_id, price_category_no, COALESCE(price_expired, '2221-01-01'::date));	-- временное решение!

COMMENT ON TABLE book_store.price
IS 'Цены
Дата создания:	30.04.2020 (Admin)
Дата изменения:	
';

COMMENT ON COLUMN book_store.price.price_id		IS 'Идентификатор цены';
COMMENT ON COLUMN book_store.price.book_id		IS 'Книга, для которой определяется цена';
COMMENT ON COLUMN book_store.price.price_category_no	IS 'Категория цены';
COMMENT ON COLUMN book_store.price.price_value		IS 'Собственно цена';
COMMENT ON COLUMN book_store.price.price_expired	IS 'Дата окончания срока действия цены, для актуальной цены - NULL';
-----------------------------------------------------------------------------------------------------------------------------



-----------------------------------------------------------------------------------------------------------------------------

-- DROP SCHEMA IF EXISTS shop
CREATE SCHEMA shop AUTHORIZATION student;

COMMENT ON SCHEMA shop IS 'Клиенты и заказы';

-- DROP TABLE IF EXISTS shop.client;
CREATE TABLE shop.client
(
	-- client_id	serial PRIMARY KEY
	client_login	varchar(31) PRIMARY KEY,
	firstname	varchar(63) NOT NULL,
	lastname	varchar(63) NOT NULL,
	patronymic	varchar(63),
	email		varchar(511),
	phone		char(10),
	delivery_addr	varchar(767) NOT NULL,

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
Дата создания:	30.04.2020 (Admin)
Дата изменения:	
';



-- COMMENT ON COLUMN shop.client.client_id	IS 'Идентификатор клиента (суррогатный)';
COMMENT ON COLUMN shop.client.client_login	IS 'Login клиента';
COMMENT ON COLUMN shop.client.firstname	IS 'Имя клиента';
COMMENT ON COLUMN shop.client.lastname		IS 'Фамилия клиента';
COMMENT ON COLUMN shop.client.patronymic	IS 'Отчество клиента';
COMMENT ON COLUMN shop.client.email		IS 'Адрес e-mail клиента';
COMMENT ON COLUMN shop.client.phone		IS 'Контактный телефон клиента';
COMMENT ON COLUMN shop.client.delivery_addr	IS 'Адрес доставки';

COMMENT ON CONSTRAINT chk_client_attributes ON shop.client IS 'Хотя бы одно поле - email или phone должно быть заполнено';
-----------------------------------------------------------------------------------------------------------------------------



-- DROP TABLE IF EXISTS shop.order_main;
CREATE TABLE shop.order_main
(
	order_id		serial 	PRIMARY KEY,
	client_login		varchar(31)	NOT NULL REFERENCES shop.client (client_login) ON UPDATE CASCADE ON DELETE RESTRICT,
	order_cnt		serial		NOT NULL,
	order_no		char(14) 	NOT NULL UNIQUE,
	order_date		date 		DEFAULT current_date
);

ALTER TABLE shop.order_main OWNER TO student;

COMMENT ON TABLE shop.order_main
IS 'Заказы
	Название "order_main" а не "order" выбрано, чтобы избежать совпадений с ключевым словом языка SQL. 
Дата создания:	30.04.2020 (Admin)
Дата изменения:	
'; 	



COMMENT ON COLUMN shop.order_main.order_id	IS 'Идентификатор заказа';
COMMENT ON COLUMN shop.order_main.order_cnt	IS 'Служебное поле - целочисленный номер заказа в пределах года';
COMMENT ON COLUMN shop.order_main.order_no	IS 'Строковый номер заказа для печатных форм';
COMMENT ON COLUMN shop.order_main.order_date	IS 'Дата размещения заказа';
-----------------------------------------------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------------------------------------------
-- DROP TABLE IF EXISTS shop.order_detail;
CREATE TABLE shop.order_detail
(
	order_id		integer NOT NULL REFERENCES shop.order_main (order_id) ON UPDATE CASCADE ON DELETE CASCADE,
	book_id		integer NOT NULL REFERENCES book_store.book (book_id) ON UPDATE CASCADE ON DELETE RESTRICT,
	qty			integer NOT NULL CHECK (qty >0 ),
	price_category_no	integer NOT NULL REFERENCES book_store.price_category (price_category_no) ON UPDATE CASCADE ON DELETE RESTRICT,

	CONSTRAINT pk_order_detail PRIMARY KEY (order_id, book_id),

	-- кроме существования книги и категории цены должна cуществовать цена как таковая!
	CONSTRAINT fk_order_detail_price FOREIGN KEY (book_id, price_category_no)

	REFERENCES book_store.price (book_id, price_category_no) ON UPDATE CASCADE ON DELETE RESTRICT 
);

ALTER TABLE shop.order_detail OWNER TO student;

CREATE INDEX i1_order_detail ON shop.order_detail USING btree (price_category_no);		-- ???

COMMENT ON TABLE shop.order_detail
IS 'Детализация заказа
Дата создания:	30.04.2020 (Admin)
Дата изменения:	
';



COMMENT ON COLUMN shop.order_detail.order_id			IS 'Идентификатор заказа';
COMMENT ON COLUMN shop.order_detail.book_id			IS 'Книга';
COMMENT ON COLUMN shop.order_detail.qty			IS 'Количество экземпляров';
COMMENT ON COLUMN shop.order_detail.price_category_no		IS 'Какая категория цен применяется';

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

INSERT INTO price_category (price_category_no, category_name)
VALUES  (1, 'Базовая цена'),
	(2, 'Цена VIP клиента'),
	(3, 'Цена по акции');

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
7	Бьёрн Страуструп	\N
8	В.Р.Михеев	\N
9	Г.И.Катышев	\N
10	Феликс Чуев	\N
11	А.Н.Пономарев	\N
12	Леонид Анциелович	\N
13	Мартин Фаулер	\N
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
\.

COPY book_store.price (price_id, book_id, price_category_no, price_value, price_expired) FROM STDIN;
1	1	2	1670.00	\N
2	1	3	1499.99	\N
3	1	1	1610.00	\N
4	2	1	1840.50	\N
5	2	2	1800.00	\N
6	2	3	1800.00	\N
7	3	3	10400.00	\N
8	3	2	1450.50	\N
9	3	1	1600.00	\N
10	4	2	900.00	\N
11	4	3	850.00	\N
12	4	1	960.50	\N
13	5	1	450.50	\N
14	5	2	400.00	\N
15	5	3	350.00	\N
16	6	3	400.00	\N
17	6	2	430.00	\N
18	6	1	475.00	\N
19	7	1	465.00	\N
20	8	3	410.00	\N
21	8	2	440.00	\N
22	7	3	410.00	\N
23	7	2	440.00	\N
24	8	1	465.00	\N
25	9	1	590.00	\N
26	9	3	520.50	\N
\.

SELECT pg_catalog.setval(pg_get_serial_sequence('book_store.price', 'price_id'), COALESCE(max(price_id), 1), true) FROM book_store.price;

