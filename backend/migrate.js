const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbFile = './time_tracker.db';
const db = new sqlite3.Database(dbFile);

db.serialize(() => {
  db.run("ALTER TABLE attendance ADD COLUMN minutesLate INTEGER DEFAULT 0", (err) => {
    if (err) {
      if (err.message.includes("duplicate column name")) {
        console.log("Column 'minutesLate' already exists.");
      } else {
        console.error("Migration failed:", err.message);
      }
    } else {
      console.log("Successfully added 'minutesLate' column to attendance table.");
    }
  });
});

db.close();
