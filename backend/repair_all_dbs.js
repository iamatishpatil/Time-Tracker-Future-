const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');

const dbFiles = ['./time_tracker.db', './time_tracker_dev.db'];

const columnsToAdd = [
  { name: 'company', type: 'TEXT' },
  { name: 'geofenceEnabled', type: 'INTEGER DEFAULT 1' },
  { name: 'payrollEnabled', type: 'INTEGER DEFAULT 1' },
  { name: 'companyLogo', type: 'TEXT' },
  { name: 'themeColor', type: 'TEXT' },
  { name: 'cameraAuthEnabled', type: 'INTEGER DEFAULT 1' }
];

function repairDb(dbFile) {
  return new Promise((resolve) => {
    const fullPath = path.join(__dirname, dbFile);
    if (!fs.existsSync(fullPath)) {
      console.log(`[SKIP] ${dbFile} not found.`);
      return resolve();
    }

    console.log(`\n--- Repairing ${dbFile} ---`);
    const db = new sqlite3.Database(fullPath);

    db.serialize(() => {
      // Get current columns first
      db.all('PRAGMA table_info(settings)', (err, columns) => {
        if (err) {
          console.error(`Error getting table info for ${dbFile}:`, err);
          return resolve();
        }

        const existingNames = columns.map(c => c.name);
        
        // Use separate serialize block for additions to be safe
        db.serialize(() => {
          columnsToAdd.forEach(col => {
            if (!existingNames.includes(col.name)) {
              console.log(`Adding missing column: ${col.name}`);
              db.run(`ALTER TABLE settings ADD COLUMN ${col.name} ${col.type}`, (err) => {
                if (err) console.error(`Error adding ${col.name}:`, err.message);
                else console.log(`✓ Added ${col.name}`);
              });
            }
          });

          // Data Standardization
          db.run("UPDATE settings SET company = companyName WHERE (company IS NULL OR company = '') AND companyName IS NOT NULL AND companyName != ''");
          db.run('UPDATE settings SET geofenceEnabled = 1 WHERE geofenceEnabled IS NULL');
          db.run('UPDATE settings SET payrollEnabled = 1 WHERE payrollEnabled IS NULL');
          db.run('UPDATE settings SET cameraAuthEnabled = 1 WHERE cameraAuthEnabled IS NULL');
          db.run('DELETE FROM settings WHERE (companyName IS NULL OR companyName = "") AND (company IS NULL OR company = "")');
          
          // CRITICAL: Standarize FUTURE / FUTURE COMPANY / Future
          // We'll set both to 'FUTURE' (all caps) to match the users table
          db.run("UPDATE settings SET company = 'FUTURE', companyName = 'FUTURE' WHERE (company = 'Future' OR companyName = 'Future' OR companyName = 'FUTURE COMPANY' OR company = 'FUTURE COMPANY')");
          
          // Final check in a separate step
          db.all('SELECT id, company, companyName, cameraAuthEnabled FROM settings', (err, rows) => {
            if (err) {
              console.error(`Error verifying ${dbFile}:`, err.message);
            } else {
              console.log(`Final Settings State for ${dbFile}:`);
              console.log(JSON.stringify(rows, null, 2));
            }
            db.close();
            resolve();
          });
        });
      });
    });
  });
}

async function run() {
  for (const f of dbFiles) {
    await repairDb(f);
  }
  console.log('\nAll repairs finished.');
}

run();
