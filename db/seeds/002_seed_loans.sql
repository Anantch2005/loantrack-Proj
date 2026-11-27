
INSERT INTO loans (borrower_name, loan_amount, property_city, status)
SELECT seed.borrower_name, seed.loan_amount, seed.property_city, seed.status
FROM (VALUES
    ('Rahul Sharma', 2500000.00, 'Delhi', 'APPROVED'),
    ('Priya Verma', 1800000.00, 'Noida', 'PENDING'),
    ('Amit Kumar', 3200000.00, 'Gurugram', 'DISBURSED'),
    ('Neha Singh', 1500000.00, 'Lucknow', 'REJECTED'),
    ('Vikash Gupta', 2750000.00, 'Jaipur', 'PENDING')
) AS seed(borrower_name, loan_amount, property_city, status)
WHERE NOT EXISTS (SELECT 1 FROM loans);
