const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('time_tracker_dev.db');

db.all('SELECT * FROM settings WHERE company = "FUTURE" OR companyName = "FUTURE"', (err, rows) => {
  if (err) {
    console.error(err);
  } else {
    console.log(JSON.stringify(rows, null, 2));
  }
  db.close();
});
