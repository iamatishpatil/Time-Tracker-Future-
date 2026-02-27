const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const db = new sqlite3.Database(path.join(__dirname, 'time_tracker.db'));

db.all("SELECT id, fullName, email, mobileNumber, role, isApproved, isActive FROM users ORDER BY id DESC LIMIT 5", (err, rows) => {
  if (err) {
    console.error(err);
  } else {
    console.log(JSON.stringify(rows, null, 2));
  }
  db.close();
});
