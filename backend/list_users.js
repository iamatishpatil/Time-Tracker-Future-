const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('time_tracker.db');
db.each('SELECT mobileNumber, role, password FROM users', (err, row) => console.log(`${row.mobileNumber} | ${row.role}`));
setTimeout(() => { db.close(); }, 2000);
