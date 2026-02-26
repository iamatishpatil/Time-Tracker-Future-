const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const db = new sqlite3.Database(path.join(__dirname, './time_tracker_dev.db'));

const columnsToAdd = [
  'ALTER TABLE attendance ADD COLUMN minutesLate INTEGER DEFAULT 0',
  'ALTER TABLE attendance ADD COLUMN minutesOvertime INTEGER DEFAULT 0',
  'ALTER TABLE attendance ADD COLUMN earlyLeaveMinutes INTEGER DEFAULT 0',
  'ALTER TABLE attendance ADD COLUMN shiftId INTEGER',
  'ALTER TABLE attendance ADD COLUMN penalty REAL DEFAULT 0',
];

db.serialize(() => {
  columnsToAdd.forEach(sql => {
    db.run(sql, (err) => {
      const col = sql.match(/ADD COLUMN (\w+)/)[1];
      if (err && err.message.includes('duplicate column')) {
        console.log(`[SKIP] ${col} already exists`);
      } else if (err) {
        console.error(`[ERR] ${col}:`, err.message);
      } else {
        console.log(`[OK] Added ${col}`);
      }
    });
  });

  db.all('PRAGMA table_info(attendance)', (err, rows) => {
    console.log('\nAttendance columns now:', rows.map(r => r.name).join(', '));
    db.close();
  });
});
