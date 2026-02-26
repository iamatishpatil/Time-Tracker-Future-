const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const dbFile = './time_tracker_dev.db';
const db = new sqlite3.Database(path.join(__dirname, dbFile));

db.serialize(() => {
  console.log('--- MIGRATING USERS ---');
  // Assign jomol and yashi to Apple (Example - they seem to be orphaned)
  // Or better, 'Global' for now so they don't break, but ideally we'd know their company.
  db.run('UPDATE users SET company = "Tech Corp" WHERE company IS NULL', [], function(err) {
    if (err) console.error(err);
    console.log(`Updated ${this.changes} users to Tech Corp`);
    
    // Fix settings with empty companyName
    db.run('DELETE FROM settings WHERE companyName = "" OR companyName IS NULL', [], function(err) {
      if (err) console.error(err);
      console.log(`Cleaned up ${this.changes} invalid settings rows`);
      db.close();
    });
  });
});
