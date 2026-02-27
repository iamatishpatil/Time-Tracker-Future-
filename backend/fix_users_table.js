const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const db = new sqlite3.Database(path.join(__dirname, 'time_tracker.db'));

db.serialize(() => {
  db.run("ALTER TABLE users ADD COLUMN isApproved INTEGER DEFAULT 0", (err) => {
    if (err) {
       if (err.message.includes('duplicate column name')) {
         console.log('isApproved already exists');
       } else {
         console.error('Error adding isApproved:', err.message);
       }
    } else {
      console.log('Added isApproved column');
    }
  });

  db.run("ALTER TABLE users ADD COLUMN rejectionReason TEXT", (err) => {
    if (err) {
       if (err.message.includes('duplicate column name')) {
         console.log('rejectionReason already exists');
       } else {
         console.error('Error adding rejectionReason:', err.message);
       }
    } else {
      console.log('Added rejectionReason column');
    }
  });
});

db.close();
