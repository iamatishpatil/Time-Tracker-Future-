const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbFile = './time_tracker_dev.db';
const db = new sqlite3.Database(dbFile);

db.all("SELECT * FROM holidays", [], (err, rows) => {
  if (err) {
    console.error("Error reading holidays:", err.message);
  } else {
    console.log("Holidays in DB:");
    console.log(JSON.stringify(rows, null, 2));
  }
  db.close();
});
