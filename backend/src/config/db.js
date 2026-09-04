const { Pool } = require('pg');
const path = require('path');

const nodeEnv = process.env.NODE_ENV || 'development';
require('dotenv').config({ path: path.join(__dirname, `../../.env.${nodeEnv}`) });

const pool = new Pool({
  user: process.env.PGUSER,
  host: process.env.PGHOST,
  database: process.env.PGDATABASE,
  password: process.env.PGPASSWORD,
  port: process.env.PGPORT,
  max: 20,
  idleTimeoutMillis: 30000,
  ssl: process.env.PGHOST && process.env.PGHOST !== 'localhost' ? { rejectUnauthorized: false } : false,
});

const runMigrations = async () => {
  const tableDDLs = [
    `CREATE TABLE IF NOT EXISTS shifts (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      "startTime" TEXT NOT NULL,
      "endTime" TEXT NOT NULL,
      company TEXT NOT NULL,
      "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`,
    `CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      "fullName" TEXT NOT NULL,
      email TEXT UNIQUE NOT NULL,
      "mobileNumber" TEXT UNIQUE NOT NULL,
      password TEXT NOT NULL,
      role TEXT DEFAULT 'employee',
      company TEXT NOT NULL,
      department TEXT,
      experience TEXT,
      technologies TEXT,
      address TEXT,
      gender TEXT,
      latitude DOUBLE PRECISION,
      longitude DOUBLE PRECISION,
      "profilePicture" TEXT,
      "shiftId" INTEGER REFERENCES shifts(id),
      "isActive" INTEGER DEFAULT 1,
      "isApproved" INTEGER DEFAULT 1,
      "biometricToken" TEXT,
      "fcmToken" TEXT,
      "rejectionReason" TEXT,
      salary NUMERIC(10, 2),
      "weekOffs" TEXT,
      "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`,
    `CREATE TABLE IF NOT EXISTS attendance (
      id SERIAL PRIMARY KEY,
      "userId" INTEGER REFERENCES users(id),
      "checkInTime" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      "checkOutTime" TIMESTAMP,
      "checkInLat" DOUBLE PRECISION,
      "checkInLong" DOUBLE PRECISION,
      "checkOutLat" DOUBLE PRECISION,
      "checkOutLong" DOUBLE PRECISION,
      "checkInAddress" TEXT,
      "checkOutAddress" TEXT,
      "checkInPhoto" TEXT,
      "checkOutPhoto" TEXT,
      "isOutside" INTEGER DEFAULT 0,
      "totalHours" DOUBLE PRECISION DEFAULT 0
    )`,
    `CREATE TABLE IF NOT EXISTS leaves (
      id SERIAL PRIMARY KEY,
      "userId" INTEGER REFERENCES users(id),
      "leaveType" TEXT NOT NULL,
      "startDate" DATE NOT NULL,
      "endDate" DATE NOT NULL,
      reason TEXT,
      status TEXT DEFAULT 'pending',
      "rejectionReason" TEXT,
      "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`,
    `CREATE TABLE IF NOT EXISTS notifications (
      id SERIAL PRIMARY KEY,
      "userId" INTEGER REFERENCES users(id),
      title TEXT NOT NULL,
      message TEXT NOT NULL,
      "isRead" INTEGER DEFAULT 0,
      "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`,
    `CREATE TABLE IF NOT EXISTS otps (
      id SERIAL PRIMARY KEY,
      email TEXT,
      "mobileNumber" TEXT,
      otp TEXT NOT NULL,
      "expiresAt" TIMESTAMP NOT NULL,
      "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`,
    `CREATE TABLE IF NOT EXISTS payslips (
      id SERIAL PRIMARY KEY,
      "userId" INTEGER REFERENCES users(id),
      month INTEGER NOT NULL,
      year INTEGER NOT NULL,
      "basicSalary" NUMERIC(10, 2),
      allowances NUMERIC(10, 2) DEFAULT 0,
      deductions NUMERIC(10, 2) DEFAULT 0,
      "netSalary" NUMERIC(10, 2),
      "pdfPath" TEXT,
      "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`,
    `CREATE TABLE IF NOT EXISTS settings (
      id SERIAL PRIMARY KEY,
      company TEXT UNIQUE NOT NULL,
      "companyName" TEXT,
      "geofenceEnabled" INTEGER DEFAULT 0,
      "payrollEnabled" INTEGER DEFAULT 1,
      "cameraAuthEnabled" INTEGER DEFAULT 1,
      "officeRadiusMeters" INTEGER DEFAULT 200,
      "workingDays" TEXT,
      "weekendDays" TEXT,
      "themeColor" TEXT,
      "secondaryColor" TEXT,
      "accentColor" TEXT,
      "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )`
  ];

  for (const sql of tableDDLs) {
    try {
      await pool.query(sql);
    } catch (err) {
      console.error('[TABLE CREATION ERROR]', err.message);
    }
  }

  const alterMigrations = [
    `ALTER TABLE users ADD COLUMN IF NOT EXISTS "biometricToken" TEXT`,
    `ALTER TABLE users ADD COLUMN IF NOT EXISTS "fcmToken" TEXT`,
    `ALTER TABLE users ADD COLUMN IF NOT EXISTS "rejectionReason" TEXT`,
    `ALTER TABLE attendance ADD COLUMN IF NOT EXISTS "isOutside" INTEGER DEFAULT 0`,
    `ALTER TABLE IF EXISTS shifts ENABLE ROW LEVEL SECURITY`,
    `ALTER TABLE IF EXISTS users ENABLE ROW LEVEL SECURITY`,
    `ALTER TABLE IF EXISTS attendance ENABLE ROW LEVEL SECURITY`,
    `ALTER TABLE IF EXISTS leaves ENABLE ROW LEVEL SECURITY`,
    `ALTER TABLE IF EXISTS notifications ENABLE ROW LEVEL SECURITY`,
    `ALTER TABLE IF EXISTS otps ENABLE ROW LEVEL SECURITY`,
    `ALTER TABLE IF EXISTS payslips ENABLE ROW LEVEL SECURITY`,
    `ALTER TABLE IF EXISTS settings ENABLE ROW LEVEL SECURITY`
  ];
  for (const sql of alterMigrations) {
    try { 
      await pool.query(sql); 
    } catch (err) { 
      console.error('[MIGRATION ERROR]', err.message); 
    }
  }
  console.log('[MIGRATIONS] Schema and tables up to date on Supabase.');
};

module.exports = {
  pool,
  runMigrations,
};
