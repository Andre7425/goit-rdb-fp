-- 1 Створення схеми та імпорт даних
SELECT * FROM mydb3.infectious_cases;

-- Створюємо схему
CREATE SCHEMA IF NOT EXISTS pandemic;

-- Обираємо її за замовчуванням
USE pandemic;

/* 2. Нормалізація таблиці (3NF)
Оскільки атрибути Entity (Назва країни/регіону) та Code (Код країни) 
постійно повторюються для кожного року, їх необхідно винести в окремий довідник. 
Ми створимо дві таблиці: entities (довідник) та cases (нормалізована таблиця з даними, 
що посилається на довідник).
*/
-- 2.1 Створення таблиці довідника (Entity та Code)
CREATE TABLE entities (
    id INT AUTO_INCREMENT PRIMARY KEY,
    entity_name VARCHAR(255) NOT NULL,
    code VARCHAR(10)
);

-- 2.2 Наповнення довідника унікальними значеннями
INSERT INTO entities (entity_name, code)
SELECT DISTINCT Entity, Code
FROM mydb3.infectious_cases;

-- 2.3 Створення нормалізованої таблиці для захворювань
CREATE TABLE normalized_cases (
    id INT AUTO_INCREMENT PRIMARY KEY,
    entity_id INT,
    year INT,
    number_yaws VARCHAR(50),
    polio_cases VARCHAR(50),
    cases_guinea_worm VARCHAR(50),
    number_rabies VARCHAR(50),
    number_malaria VARCHAR(50),
    number_hiv VARCHAR(50),
    number_tuberculosis VARCHAR(50),
    number_smallpox VARCHAR(50),
    number_cholera_cases VARCHAR(50),
    FOREIGN KEY (entity_id) REFERENCES entities(id)
);

-- 2.4 Перенесення даних з прив'язкою до entity_id
INSERT INTO normalized_cases (
    entity_id, year, number_yaws, polio_cases, cases_guinea_worm, number_rabies, 
    number_malaria, number_hiv, number_tuberculosis, number_smallpox, number_cholera_cases
)
SELECT 
    e.id, ic.Year, ic.Number_yaws, ic.polio_cases, ic.cases_guinea_worm, ic.Number_rabies, 
    ic.Number_malaria, ic.Number_hiv, ic.Number_tuberculosis, ic.Number_smallpox, ic.Number_cholera_cases
FROM mydb3.infectious_cases ic
JOIN entities e ON ic.Entity = e.entity_name AND (ic.Code = e.code OR (ic.Code IS NULL AND e.code IS NULL));

-- 2.5 Виведення кількості рядків із сирої таблиці (інфо для ментора)
SELECT COUNT(*) AS total_raw_cases FROM mydb3.infectious_cases;

/* 3. Аналіз даних (Number_rabies)
Розрахуємо статистику по сказу (Number_rabies) для кожного регіону. 
Ми відфільтруємо порожні рядки (!= '') та NULL значення.
*/
SELECT 
    e.entity_name,
    e.code,
    AVG(nc.number_rabies) AS avg_rabies,
    MIN(nc.number_rabies) AS min_rabies,
    MAX(nc.number_rabies) AS max_rabies,
    SUM(nc.number_rabies) AS sum_rabies
FROM normalized_cases nc
JOIN entities e ON nc.entity_id = e.id
WHERE nc.number_rabies != '' AND nc.number_rabies IS NOT NULL
GROUP BY e.entity_name, e.code
ORDER BY avg_rabies DESC
LIMIT 10;

/* 4. Побудова колонки різниці в роках
Використаємо вбудовану функцію MAKEDATE(year, day_of_year), 
щоб з року створити 1 січня, та TIMESTAMPDIFF 
для вирахування точної різниці в роках.
*/
SELECT 
    year,
    MAKEDATE(year, 1) AS start_of_year_date,     -- Дата 1 січня відповідного року
    CURDATE() AS current_date_val,               -- Поточна дата
    TIMESTAMPDIFF(YEAR, MAKEDATE(year, 1), CURDATE()) AS diff_in_years -- Різниця в роках
FROM 
    normalized_cases
LIMIT 20; -- Обмежив вивід, щоб не "засмічувати" екран тисячами рядків

/* 5. Побудова власної функції
Створимо функцію, яка буде інкапсулювати логіку з попереднього завдання 
(приймає рік, повертає різницю років з поточною датою).
*/
-- Видаляємо функцію, якщо вона вже існує
DROP FUNCTION IF EXISTS GetYearsDifference;

-- Змінюємо роздільник для створення функції
DELIMITER //

CREATE FUNCTION GetYearsDifference(input_year INT) 
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE years_diff INT;
    -- Вираховуємо різницю: від 1 січня вказаного року до поточної дати
    SET years_diff = TIMESTAMPDIFF(YEAR, MAKEDATE(input_year, 1), CURDATE());
    RETURN years_diff;
END //

-- Повертаємо стандартний роздільник
DELIMITER ;

-- ==========================================
-- Застосування функції до наших даних
-- ==========================================
SELECT 
    year,
    GetYearsDifference(year) AS years_passed
FROM 
    normalized_cases
LIMIT 20;
