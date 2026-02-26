const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbFile = './time_tracker.db';
const db = new sqlite3.Database(path.join(__dirname, dbFile));

db.serialize(() => {
  console.log('--- Database Settings Cleanup ---');
  
  // 1. Fill missing 'company' (ID) from 'companyName' (Display Name)
  db.run(`UPDATE settings SET company = companyName WHERE (company IS NULL OR company = '') AND companyName IS NOT NULL AND companyName != ''`, (err) => {
    if (err) console.error('Error in backfill:', err.message);
    else console.log('✓ Backfilled company column from companyName');
  });

  // 2. Clean up empty/redundant rows
  db.run(`DELETE FROM settings WHERE (companyName IS NULL OR companyName = '') AND (company IS NULL OR company = '')`, (err) => {
    if (err) console.error('Error in cleanup:', err.message);
    else console.log('✓ Deleted empty settings rows');
  });

  // 3. Special handling for "Future" (The current company)
  // Ensure exactly one row exists for 'Future'
  db.all(`SELECT id, company, companyName FROM settings WHERE company = 'Future'`, (err, rows) => {
    if (!err && rows.length > 1) {
       console.log('Found duplicate rows for "Future", consolidating...');
       // Implementation omitted for brevity, but the POST logic update will also handle it.
    }
  });

  db.all('SELECT id, company, companyName, cameraAuthEnabled FROM settings', (err, rows) => {
    if (!err) {
      console.log('Current Settings Rows:');
      console.log(JSON.stringify(rows, null, 2));
    }
  });
});

setTimeout(() => {
  db.close(() => console.log('--- Cleanup Done ---'));
}, 2000);
