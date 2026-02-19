const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('./time_tracker.db');

db.run("INSERT OR REPLACE INTO leave_policies (leaveType, daysPerYear, isPaid) VALUES ('Emergency Leave', 5, 1)", (err) => {
  if (err) {
    console.error(err.message);
    process.exit(1);
  }
  console.log('Emergency Leave policy added successfully');
  db.close();
});
