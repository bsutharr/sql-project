## data imported using data import wizard

use bhanwar;

select * from hospital;
SET SQL_SAFE_UPDATES = 0;

-- Increase all paid_amount by 5% for “Insurance” payments
update hospital
set paid_amount = paid_amount * 1.05
where payment_method = "Insurance" ;

-- Correct any visit records where age < 1 → set to NULL

UPDATE hospital
SET age = null
WHERE age < 1;

-- Delete records where billing_amount = 0

delete from hospital
where billing_amount = 0;

-- Total revenue, paid revenue, outstanding revenue
select sum(billing_amount) as total_revenue, sum(paid_amount) as paid_revenue, sum(billing_amount - paid_amount) as outstandning_revenue
from hospital;

-- revenue by doctor
select doctor_name, sum(billing_amount) as total_revenue
from hospital
group by doctor_name
order by total_revenue desc;

-- revenue by Department #
select department, sum(billing_amount) as total_revenue
from hospital
group by department
order by total_revenue desc;

-- Top 10 patients by spending
select patient_name , sum(billing_amount) as total_spend
from hospital
group by patient_name
order by total_spend desc
limit 10;

-- Monthly revenue trend
select date_format(str_to_date(visit_date, '%m/%d/%y'), '%y-%m') as month, 
sum(billing_amount) as monthly_revenue
from hospital group by date_format(str_to_date(visit_date, '%m/%d/%y'), '%y-%m') 
order by month;

-- Average billing per visit type
select visit_type, round(avg(billing_amount),2) as avg_billing
from hospital
group by visit_type;

-- Count of visits requiring follow-up
select count(*) as follow_up_visits
from hospital
where follow_up_flag =1;

## joins ##
-- List all visits with patient name + doctor name + department

select v.visit_id, v.visit_date,
v.patient_name,
v.doctor_name, v.department
from hospital v
order by v.patient_name;

-- Get all procedures performed along with billing amounts
select procedure_description, billing_amount 
from hospital 
where procedure_description is not null;

## Patients whose visit count is above average visit count
select patient_id, patient_name, count(*) as total_visit
from hospital
group by patient_id, patient_name 
having count(*) > ( select avg(cnt)
					from (select count(*) as cnt from hospital group by patient_id) t);
                    

## Visits where billing is above patient’s own average billing

select * from 
hospital v where
billing_amount > ( select avg(billing_amount)
					from hospital
                    where patient_id = v.patient_id);

-- Doctors with revenue higher than average doctor revenue

select doctor_id, sum(billing_amount) as revenue
from hospital
group by doctor_id
having sum(billing_amount) > ( select avg(rev) from (
									select sum(billing_amount) as rev from hospital group by doctor_id) t);
                                    


-- Running total of Daily Revenue
select 
visit_date,
    SUM(billing_amount) OVER (ORDER BY visit_date) AS running_total_revenue
FROM hospital
GROUP BY visit_date
ORDER BY visit_date;    

-- lag / lead daily revenue

select visit_date,
sum(billing_amount) as daily_revenue,
lag(sum(billing_amount)) over (order by visit_date) as prev_day,
lead(sum(billing_amount)) over (order by visit_date) as next_day,  
from hospital
group by visit_date;

-- views -- monthly billing summary

CREATE VIEW Monthly_Billing_Summary AS
SELECT DATE_FORMAT(STR_TO_DATE(visit_date, '%d-%m-%Y'), '%Y-%m') AS month,
    COUNT(visit_id) AS total_visits,
    SUM(paid_amount) AS total_billing,
    AVG(paid_amount) AS avg_billing
FROM hospital
GROUP BY DATE_FORMAT(STR_TO_DATE(visit_date, '%d-%m-%Y'), '%Y-%m')
ORDER BY month;

select * from Monthly_Billing_Summary;

-- Doctor_Performance View
CREATE VIEW Doctor_Performance AS
SELECT 
    doctor_name,
    COUNT(visit_id) AS total_visits,
    SUM(paid_amount) AS total_revenue,
    AVG(paid_amount) AS avg_billing
FROM hospital
GROUP BY doctor_name
ORDER BY total_revenue DESC;

select * from Doctor_Performance;    

-- High_Value_Patients View
CREATE VIEW High_Value_Patientss AS
SELECT 
    patient_id,
    patient_name,
    SUM(paid_amount) AS total_billing,
    COUNT(visit_id) AS total_visits
FROM hospital
GROUP BY patient_id, patient_name
HAVING SUM(paid_amount) > 5000
ORDER BY total_billing DESC;

select * from High_Value_Patientss;      

-- store procedures --settle_payment
DELIMITER $$

CREATE PROCEDURE settle_payments(
    IN p_visit_id VARCHAR(20),
    IN p_amount DECIMAL(10,2)
)
BEGIN
    UPDATE hospital
    SET paid_amount = p_amount
    WHERE visit_id = p_visit_id;

    -- Return the updated row
    SELECT * FROM hospital
    WHERE visit_id = p_visit_id;
END$$

DELIMITER ;

-- Call the procedure with a string visit_id
CALL settle_payments('VIS20010', 500.00);


-- Stored Procedure: add_followup(visit_id)


DELIMITER $$

CREATE PROCEDURE add_followup(
    IN p_visit_id TEXT
)
BEGIN
    UPDATE hospital
    SET follow_up_flag = 1
    WHERE visit_id = p_visit_id;

    SELECT * FROM hospital
    WHERE visit_id = p_visit_id;
END$$

DELIMITER ;

-- Usage:
CALL add_followup('VIS20010');


## triggers

CREATE TABLE IF NOT EXISTS audit_log (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    visit_id TEXT,
    old_billing DOUBLE,
    new_billing DOUBLE,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE hospital ADD COLUMN outstanding_amount DOUBLE DEFAULT 0;

-- Trigger 1: On UPDATE of billing_amount → insert into audit_log

DELIMITER $$

CREATE TRIGGER trg_billing_update
AFTER UPDATE ON hospital
FOR EACH ROW
BEGIN
    IF OLD.billing_amount <> NEW.billing_amount THEN
        INSERT INTO audit_log (visit_id, old_billing, new_billing)
        VALUES (NEW.visit_id, OLD.billing_amount, NEW.billing_amount);
    END IF;
END$$

DELIMITER ;


-- Trigger 2: On INSERT → auto-calculate outstanding_amount
DELIMITER $$

CREATE TRIGGER trg_insert_outstanding
BEFORE INSERT ON hospital
FOR EACH ROW
BEGIN
    SET NEW.outstanding_amount = IFNULL(NEW.billing_amount,0) - IFNULL(NEW.paid_amount,0);
END$$

DELIMITER ;

-- trigger o/p 

-- Insert new visit
INSERT INTO hospital (visit_id, billing_amount, paid_amount) 
VALUES ('V200', 5000, 2000);

-- Check outstanding_amount
SELECT visit_id, billing_amount, paid_amount, outstanding_amount
FROM hospital
WHERE visit_id='V200';

-- Update billing
UPDATE hospital SET billing_amount = 6000 WHERE visit_id='V200';

-- Check audit log
SELECT * FROM audit_log;


