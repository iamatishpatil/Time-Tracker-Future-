const sqlite3 = require('sqlite3').verbose();
const nodeEnv = process.env.NODE_ENV || 'development';
require('dotenv').config({ path: `.env.${nodeEnv}` });

const dbFile = process.env.DB_FILE || './time_tracker.db';
const db = new sqlite3.Database(dbFile);

db.all('SELECT * FROM leave_policies', (err, rows) => {
  if (err) {
    console.error(err.message);
    process.exit(1);
  }
  console.log(JSON.stringify(rows, null, 2));
  db.close();
});
