-- Clean up existing tables
DROP TABLE IF EXISTS settings CASCADE;
DROP TABLE IF EXISTS otps CASCADE;
DROP TABLE IF EXISTS payslips CASCADE;
DROP TABLE IF EXISTS holidays CASCADE;
DROP TABLE IF EXISTS leave_balances CASCADE;
DROP TABLE IF EXISTS leave_policies CASCADE;
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS leaves CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS shifts CASCADE;

-- Users Table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    "fullName" TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    "mobileNumber" TEXT UNIQUE NOT NULL,
    gender TEXT,
    password TEXT NOT NULL,
    role TEXT DEFAULT 'User',
    company TEXT,
    department TEXT,
    experience TEXT,
    technologies TEXT,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    "profilePicture" TEXT,
    salary DOUBLE PRECISION DEFAULT 0,
    "shiftId" INTEGER,
    "isActive" INTEGER DEFAULT 1,
    "isApproved" INTEGER DEFAULT 0,
    "rejectionReason" TEXT,
    "weekOffs" TEXT DEFAULT 'Sunday',
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Attendance Table
CREATE TABLE attendance (
    id SERIAL PRIMARY KEY,
    "userId" INTEGER REFERENCES users(id),
    "checkInTime" TIMESTAMP,
    "checkInLat" DOUBLE PRECISION,
    "checkInLong" DOUBLE PRECISION,
    "checkInAddress" TEXT,
    "checkInPhoto" TEXT,
    "checkOutTime" TIMESTAMP,
    "checkOutLat" DOUBLE PRECISION,
    "checkOutLong" DOUBLE PRECISION,
    "checkOutAddress" TEXT,
    "checkOutPhoto" TEXT,
    status TEXT DEFAULT 'Present',
    "minutesLate" INTEGER DEFAULT 0,
    "overtimeHours" DOUBLE PRECISION DEFAULT 0,
    "isManual" INTEGER DEFAULT 0,
    "editedBy" INTEGER,
    "minutesOvertime" INTEGER DEFAULT 0,
    "earlyLeaveMinutes" INTEGER DEFAULT 0,
    "shiftId" INTEGER,
    penalty DOUBLE PRECISION DEFAULT 0
);
CREATE INDEX idx_attendance_user ON attendance("userId");
CREATE INDEX idx_attendance_time ON attendance("checkInTime");

-- OTP Table
CREATE TABLE otps (
    id SERIAL PRIMARY KEY,
    "mobileNumber" TEXT,
    email TEXT,
    otp TEXT NOT NULL,
    "expiresAt" TIMESTAMP NOT NULL
);

-- Leaves Table
CREATE TABLE leaves (
    id SERIAL PRIMARY KEY,
    "userId" INTEGER REFERENCES users(id),
    "leaveType" TEXT DEFAULT 'Casual Leave',
    "startDate" TEXT NOT NULL,
    "endDate" TEXT NOT NULL,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'Pending',
    "rejectionReason" TEXT,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_leaves_user ON leaves("userId");

-- Notifications Table
CREATE TABLE notifications (
    id SERIAL PRIMARY KEY,
    "userId" INTEGER REFERENCES users(id),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    "isRead" INTEGER DEFAULT 0,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_notifications_user ON notifications("userId");

-- Leave Policies Table
CREATE TABLE leave_policies (
    id SERIAL PRIMARY KEY,
    "leaveType" TEXT NOT NULL,
    "daysPerYear" INTEGER DEFAULT 10,
    "isPaid" INTEGER DEFAULT 1,
    company TEXT,
    UNIQUE("leaveType", company)
);

-- Leave Balances Table
CREATE TABLE leave_balances (
    id SERIAL PRIMARY KEY,
    "userId" INTEGER REFERENCES users(id),
    "leaveType" TEXT NOT NULL,
    "totalDays" INTEGER DEFAULT 10,
    UNIQUE("userId", "leaveType")
);

-- Holidays Table
CREATE TABLE holidays (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    date TEXT NOT NULL,
    type TEXT DEFAULT 'Public',
    duration TEXT DEFAULT 'Full Day',
    company TEXT,
    UNIQUE(date, company)
);

-- Payslips Table
CREATE TABLE payslips (
    id SERIAL PRIMARY KEY,
    "userId" INTEGER REFERENCES users(id),
    company TEXT,
    month INTEGER,
    year INTEGER,
    "basicSalary" DOUBLE PRECISION,
    allowances DOUBLE PRECISION DEFAULT 0,
    deductions DOUBLE PRECISION DEFAULT 0,
    "netSalary" DOUBLE PRECISION,
    "generatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Shifts Table
CREATE TABLE shifts (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    "startTime" TEXT NOT NULL,
    "endTime" TEXT NOT NULL,
    "gracePeriodMins" INTEGER DEFAULT 0,
    "overtimeRate" DOUBLE PRECISION DEFAULT 1.0,
    "latePenaltyPerMin" DOUBLE PRECISION DEFAULT 0,
    company TEXT
);

-- Settings Table
CREATE TABLE settings (
    id SERIAL PRIMARY KEY,
    "companyName" TEXT,
    company TEXT UNIQUE,
    "officeLat" DOUBLE PRECISION,
    "officeLong" DOUBLE PRECISION,
    "officeRadiusMeters" DOUBLE PRECISION DEFAULT 100,
    "geofenceEnabled" INTEGER DEFAULT 1,
    "payrollEnabled" INTEGER DEFAULT 1,
    "workingDays" TEXT DEFAULT '["Mon","Tue","Wed","Thu","Fri"]',
    "weekendDays" TEXT DEFAULT '["Sat","Sun"]',
    "companyLogo" TEXT,
    "themeColor" TEXT,
    "secondaryColor" TEXT,
    "accentColor" TEXT,
    "cameraAuthEnabled" INTEGER DEFAULT 1
);

-- =========================================
-- Performance Optimization Indexes
-- =========================================
-- Users table: speeds up admin company filtering
CREATE INDEX IF NOT EXISTS idx_users_company ON users(company);

-- Attendance table: speeds up finding active sessions & late stats
CREATE INDEX IF NOT EXISTS idx_attendance_checkout ON attendance("checkOutTime");
CREATE INDEX IF NOT EXISTS idx_attendance_status ON attendance(status);

-- Leaves table: speeds up leave balance and absence calculations
CREATE INDEX IF NOT EXISTS idx_leaves_status ON leaves(status);
CREATE INDEX IF NOT EXISTS idx_leaves_dates ON leaves("startDate", "endDate");

-- Payslips table: speeds up payroll loads
CREATE INDEX IF NOT EXISTS idx_payslips_company_date ON payslips(company, year, month);

