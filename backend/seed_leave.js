const sqlite3 = require('sqlite3').verbose();
const nodeEnv = process.env.NODE_ENV || 'development';
require('dotenv').config({ path: `.env.${nodeEnv}` });

const dbFile = process.env.DB_FILE || './time_tracker.db';
const db = new sqlite3.Database(dbFile);

db.run("INSERT OR REPLACE INTO leave_policies (leaveType, daysPerYear, isPaid) VALUES ('Emergency Leave', 5, 1)", (err) => {
  if (err) {
    console.error(err.message);
    process.exit(1);
  }
  console.log('Emergency Leave policy added successfully');
  db.close();
});
