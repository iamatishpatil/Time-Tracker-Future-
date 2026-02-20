const sqlite3 = require('sqlite3').verbose();
const nodeEnv = process.env.NODE_ENV || 'development';
require('dotenv').config({ path: `.env.${nodeEnv}` });

const dbFile = process.env.DB_FILE || 'time_tracker.db';
const db = new sqlite3.Database(dbFile);
db.each('SELECT mobileNumber, role, password FROM users', (err, row) => console.log(`${row.mobileNumber} | ${row.role}`));
setTimeout(() => { db.close(); }, 2000);
