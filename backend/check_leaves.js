const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('./time_tracker.db');

db.all('SELECT * FROM leave_policies', (err, rows) => {
  if (err) {
    console.error(err.message);
    process.exit(1);
  }
  console.log(JSON.stringify(rows, null, 2));
  db.close();
});
