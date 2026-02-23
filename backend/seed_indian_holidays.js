const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const nodeEnv = process.env.NODE_ENV || 'development';
require('dotenv').config({ path: `.env.${nodeEnv}` });

const dbFile = process.env.DB_FILE || './time_tracker.db';
const db = new sqlite3.Database(dbFile);

const baseHolidays = [
  { name: "New Year Day", date: "01-01", type: "Optional", duration: "Full Day" },
  { name: "Lohri", date: "01-13", type: "Optional", duration: "Full Day" },
  { name: "Makar Sankranti", date: "01-14", type: "Optional", duration: "Full Day" },
  { name: "Republic Day", date: "01-26", type: "Public", duration: "Full Day" },
  { name: "Holi", date: "03-04", type: "Public", duration: "Full Day" },
  { name: "Independence Day", date: "08-15", type: "Public", duration: "Full Day" },
  { name: "Gandhi Jayanti", date: "10-02", type: "Public", duration: "Full Day" },
  { name: "Christmas", date: "12-25", type: "Public", duration: "Full Day" },
  { name: "New Year's Eve", date: "12-31", type: "Optional", duration: "Half Day" }
];

const holidays = [];
[2025, 2026].forEach(year => {
  baseHolidays.forEach(bh => {
    holidays.push({ ...bh, date: `${year}-${bh.date}` });
  });
});

db.serialize(() => {
  // Clear existing global holidays first to ensure a clean state
  db.run('DELETE FROM holidays WHERE company IS NULL');

  const stmt = db.prepare('INSERT OR REPLACE INTO holidays (name, date, type, duration, company) VALUES (?, ?, ?, ?, NULL)');
  
  db.run('BEGIN TRANSACTION');
  
  holidays.forEach(h => {
    stmt.run(h.name, h.date, h.type, h.duration, (err) => {
      if (err) console.error(`Error inserting ${h.name}:`, err.message);
    });
  });

  stmt.finalize();
  
  db.run('COMMIT', (err) => {
    if (err) {
      console.error('Transaction commit failed:', err.message);
    } else {
      console.log(`Successfully seeded ${holidays.length} comprehensive Indian holidays for 2026.`);
    }
  });
});

db.close();
