const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbFile = './time_tracker.db';
const db = new sqlite3.Database(path.join(__dirname, dbFile));

db.serialize(() => {
  console.log('Checking settings table schema...');
  
  const columnsToAdd = [
    { name: 'company', type: 'TEXT UNIQUE' },
    { name: 'geofenceEnabled', type: 'INTEGER DEFAULT 1' },
    { name: 'payrollEnabled', type: 'INTEGER DEFAULT 1' },
    { name: 'companyLogo', type: 'TEXT' },
    { name: 'themeColor', type: 'TEXT' },
    { name: 'cameraAuthEnabled', type: 'INTEGER DEFAULT 1' }
  ];

  db.all('PRAGMA table_info(settings)', (err, columns) => {
    if (err) {
      console.error('Error getting table info:', err);
      return;
    }

    const existingNames = columns.map(c => c.name);
    console.log('Existing columns:', existingNames);

    columnsToAdd.forEach(col => {
      if (!existingNames.includes(col.name)) {
        console.log(`Adding missing column: ${col.name}`);
        // We can't add UNIQUE in ALTER TABLE directly in some SQLite versions if there are existing rows
        // But let's try a standard ADD COLUMN first.
        // If UNIQUE fails, we'll handle it.
        const addSql = `ALTER TABLE settings ADD COLUMN ${col.name} ${col.type}`;
        db.run(addSql, (err) => {
          if (err) {
            console.error(`Error adding ${col.name}:`, err.message);
            // Fallback for UNIQUE if needed: just add it without UNIQUE first
            if (col.type.includes('UNIQUE')) {
               console.log(`Attempting fallback for ${col.name} without UNIQUE...`);
               db.run(`ALTER TABLE settings ADD COLUMN ${col.name} TEXT`, (err2) => {
                 if (err2) console.error(`Fallback failed for ${col.name}:`, err2.message);
               });
            }
          } else {
            console.log(`Successfully added ${col.name}`);
          }
        });
      }
    });

    // Also backfill 'company' column from 'companyName' for existing rows if needed
    db.run("UPDATE settings SET company = companyName WHERE (company IS NULL OR company = '') AND companyName IS NOT NULL AND companyName != ''", (err) => {
        if (!err) console.log('Backfilled company column from companyName');
    });

  });
});

setTimeout(() => {
  db.close(() => console.log('Database repair completed.'));
}, 2000);
