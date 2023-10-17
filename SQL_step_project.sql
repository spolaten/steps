/*
SQL степ-проект
Запросы
1.Покажите среднюю зарплату сотрудников за каждый год (средняя заработная плата среди тех, кто работал в отчетный период 
-статистика с начала до 2005 года).
*/
/*
В таблице данные только до 2002 года
*/

SELECT MIN(from_date), MIN(to_date) 
FROM salaries; -- разница 3 месяца, год тот же

SELECT MAX(from_date), MAX(to_date) 
FROM salaries WHERE to_date < '9999-01-01';
-- выбор from_date или to_date для определения года (YEAR(from_date) или YEAR(to_date)) равноценен, данные будут отличаться незначительно, 
-- при этом никакие данные не будут утеряны.

SELECT 
	YEAR(from_date) AS year_from, 
    ROUND(AVG(salary), 0) AS avg_salary_from 
FROM salaries 
GROUP BY YEAR(from_date) 
ORDER BY YEAR(from_date);


/*
2.Покажите среднюю зарплату сотрудников по каждому отделу. Примечание: принять в расчет только текущие отделы и текущую заработную плату.
*/

SELECT 
	ed.dept_name AS 'Department', 
    ROUND(AVG(es.salary),0) AS 'Current avg salary'
FROM 
	employees.dept_emp ede
	INNER JOIN
	employees.salaries es ON (ede.emp_no = es.emp_no)
	INNER JOIN
	employees.departments ed ON (ede.dept_no = ed.dept_no)
WHERE 
	NOW() BETWEEN es.from_date AND es.to_date
	AND
	NOW() BETWEEN ede.from_date AND ede.to_date
GROUP BY ed.dept_name;


/*
3.Покажите среднюю зарплату сотрудников по каждому отделу за каждый год. Примечание: для средней зарплаты отдела X в году Y нам нужно взять 
среднее значение всех зарплат в году Y сотрудников,которые были в отделе X в году Y.
*/

SELECT 
	ed.dept_name 'Department', 
    YEAR(es.from_date) 'Year', 
    ROUND(AVG(es.salary),0) 'Avg salary'
FROM 
	employees.dept_emp ede
	INNER JOIN
	employees.salaries es ON (ede.emp_no = es.emp_no)
	INNER JOIN
	employees.departments ed ON (ede.dept_no = ed.dept_no)
WHERE 
	ede.from_date <= es.from_date AND es.from_date <= ede.to_date
	OR 
    ede.from_date <= es.to_date AND es.to_date <= ede.to_date
GROUP BY 
	ed.dept_name, YEAR(es.from_date)
ORDER BY 
	ed.dept_name, YEAR(es.from_date);


/*
4.Покажите для каждого года самый крупный отдел (по количеству сотрудников) в этом году и его среднюю зарплату.
*/

WITH max_ads AS(
	SELECT 
		ed.dept_name department, 
		YEAR(es.from_date) year, 
		COUNT(ede.emp_no) count_employees, 
		ROUND(AVG(es.salary),0) avg_salary,
		FIRST_VALUE(COUNT(ede.emp_no)) 
			OVER (PARTITION BY YEAR(es.from_date) ORDER BY COUNT(ede.emp_no) DESC) AS max_dept_count
	FROM 
		employees.dept_emp ede
		INNER JOIN
		employees.salaries es ON (ede.emp_no = es.emp_no)
		INNER JOIN
		employees.departments ed ON (ede.dept_no = ed.dept_no)
	WHERE 
		ede.from_date <= es.from_date AND es.from_date <= ede.to_date
		OR 
        ede.from_date <= es.to_date AND es.to_date <= ede.to_date
	GROUP BY 
		YEAR(es.from_date), ed.dept_name
	ORDER BY 
		YEAR(es.from_date), ed.dept_name
)
SELECT 
	year, 
    department, 
    count_employees, 
    avg_salary 
FROM max_ads 
WHERE count_employees = max_dept_count 
ORDER BY year;


/*
5.Покажите подробную информацию о менеджере, который дольше всех исполняет свои обязанности на данный момент.
*/

SELECT * 
FROM employees.employees 
WHERE emp_no IN 
	(SELECT emp_no 
    FROM employees.dept_manager 
    WHERE from_date = 
		(SELECT MIN(from_date) 
        FROM employees.dept_manager
		WHERE CURDATE() BETWEEN from_date AND to_date));
        
        
/*
6.Покажите топ-10 нынешних сотрудников компании с наибольшей разницей между их зарплатой и текущей средней зарплатой в их отделе.
*/

WITH avg_dept_sal AS(
	SELECT 
		ede.dept_no dept_no, 
        ROUND(AVG(es.salary), 0) avg_salary 
	FROM 
		salaries es 
		INNER JOIN 
        dept_emp ede USING (emp_no) 
	WHERE 
		CURDATE() BETWEEN es.from_date AND es.to_date 
		AND 
		CURDATE() BETWEEN ede.from_date AND ede.to_date
	GROUP BY ede.dept_no
),
cur_empl AS(
	SELECT 
		es.emp_no, 
		ede.dept_no dept_no, 
        es.salary 
	FROM 
		salaries es 
		INNER JOIN 
		dept_emp ede USING (emp_no) 
	WHERE 
		curdate() BETWEEN es.from_date AND es.to_date 
		AND 
        curdate() BETWEEN ede.from_date AND ede.to_date
)
SELECT 
	ce.emp_no, 
    ce.dept_no, 
    ce.salary, 
    ads.avg_salary, 
    ABS(ce.salary - ads.avg_salary) diff_salary 
FROM 
	cur_empl ce 
    INNER JOIN 
    avg_dept_sal ads ON (ce.dept_no = ads.dept_no)
ORDER BY diff_salary DESC 
LIMIT 10;


/*
7.Из-за кризиса на одно подразделение на своевременную выплату зарплаты выделяется всего 500 тысяч долларов. 
Правление решило, что низкооплачиваемые сотрудники будут первыми получать зарплату. 
Показать список всех сотрудников, которые будут вовремя получать зарплату (обратите внимание, что мы должны платить зарплату 
за один месяц, но в базе данных мы храним годовые суммы).
*/

WITH data_tab AS (
	SELECT 
		es.emp_no, 
		ede.dept_no dept_no, 
        ROUND(es.salary/12, 0) month_salary, 
		SUM(ROUND(es.salary/12, 0)) 
			OVER(PARTITION BY ede.dept_no ORDER BY ROUND(es.salary/12, 0) 
			ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_sum 
	FROM 
		salaries es 
		INNER JOIN 
        dept_emp ede USING (emp_no) 
	WHERE 
		CURDATE() BETWEEN es.from_date AND es.to_date 
		AND 
        CURDATE() BETWEEN ede.from_date AND ede.to_date
)
SELECT *
FROM data_tab
WHERE cum_sum <= 500000;


/*
Дизайн базы данных:

1.Разработайте базу данных для управления курсами. 
База данных содержит следующие сущности:
a.students: student_no, teacher_no, course_no, student_name, email, birth_date.
b.teachers: teacher_no, teacher_name, phone_no
c.courses: course_no, course_name, start_date, end_date.
*/

CREATE DATABASE courses_db;

USE courses_db;

CREATE TABLE IF NOT EXISTS students (
   student_no INT,
   teacher_no INT,
   course_no INT,
   student_name VARCHAR(60),
   email VARCHAR(40),
   birth_date DATE
);

CREATE TABLE IF NOT EXISTS teachers (
   teacher_no INT,
   teacher_name VARCHAR(60),
   phone_no VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS courses (
   course_no INT,
   course_name VARCHAR(100),
   start_date DATE,
   end_date DATE
);


/*
Секционировать по годам, таблицу students по полю birth_date с помощью механизма range
*/

ALTER TABLE students
PARTITION BY RANGE (YEAR(birth_date)) 
(PARTITION p1962 VALUES LESS THAN (1963),
PARTITION p1963 VALUES LESS THAN (1964),
PARTITION p1964 VALUES LESS THAN (1965),
PARTITION p1965 VALUES LESS THAN (1966),
PARTITION p1966 VALUES LESS THAN (1967),
PARTITION p1967 VALUES LESS THAN (1968),
PARTITION p1968 VALUES LESS THAN (1969),
PARTITION p1969 VALUES LESS THAN (1970),
PARTITION p1970 VALUES LESS THAN (1971),
PARTITION p1971 VALUES LESS THAN (1972),
PARTITION p1972 VALUES LESS THAN (1973),
PARTITION p1973 VALUES LESS THAN (1974),
PARTITION p1974 VALUES LESS THAN (1975),
PARTITION p1975 VALUES LESS THAN (1976),
PARTITION p1976 VALUES LESS THAN (1977),
PARTITION p1977 VALUES LESS THAN (1978),
PARTITION p1978 VALUES LESS THAN (1979),
PARTITION p1979 VALUES LESS THAN (1980),
PARTITION p1980 VALUES LESS THAN (1981),
PARTITION p1981 VALUES LESS THAN (1982),
PARTITION p1982 VALUES LESS THAN (1983),
PARTITION p1983 VALUES LESS THAN (1984),
PARTITION p1984 VALUES LESS THAN (1985),
PARTITION p1985 VALUES LESS THAN (1986),
PARTITION p1986 VALUES LESS THAN (1987),
PARTITION p1987 VALUES LESS THAN (1988),
PARTITION p1988 VALUES LESS THAN (1989),
PARTITION p1989 VALUES LESS THAN (1990),
PARTITION p1990 VALUES LESS THAN (1991),
PARTITION p1991 VALUES LESS THAN (1992),
PARTITION p1992 VALUES LESS THAN (1993),
PARTITION p1993 VALUES LESS THAN (1994),
PARTITION p1994 VALUES LESS THAN (1995),
PARTITION p1995 VALUES LESS THAN (1996),
PARTITION p1996 VALUES LESS THAN (1997),
PARTITION p1997 VALUES LESS THAN (1998),
PARTITION p1998 VALUES LESS THAN (1999),
PARTITION p1999 VALUES LESS THAN (2000),
PARTITION p2000 VALUES LESS THAN (2001),
PARTITION p2001 VALUES LESS THAN (2002),
PARTITION p2002 VALUES LESS THAN (2003),
PARTITION p2003 VALUES LESS THAN (2004),
PARTITION p2004 VALUES LESS THAN (2005),
PARTITION p2005 VALUES LESS THAN (2006),
PARTITION p2006 VALUES LESS THAN (2007)
);

EXPLAIN SELECT * FROM students;

-- === Ответ сервера ===
-- 1	SIMPLE	students	p1962,p1963,p1964,p1965,p1966,p1967,p1968,p1969,p1970,p1971,p1972,p1973,p1974,p1975,p1976,p1977,p1978,p1979,p1980,p1981,p1982,p1983,p1984,p1985,p1986,p1987,p1988,p1989,p1990,p1991,p1992,p1993,p1994,p1995,p1996,p1997,p1998,p1999,p2000,p2001,p2002,p2003,p2...	ALL					1	100.00	


/*
В таблице students сделать первичный ключ в сочетании двух полей student_no и birth_date 
*/

ALTER TABLE students ADD PRIMARY KEY(student_no, birth_date);

DESC students;


/*
Создать индекс по полю students.email
*/

CREATE INDEX index_email ON students(email);

SHOW INDEXES FROM students;


/*
Создать уникальный индекс по полю teachers.phone_no
*/

CREATE UNIQUE INDEX index_phone_no ON teachers(phone_no);

SHOW INDEXES FROM teachers;


/*
2.На свое усмотрение добавить тестовые данные (7-10 строк) в наши три таблицы.
*/

INSERT INTO courses VALUES
(1, 'Англійська для дорослих', '2022-09-09', '2023-02-20'),
(2, 'Англійська для підлітків, підготовка до ЗНО та ДПА', '2022-09-09', '2022-11-10'),
(3, 'Англійська для дітей', '2022-09-09', '2023-03-15'),
(4, 'Підготовка до IELTS, TOEFL, Cambridge Assessment English', '2022-09-09', '2022-12-15'),
(5, 'Корпоративна англійська', '2022-09-09', '2022-12-20'),
(6, 'Розмовна англійська', '2022-09-09', '2022-11-15'),
(7, 'Інтенсивні курси для дорослих', '2022-09-09', '2022-10-09');

SELECT * FROM courses;

INSERT INTO teachers VALUES
(1, 'Кмета Творимира Костянтинівна', '380968685223'),
(2, 'Демешко Йоган Юхимович', '380956902316'),
(3, 'Остафійчук Славина Полянівна', '380500494466'),
(4, 'Савула Цвітан Адамович', '380635707781'),
(5, 'Грицюк Трояна Найденівна', '380987330110'),
(6, 'Косарчин Чеслав Герасимович', '380676733269'),
(7, 'Пучко Жозефіна Борисівна', '380684087268');

SELECT * FROM teachers;

INSERT INTO students VALUES
(1, 7, 7, 'Горовий Біломир Олегович', 'ceimause-7333@agmail.com', '1967-09-17'),
(2, 5, 3, 'Тесля Венера Вітанівна', 'brallozo-7120@agmail.com', '1987-11-28'),
(3, 3, 5, 'Ропаник Радмила Августинівна', 'bepomce-3113@agmail.com', '1977-09-01'),
(4, 1, 2, 'Палій Ісидора Леонідівна', 'bajameni-8334@agmail.com', '2005-12-09'),
(5, 6, 4, 'Многогрішна Ромена Чеславівна', 'japoll-9780@agmail.com', '1984-04-06'),
(6, 2, 1, 'Рибак Улита Максимівна', 'breuse-2940@agmail.com', '1980-06-05'),
(7, 4, 6, 'Хомик Федір Володимирович', 'ceppaul-4249@agmail.com', '1989-03-31'),
(8, 3, 5, 'Лисак Яків Богданович', 'tebreid-1744@agmail.com', '1995-07-10'),
(9, 7, 7, 'Сотниченко Юхим Остапович', 'hefimmi-5261@agmail.com', '1969-01-18'),
(10, 5, 3, 'Гоголь Ярослав Ярославович', 'moxoko-3827@agmail.com', '1993-03-30');

SELECT * FROM students;


/*
3.Отобразить данные за любой год из таблицы students и зафиксировать в виду комментария план выполнения запроса, 
где будет видно что запрос будет выполняться по конкретной секции.
*/

EXPLAIN SELECT * FROM students WHERE YEAR(birth_date) = 1980;

-- === Ответ сервера ===
-- 1	SIMPLE	students	p1962,p1963,p1964,p1965,p1966,p1967,p1968,p1969,p1970,p1971,p1972,p1973,p1974,p1975,p1976,p1977,p1978,p1979,p1980,p1981,p1982,p1983,p1984,p1985,p1986,p1987,p1988,p1989,p1990,p1991,p1992,p1993,p1994,p1995,p1996,p1997,p1998,p1999,p2000,p2001,p2002,p2003,p2...	ALL					10	100.00	Using where


/*
4.Отобразить данные учителя, по любому одному номеру телефона и зафиксировать план выполнения запроса, где будет видно, 
что запрос будет выполняться по индексу, а не методом ALL. Далее индекс из поля teachers.phone_no сделать невидимым и 
зафиксировать план выполнения запроса, где ожидаемый результат -метод ALL. В итоге индекс оставить в статусе -видимый. 
*/

EXPLAIN SELECT * FROM teachers WHERE phone_no=380635707781;

-- === Ответ сервера ===
-- 1	SIMPLE	teachers		ALL	index_phone_no				7	14.29	Using where

ALTER TABLE teachers ALTER INDEX index_phone_no INVISIBLE;

EXPLAIN SELECT * FROM teachers WHERE phone_no=380635707781;

-- === Ответ сервера ===
-- 1	SIMPLE	teachers		ALL					7	14.29	Using where 

ALTER TABLE teachers ALTER INDEX index_phone_no VISIBLE;

EXPLAIN SELECT * FROM teachers WHERE phone_no=380635707781;

-- === Ответ сервера ===
-- 1	SIMPLE	teachers		ALL	index_phone_no				7	14.29	Using where


/*
5.Специально сделаем 3 дубляжа в таблице students (добавим еще 3 одинаковые строки).
*/
/*
Не совсем поняла задание в части "3 одинаковые строки", поэтому добавляю 3 разные, но уже существующие в таблице строки 
и полностью одинаковые 3 строки
*/

INSERT INTO students VALUES
(1, 7, 7, 'Горовий Біломир Олегович', 'ceimause-7333@agmail.com', '1967-09-17'),
(2, 5, 3, 'Тесля Венера Вітанівна', 'brallozo-7120@agmail.com', '1987-11-28'),
(3, 3, 5, 'Ропаник Радмила Августинівна', 'bepomce-3113@agmail.com', '1977-09-01'),
(3, 3, 5, 'Ропаник Радмила Августинівна', 'bepomce-3113@agmail.com', '1977-09-01'),
(3, 3, 5, 'Ропаник Радмила Августинівна', 'bepomce-3113@agmail.com', '1977-09-01');

-- === Ответ сервера (из-за неуникальности комбинированного ключа) ===
-- Error Code: 1062. Duplicate entry '1-1967-09-17' for key 'students.PRIMARY'

-- сделаем комбинации PRIMARY KEY уникальными, изменим student_no

INSERT INTO students VALUES
(11, 7, 7, 'Горовий Біломир Олегович', 'ceimause-7333@agmail.com', '1967-09-17'),
(12, 5, 3, 'Тесля Венера Вітанівна', 'brallozo-7120@agmail.com', '1987-11-28'),
(13, 3, 5, 'Ропаник Радмила Августинівна', 'bepomce-3113@agmail.com', '1977-09-01'),
(14, 3, 5, 'Ропаник Радмила Августинівна', 'bepomce-3113@agmail.com', '1977-09-01'),
(15, 3, 5, 'Ропаник Радмила Августинівна', 'bepomce-3113@agmail.com', '1977-09-01');


/*
6.Написать запрос, который выводит строки с дубляжами.
*/

SELECT *, COUNT(*) AS count
FROM students
GROUP BY 
	teacher_no, 
    course_no, 
    student_name, 
    email, 
    birth_date
HAVING count > 1;

