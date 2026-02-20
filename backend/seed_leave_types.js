const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const nodeEnv = process.env.NODE_ENV || 'development';
require('dotenv').config({ path: `.env.${nodeEnv}` });

const dbFile = process.env.DB_FILE || path.join(__dirname, 'time_tracker.db');
const db = new sqlite3.Database(dbFile);

const standardLeaves = [
  { leaveType: 'Sick Leave', daysPerYear: 12, isPaid: 1 },
  { leaveType: 'Casual Leave', daysPerYear: 10, isPaid: 1 },
  { leaveType: 'Earned Leave (Privilege)', daysPerYear: 18, isPaid: 1 },
  { leaveType: 'Maternity Leave', daysPerYear: 182, isPaid: 1 }, // Standard ~26 weeks
  { leaveType: 'Paternity Leave', daysPerYear: 15, isPaid: 1 },
  { leaveType: 'Bereavement Leave', daysPerYear: 5, isPaid: 1 },
  { leaveType: 'Compensatory Off (Comp-off)', daysPerYear: 0, isPaid: 1 }, // Accrued dynamically usually
  { leaveType: 'Marriage Leave', daysPerYear: 5, isPaid: 1 },
  { leaveType: 'Leave Without Pay (LWP)', daysPerYear: 365, isPaid: 0 },
  { leaveType: 'Sabbatical Leave', daysPerYear: 365, isPaid: 0 }
];

db.serialize(() => {
  db.run(`CREATE TABLE IF NOT EXISTS leave_policies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    leaveType TEXT NOT NULL UNIQUE,
    daysPerYear INTEGER DEFAULT 10,
    isPaid INTEGER DEFAULT 1
  )`);

  const stmt = db.prepare('INSERT OR REPLACE INTO leave_policies (leaveType, daysPerYear, isPaid) VALUES (?, ?, ?)');
  
  db.run('BEGIN TRANSACTION');
  
  standardLeaves.forEach(l => {
    stmt.run(l.leaveType, l.daysPerYear, l.isPaid, (err) => {
      if (err) console.error(`Error inserting ${l.leaveType}:`, err.message);
    });
  });

  stmt.finalize();
  
  db.run('COMMIT', (err) => {
    if (err) {
      console.error('Transaction commit failed:', err.message);
    } else {
      console.log(`Successfully seeded ${standardLeaves.length} comprehensive leave types.`);
    }
  });

});

db.close();

