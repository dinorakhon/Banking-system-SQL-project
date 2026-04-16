create database project
use project

IF OBJECT_ID('tempdb..#Numbers') IS NOT NULL DROP TABLE #Numbers;

SELECT TOP 10000 
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
INTO #Numbers
FROM sys.objects a CROSS JOIN sys.objects b;



--Core Banking Tables

CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY,
    FullName NVARCHAR(100),
    DOB DATE,
    Email NVARCHAR(100),
    PhoneNumber NVARCHAR(20),
    Address NVARCHAR(200),
    NationalID NVARCHAR(50),
    TaxID NVARCHAR(50),
    EmploymentStatus NVARCHAR(50),
    AnnualIncome DECIMAL(12,2),
    CreatedAt DATETIME,
    UpdatedAt DATETIME
);
INSERT INTO Customers
SELECT 
    n,
    CONCAT(
        CHOOSE(ABS(CHECKSUM(NEWID())) % 10 + 1,
        'Ali','Vali','Bekzod','Aziz','Jasur','Sardor','Dilshod','Akmal','Umid','Sherzod'),
        ' ',
        CHOOSE(ABS(CHECKSUM(NEWID())) % 10 + 1,
        'Karimov','Aliyev','Rahimov','Toshev','Nazarov','Ergashev','Yusupov','Ismoilov','Qodirov','Abdullayev')
    ),
    DATEADD(YEAR, -(18 + ABS(CHECKSUM(NEWID())) % 40), GETDATE()),
    CONCAT('user', n, '@mail.com'),
    CONCAT('+9989', ABS(CHECKSUM(NEWID())) % 9000000 + 1000000),
    CHOOSE(ABS(CHECKSUM(NEWID())) % 5 + 1,'Tashkent','Samarkand','Bukhara','Namangan','Andijan'),
    CONCAT('ID', n),
    CONCAT('TAX', n),
    CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1,'Employed','Student','Unemployed'),
    ABS(CHECKSUM(NEWID())) % 20000 + 1000,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 1000, GETDATE()),
    GETDATE()
FROM #Numbers;
select * from Customers


CREATE TABLE Accounts (
    AccountID INT PRIMARY KEY,
    CustomerID INT,
    AccountType NVARCHAR(50),
    Balance DECIMAL(12,2),
    Currency NVARCHAR(10),
    Status NVARCHAR(20),
    BranchID INT,
    CreatedDate DATETIME,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID),
    FOREIGN KEY (BranchID) REFERENCES Branches(BranchID)
);
INSERT INTO Accounts
SELECT TOP 15000
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
    ABS(CHECKSUM(NEWID())) % 10000 + 1,
    CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1,'Savings','Checking','Business'),
    ABS(CHECKSUM(NEWID())) % 100000 + 100,
    'UZS',
    CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1,'Active','Blocked','Closed'),
    ABS(CHECKSUM(NEWID())) % 5 + 1,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 1000, GETDATE())
FROM sys.objects a CROSS JOIN sys.objects b;


CREATE TABLE Transactions (
    TransactionID INT PRIMARY KEY,
    AccountID INT,
    TransactionType NVARCHAR(50),
    Amount DECIMAL(12,2),
    Currency NVARCHAR(10),
    Date DATETIME,
    Status NVARCHAR(20),
    ReferenceNo NVARCHAR(50),
    FOREIGN KEY (AccountID) REFERENCES Accounts(AccountID)
);



-- Transactions jadvaliga realistik ma'lumotlar qo'shish
-- Agar Accounts jadvali mavjud bo'lsa, undagi AccountID lardan foydalanamiz
INSERT INTO Transactions (TransactionID, AccountID, TransactionType, Amount, Currency, Date, Status, ReferenceNo)
SELECT 
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS TransactionID,
    AccountID,
    -- TransactionType: turli xil transaction turlari
    CHOOSE(ABS(CHECKSUM(NEWID())) % 5 + 1, 
        'Transfer', 
        'Withdrawal', 
        'Deposit', 
        'Payment', 
        'Wire Transfer'
    ) AS TransactionType,
    -- Amount: UZS da, ba'zilari katta ($10,000 = 130,000,000 UZS)
    CASE 
        -- 5% transactionlar katta (130M dan yuqori)
        WHEN ABS(CHECKSUM(NEWID())) % 100 < 5 THEN 
            ABS(CHECKSUM(NEWID())) % 270000000 + 130000000  -- 130M dan 400M gacha
        -- 15% transactionlar o'rta (10M - 130M)
        WHEN ABS(CHECKSUM(NEWID())) % 100 < 20 THEN 
            ABS(CHECKSUM(NEWID())) % 120000000 + 10000000  -- 10M dan 130M gacha
        -- Qolganlari kichik transactionlar
        ELSE 
            ABS(CHECKSUM(NEWID())) % 10000000 + 100000  -- 100K dan 10.1M gacha
    END AS Amount,
    'UZS' AS Currency,  -- Barcha transactionlar UZS da
    -- Realistik vaqtlar: oxirgi 90 kun ichida, turli vaqtlarda
    DATEADD(MINUTE, 
        ABS(CHECKSUM(NEWID())) % (24 * 60 * 90),  -- 90 kun * 24 soat * 60 daqiqa
        DATEADD(DAY, -90, GETDATE())  -- 90 kun oldindan boshlab
    ) AS Date,
    -- Status: 80% Completed, 10% Pending, 5% Failed, 5% Cancelled
    CASE 
        WHEN ABS(CHECKSUM(NEWID())) % 100 < 80 THEN 'Completed'
        WHEN ABS(CHECKSUM(NEWID())) % 100 < 90 THEN 'Pending'
        WHEN ABS(CHECKSUM(NEWID())) % 100 < 95 THEN 'Failed'
        ELSE 'Cancelled'
    END AS Status,
    -- Reference number
    CONCAT('REF', 
        UPPER(LEFT(NEWID(), 8)), 
        ABS(CHECKSUM(NEWID())) % 10000
    ) AS ReferenceNo
FROM (
    -- Accounts jadvalidan AccountID larni olish
    -- Agar Accounts jadvali bo'lmasa, CustomerID dan foydalanib Account yaratish kerak
    SELECT AccountID 
    FROM Accounts 
    WHERE AccountID IS NOT NULL
) a
CROSS JOIN (
    -- Har bir account uchun 3-10 transaction yaratamiz
    SELECT TOP 10 * FROM #Numbers
) n
WHERE a.AccountID <= 10000  -- Birinchi 10000 account uchun
ORDER BY NEWID();

-- TransactionID larni tartiblash (agar ketma-ket bo'lishini xohlasangiz)
WITH TransactionNumbering AS (
    SELECT 
        TransactionID,
        ROW_NUMBER() OVER (ORDER BY Date) AS NewTransactionID
    FROM Transactions
)
UPDATE t
SET t.TransactionID = tn.NewTransactionID
FROM Transactions t
INNER JOIN TransactionNumbering tn ON t.TransactionID = tn.TransactionID;

ALTER TABLE Transactions
ADD Country NVARCHAR(50);
UPDATE Transactions
SET Country = CHOOSE(ABS(CHECKSUM(NEWID())) % 5 + 1,
    'Uzbekistan','USA','Germany','UK','UAE');

CREATE TABLE Branches (
    BranchID INT PRIMARY KEY,
    BranchName NVARCHAR(100),
    Address NVARCHAR(200),
    City NVARCHAR(50),
    State NVARCHAR(50),
    Country NVARCHAR(50),
    ManagerID INT NULL,
    ContactNumber NVARCHAR(20)
);

CREATE TABLE Employees (
    EmployeeID INT PRIMARY KEY,
    BranchID INT,
    FullName NVARCHAR(100),
    Position NVARCHAR(50),
    Department NVARCHAR(50),
    Salary DECIMAL(12,2),
    HireDate DATE,
    Status NVARCHAR(20),
    FOREIGN KEY (BranchID) REFERENCES Branches(BranchID)
);
INSERT INTO Employees
SELECT TOP 200
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
    ABS(CHECKSUM(NEWID())) % 5 + 1,
    CONCAT('Employee_', ROW_NUMBER() OVER (ORDER BY (SELECT NULL))),
    CHOOSE(ABS(CHECKSUM(NEWID())) % 4 + 1,'Manager','Clerk','Analyst','Cashier'),
    'Operations',
    ABS(CHECKSUM(NEWID())) % 3000 + 500,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 2000, GETDATE()),
    'Active'
FROM sys.objects;

INSERT INTO Branches (BranchID, BranchName, Address, City, State, Country, ManagerID, ContactNumber)
VALUES
(1,'Tashkent Central','Main Street','Tashkent','Tashkent','Uzbekistan',NULL,'+998901111111'),
(2,'Chilonzor Branch','Chilonzor','Tashkent','Tashkent','Uzbekistan',NULL,'+998902222222'),
(3,'Samarkand Main','Registan','Samarkand','Samarkand','Uzbekistan',NULL,'+998903333333'),
(4,'Bukhara Center','Old City','Bukhara','Bukhara','Uzbekistan',NULL,'+998904444444'),
(5,'Fergana Branch','Center','Fergana','Fergana','Uzbekistan',NULL,'+998905555555');


-- Digital Banking & Payments

CREATE TABLE CreditCards (
    CardID INT PRIMARY KEY,
    CustomerID INT,
    CardNumber NVARCHAR(20),
    CardType NVARCHAR(20),
    CVV NVARCHAR(5),
    ExpiryDate DATE,
    CreditLimit DECIMAL(12,2),
    Status NVARCHAR(20),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
INSERT INTO CreditCards
SELECT 
    n,                              -- CardID
    n,                              -- CustomerID (1:1 mapping)
    CONCAT('8600', RIGHT('0000000000' + CAST(n AS VARCHAR), 10)),
    CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1,'VISA','MasterCard','HUMO'),
    RIGHT('000' + CAST(ABS(CHECKSUM(NEWID())) % 1000 AS VARCHAR),3),
    DATEADD(YEAR, 2 + ABS(CHECKSUM(NEWID())) % 3, GETDATE()),
    ABS(CHECKSUM(NEWID())) % 10000 + 1000,
    CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1,'Active','Blocked','Expired')
FROM #Numbers;


CREATE TABLE CreditCardTransactions (
    TransactionID INT PRIMARY KEY,
    CardID INT,
    Merchant NVARCHAR(100),
    Amount DECIMAL(12,2),
    Currency NVARCHAR(10),
    Date DATETIME,
    Status NVARCHAR(20),
    FOREIGN KEY (CardID) REFERENCES CreditCards(CardID)
);
INSERT INTO CreditCardTransactions
SELECT TOP 20000
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
    ABS(CHECKSUM(NEWID())) % 10000 + 1,   -- existing CardID
    CHOOSE(ABS(CHECKSUM(NEWID())) % 6 + 1,
        'Amazon','Uzum Market','KorZinka','Havas','Payme','Click'),
    ABS(CHECKSUM(NEWID())) % 2000 + 10,
    'UZS',
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE()),
    CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1,'Success','Failed','Pending')
FROM sys.objects a CROSS JOIN sys.objects b;


CREATE TABLE OnlineBankingUsers (
    UserID INT PRIMARY KEY,
    CustomerID INT,
    Username NVARCHAR(50),
    PasswordHash NVARCHAR(200),
    LastLogin DATETIME,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
INSERT INTO OnlineBankingUsers
SELECT 
    n,
    n,
    CONCAT('user', n),
    CONCAT('hash_', n),
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 30, GETDATE())
FROM #Numbers;


CREATE TABLE BillPayments (
    PaymentID INT PRIMARY KEY,
    CustomerID INT,
    BillerName NVARCHAR(100),
    Amount DECIMAL(12,2),
    Date DATETIME,
    Status NVARCHAR(20),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
INSERT INTO BillPayments
SELECT 
    n,
    n,
    CHOOSE(ABS(CHECKSUM(NEWID())) % 5 + 1,
        'Electricity','Gas','Water','Internet','Mobile'),
    ABS(CHECKSUM(NEWID())) % 500 + 50,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 180, GETDATE()),
    CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1,'Paid','Pending','Failed')
FROM #Numbers;

CREATE TABLE MobileBankingTransactions (
    TransactionID INT PRIMARY KEY,
    CustomerID INT,
    DeviceID NVARCHAR(50),
    AppVersion NVARCHAR(20),
    TransactionType NVARCHAR(50),
    Amount DECIMAL(12,2),
    Date DATETIME,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
INSERT INTO MobileBankingTransactions
SELECT 
    n,
    n,
    CONCAT('device_', ABS(CHECKSUM(NEWID())) % 10000),
    CONCAT('v', ABS(CHECKSUM(NEWID())) % 5 + 1, '.0'),
    CHOOSE(ABS(CHECKSUM(NEWID())) % 4 + 1,
        'Transfer','Payment','TopUp','Withdrawal'),
    ABS(CHECKSUM(NEWID())) % 3000 + 50,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 90, GETDATE())
FROM #Numbers;

-- Loans & Credit

CREATE TABLE Loans (
    LoanID INT PRIMARY KEY,
    CustomerID INT,
    LoanType NVARCHAR(50),
    Amount DECIMAL(12,2),
    InterestRate DECIMAL(5,2),
    StartDate DATE,
    EndDate DATE,
    Status NVARCHAR(20),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
INSERT INTO Loans
SELECT TOP 5000
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
    ABS(CHECKSUM(NEWID())) % 10000 + 1,
    CHOOSE(ABS(CHECKSUM(NEWID())) % 4 + 1,
        'Mortgage','Personal','Auto','Business'),
    ABS(CHECKSUM(NEWID())) % 50000 + 1000,
    (ABS(CHECKSUM(NEWID())) % 20) + 5, -- 5% - 25%
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 1000, GETDATE()),
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 1000, GETDATE()),
    CASE 
        WHEN ABS(CHECKSUM(NEWID())) % 5 = 0 THEN 'Default'
        WHEN ABS(CHECKSUM(NEWID())) % 3 = 0 THEN 'Closed'
        ELSE 'Active'
    END
FROM sys.objects;


CREATE TABLE LoanPayments (
    PaymentID INT PRIMARY KEY,
    LoanID INT,
    AmountPaid DECIMAL(12,2),
    PaymentDate DATE,
    RemainingBalance DECIMAL(12,2),
    FOREIGN KEY (LoanID) REFERENCES Loans(LoanID)
);
INSERT INTO LoanPayments
SELECT TOP 10000
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
    l.LoanID,
    ABS(CHECKSUM(NEWID())) % 2000 + 100,
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 365, l.StartDate),
    l.Amount - (ABS(CHECKSUM(NEWID())) % l.Amount)
FROM Loans l
CROSS JOIN sys.objects;



CREATE TABLE CreditScores (
    CustomerID INT PRIMARY KEY,
    CreditScore INT,
    UpdatedAt DATETIME,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
INSERT INTO CreditScores
SELECT 
    n,
    ABS(CHECKSUM(NEWID())) % 550 + 300, -- 300–850
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE())
FROM #Numbers;


CREATE TABLE DebtCollection (
    DebtID INT PRIMARY KEY,
    CustomerID INT,
    AmountDue DECIMAL(12,2),
    DueDate DATE,
    CollectorAssigned NVARCHAR(100),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
INSERT INTO DebtCollection
SELECT TOP 2000
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
    ABS(CHECKSUM(NEWID())) % 10000 + 1,
    ABS(CHECKSUM(NEWID())) % 20000 + 500,
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 180, GETDATE()),
    CONCAT('Collector_', ABS(CHECKSUM(NEWID())) % 50)
FROM sys.objects;

--Compliance & Risk Management

CREATE TABLE KYC (
    KYCID INT PRIMARY KEY,
    CustomerID INT,
    DocumentType NVARCHAR(50),
    DocumentNumber NVARCHAR(50),
    VerifiedBy NVARCHAR(100),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
INSERT INTO KYC
SELECT 
    n,
    n,
    CHOOSE(ABS(CHECKSUM(NEWID())) % 4 + 1,
        'Passport','ID Card','Driver License','Residence Permit'),
    CONCAT('DOC', n),
    CONCAT('Officer_', ABS(CHECKSUM(NEWID())) % 100)
FROM #Numbers;

CREATE TABLE FraudDetection (
    FraudID INT PRIMARY KEY,
    CustomerID INT,
    TransactionID INT,
    RiskLevel NVARCHAR(20),
    ReportedDate DATE,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
INSERT INTO FraudDetection
SELECT TOP 3000
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
    a.CustomerID,     -- real FK
    t.TransactionID,
    CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1, 'Low','Medium','High'),
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 180, GETDATE())
FROM Transactions t
JOIN Accounts a ON t.AccountID = a.AccountID;

CREATE TABLE AMLCases (
    CaseID INT PRIMARY KEY,
    CustomerID INT,
    CaseType NVARCHAR(50),
    Status NVARCHAR(20),
    InvestigatorID INT,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
INSERT INTO AMLCases
SELECT TOP 2000
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
    ABS(CHECKSUM(NEWID())) % 10000 + 1,
    CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1,
        'Money Laundering','Suspicious Transfer','Fraud'),
    CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1,
        'Open','Investigating','Closed'),
    ABS(CHECKSUM(NEWID())) % 200 + 1
FROM sys.objects;


CREATE TABLE RegulatoryReports (
    ReportID INT PRIMARY KEY,
    ReportType NVARCHAR(50),
    SubmissionDate DATE
);

INSERT INTO RegulatoryReports
SELECT TOP 100
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
    CHOOSE(ABS(CHECKSUM(NEWID())) % 4 + 1,
        'Monthly Report','Quarterly Report','Annual Report','Audit Report'),
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE())
FROM sys.objects;
truncate table RegulatoryReports

-- Human Resources & Payroll

CREATE TABLE Departments (
    DepartmentID INT PRIMARY KEY,
    DepartmentName NVARCHAR(50),
    ManagerID INT
);
INSERT INTO Departments
VALUES
(1,'Operations',1),
(2,'IT',2),
(3,'Finance',3),
(4,'HR',4),
(5,'Risk Management',5);


CREATE TABLE Salaries (
    SalaryID INT PRIMARY KEY,
    EmployeeID INT,
    BaseSalary DECIMAL(12,2),
    Bonus DECIMAL(12,2),
    Deductions DECIMAL(12,2),
    PaymentDate DATE,
    FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID)
);
INSERT INTO Salaries
SELECT 
    e.EmployeeID,
    e.EmployeeID,
    e.Salary,
    ABS(CHECKSUM(NEWID())) % 500,
    ABS(CHECKSUM(NEWID())) % 200,
    DATEADD(MONTH, -ABS(CHECKSUM(NEWID())) % 12, GETDATE())
FROM Employees e;


CREATE TABLE EmployeeAttendance (
    AttendanceID INT PRIMARY KEY,
    EmployeeID INT,
    CheckInTime DATETIME,
    CheckOutTime DATETIME,
    TotalHours INT,
    FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID)
);
INSERT INTO EmployeeAttendance
SELECT TOP 5000
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
    e.EmployeeID,
    DATEADD(HOUR, 9, CAST(GETDATE() AS DATETIME)),  -- CheckIn
    DATEADD(HOUR, 18, CAST(GETDATE() AS DATETIME)), -- CheckOut
    9
FROM Employees e
CROSS JOIN sys.objects;

--Investments & Treasury

CREATE TABLE Investments (
    InvestmentID INT PRIMARY KEY,
    CustomerID INT,
    InvestmentType NVARCHAR(50),
    Amount DECIMAL(12,2),
    ROI DECIMAL(5,2),
    MaturityDate DATE,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
INSERT INTO Investments
SELECT 
    n,
    n,
    CHOOSE(ABS(CHECKSUM(NEWID())) % 4 + 1,
        'Stocks','Bonds','Real Estate','Crypto'),
    ABS(CHECKSUM(NEWID())) % 50000 + 1000,
    (ABS(CHECKSUM(NEWID())) % 20) + 5,
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 1000, GETDATE())
FROM #Numbers;

CREATE TABLE StockTradingAccounts (
    AccountID INT PRIMARY KEY,
    CustomerID INT,
    BrokerageFirm NVARCHAR(100),
    TotalInvested DECIMAL(12,2),
    CurrentValue DECIMAL(12,2),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
INSERT INTO StockTradingAccounts
SELECT 
    n,
    n,
    CHOOSE(ABS(CHECKSUM(NEWID())) % 4 + 1,
        'Interactive Brokers','Robinhood','eToro','Freedom Finance'),
    ABS(CHECKSUM(NEWID())) % 100000,
    ABS(CHECKSUM(NEWID())) % 120000
FROM #Numbers;


CREATE TABLE ForeignExchange (
    FXID INT PRIMARY KEY,
    CustomerID INT,
    CurrencyPair NVARCHAR(20),
    ExchangeRate DECIMAL(10,4),
    AmountExchanged DECIMAL(12,2),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
INSERT INTO ForeignExchange
SELECT 
    n,
    n,
    CHOOSE(ABS(CHECKSUM(NEWID())) % 4 + 1,
        'USD/UZS','EUR/UZS','RUB/UZS','GBP/UZS'),
    CAST((ABS(CHECKSUM(NEWID())) % 10000) / 100.0 AS DECIMAL(10,4)),
    ABS(CHECKSUM(NEWID())) % 10000 + 100
FROM #Numbers;


-- Insurance & Security

CREATE TABLE InsurancePolicies (
    PolicyID INT PRIMARY KEY,
    CustomerID INT,
    InsuranceType NVARCHAR(50),
    PremiumAmount DECIMAL(12,2),
    CoverageAmount DECIMAL(12,2),
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
INSERT INTO InsurancePolicies
SELECT 
    n,
    n,
    CHOOSE(ABS(CHECKSUM(NEWID())) % 4 + 1,
        'Health','Car','Property','Life'),
    ABS(CHECKSUM(NEWID())) % 2000 + 100,
    ABS(CHECKSUM(NEWID())) % 100000 + 5000
FROM #Numbers;

CREATE TABLE Claims (
    ClaimID INT PRIMARY KEY,
    PolicyID INT,
    ClaimAmount DECIMAL(12,2),
    Status NVARCHAR(20),
    FiledDate DATE,
    FOREIGN KEY (PolicyID) REFERENCES InsurancePolicies(PolicyID)
);
INSERT INTO Claims
SELECT TOP 5000
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
    p.PolicyID,
    ABS(CHECKSUM(NEWID())) % 50000 + 500,
    CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1,
        'Approved','Pending','Rejected'),
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE())
FROM InsurancePolicies p;

CREATE TABLE UserAccessLogs (
    LogID INT PRIMARY KEY,
    UserID INT,
    ActionType NVARCHAR(50),
    Timestamp DATETIME
);
INSERT INTO UserAccessLogs
SELECT 
    n,
    n,
    CHOOSE(ABS(CHECKSUM(NEWID())) % 4 + 1,
        'Login','Logout','Transfer','Password Change'),
    DATEADD(MINUTE, -ABS(CHECKSUM(NEWID())) % 10000, GETDATE())
FROM #Numbers;

CREATE TABLE CyberSecurityIncidents (
    IncidentID INT PRIMARY KEY,
    AffectedSystem NVARCHAR(100),
    ReportedDate DATE,
    ResolutionStatus NVARCHAR(50)
);
INSERT INTO CyberSecurityIncidents
SELECT TOP 200
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
    CHOOSE(ABS(CHECKSUM(NEWID())) % 4 + 1,
        'Mobile App','Web Banking','ATM System','Database'),
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE()),
    CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1,
        'Resolved','Investigating','Critical')
FROM sys.objects;

CREATE TABLE Merchants (
    MerchantID INT PRIMARY KEY,
    MerchantName NVARCHAR(100),
    Industry NVARCHAR(50),
    Location NVARCHAR(100),
    CustomerID INT,
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);
INSERT INTO Merchants
SELECT 
    n,
    CONCAT('Merchant_', n),
    CHOOSE(ABS(CHECKSUM(NEWID())) % 5 + 1,
        'Retail','Food','Tech','Services','E-commerce'),
    CHOOSE(ABS(CHECKSUM(NEWID())) % 5 + 1,
        'Tashkent','Samarkand','Bukhara','Fergana','Namangan'),
    n
FROM #Numbers;

CREATE TABLE MerchantTransactions (
    TransactionID INT PRIMARY KEY,
    MerchantID INT,
    Amount DECIMAL(12,2),
    PaymentMethod NVARCHAR(50),
    Date DATETIME,
    FOREIGN KEY (MerchantID) REFERENCES Merchants(MerchantID)
);
INSERT INTO MerchantTransactions
SELECT TOP 20000
    ROW_NUMBER() OVER (ORDER BY (SELECT NULL)),
    m.MerchantID,
    ABS(CHECKSUM(NEWID())) % 5000 + 50,
    CHOOSE(ABS(CHECKSUM(NEWID())) % 3 + 1,
        'Card','Cash','Online'),
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE())
FROM Merchants m
CROSS JOIN sys.objects;

                     -- KPI ! 

-- 1. Top 3 Customers with the Highest Total Balance Across All Accounts 

select * from Accounts
select * from Customers

select top 3 c.customerID, c.Fullname,  sum(a.Balance) as totalBalance
from Customers c
join Accounts a
on c.CustomerID=a.CustomerID
group by c.customerID, c.FullName 
order by totalBalance desc


-- 2. Customers Who Have More Than One Active Loan

select * from Customers
select * from Loans

select c.CustomerID, count(l.LoanID) as numbLoans, c.FullName 
from Customers c
join Loans l
on c.CustomerID=l.CustomerID
where l.Status='Active'
group by c.CustomerID,c.FullName
having count(l.LoanID) > 1 


--3. Transactions That Were Flagged as Fraudulent  

select * from Transactions
select * from FraudDetection

select t.transactionID, f.RiskLevel from Transactions t
join FraudDetection f
on t.TransactionID=f.TransactionID
where f.RiskLevel='High'


--4. Total Loan Amount Issued Per Branch

select * from Loans
select * from Branches
select * from Accounts

select b.BranchID, b.BranchName, sum(l.Amount) as TotalLoanAmount
from Loans l
join Accounts a
on l.CustomerID=a.CustomerID
join Branches b 
on a.BranchID=b.BranchID
group by b.BranchID, b.BranchName
order by TotalLoanAmount desc


--5. Customers who made multiple large transactions (above $10,000) 
--within a short time frame (less than 1 hour apart)

select * from Transactions
select * from Customers
select * from Accounts

;with cte as 
(select *, 
lead(Date) over (order by Date) as nexttransaction,
lead(Amount) over (order by Amount) as nextAmount
from Transactions )
select ct.CustomerID,
ct.FullName,
c.TransactionID,
c.Amount,
c.nextAmount,
c.Date,
c.nexttransaction,
datediff(MINUTE, c.Date, c.nexttransaction) as diff
from cte c
join Accounts a 
on c.AccountID=a.AccountID
join Customers ct
on a.CustomerID=ct.CustomerID
where nextAmount > 121550000 and 
datediff(MINUTE, c.Date, nexttransaction) < 60 
order by diff desc, ct.CustomerID

-- 6. Customers who have made transactions from different countries within 10 minutes, 
--a common red flag for fraud.

select * from Transactions
select * from Customers
select * from Accounts


select distinct
t.TransactionID, c.FullName  from Transactions t
join Transactions t2
on t.AccountID=t2.AccountID
and t.TransactionID <> t2.TransactionID
join Accounts a
on t.AccountID=a.AccountID
join Customers c
on a.CustomerID=c.CustomerID
where t.Country<>t2.Country and
datediff(MINUTE, t.Date, t2.Date) > 10


