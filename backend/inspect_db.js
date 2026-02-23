const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('./time_tracker_dev.db');

db.all('PRAGMA table_info(holidays)', (err, columns) => {
  console.log('Columns:', columns.map(c => c.name));
  
  db.all('SELECT * FROM holidays LIMIT 5', (err, rows) => {
    console.log('Sample Rows:', JSON.stringify(rows, null, 2));
    db.close();
  });
});
