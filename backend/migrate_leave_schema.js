const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('./time_tracker_dev.db');

db.serialize(() => {
  console.log('--- Starting Leave Policies Schema Migration ---');
  
  // 1. Create new table
  db.run(`CREATE TABLE IF NOT EXISTS leave_policies_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    leaveType TEXT NOT NULL,
    daysPerYear INTEGER DEFAULT 10,
    isPaid INTEGER DEFAULT 1,
    company TEXT,
    UNIQUE(leaveType, company)
  )`);

  // 2. Copy data (carefully handling possible duplicates if they existed, though unique constraint prevented them)
  db.run(`INSERT INTO leave_policies_new (leaveType, daysPerYear, isPaid, company)
          SELECT leaveType, daysPerYear, isPaid, company FROM leave_policies`);

  // 3. Drop old table and rename new one
  db.run(`DROP TABLE leave_policies`);
  db.run(`ALTER TABLE leave_policies_new RENAME TO leave_policies`);

  console.log('✅ Leave Policies Schema Migration Completed');
});

db.close();
