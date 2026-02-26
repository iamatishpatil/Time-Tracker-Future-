const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const db = new sqlite3.Database(path.join(__dirname, './time_tracker_dev.db'));

db.serialize(() => {
  // 1. Approve all admins unconditionally
  db.run('UPDATE users SET isApproved = 1 WHERE role = ?', ['Admin'], function(err) {
    if (err) console.error('Error approving admins:', err.message);
    else console.log(`Approved ${this.changes} Admin users`);
  });

  // 2. Approve all existing real users with +91 phone numbers
  db.run('UPDATE users SET isApproved = 1 WHERE mobileNumber LIKE ?', ['+91%'], function(err) {
    if (err) console.error('Error approving +91 users:', err.message);
    else console.log(`Approved ${this.changes} +91 users`);
  });

  // 3. Show the FUTURE company users
  db.all('SELECT id, fullName, company, role, isApproved FROM users WHERE company = ?', ['FUTURE'], (err, rows) => {
    if (!err) {
      console.log('\nFUTURE company users:');
      console.log(JSON.stringify(rows, null, 2));
    }
    db.close(() => console.log('\nDone.'));
  });
});
