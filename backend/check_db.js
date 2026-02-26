const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const dbFile = './time_tracker_dev.db';
const db = new sqlite3.Database(path.join(__dirname, dbFile));

db.serialize(() => {
  console.log('--- USERS ---');
  db.all('SELECT id, fullName, role, company FROM users LIMIT 20', [], (err, rows) => {
    if (err) console.error(err);
    console.table(rows);
    
    console.log('--- SETTINGS ---');
    db.all('SELECT id, companyName FROM settings', [], (err, rows) => {
      if (err) console.error(err);
      console.table(rows);
      db.close();
    });
  });
});
