const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('./time_tracker_dev.db');

db.all('PRAGMA index_list(leave_policies)', (err, indices) => {
  if (err) {
    console.error(err);
    db.close();
    return;
  }
  console.log('--- Indices for leave_policies ---');
  console.log(JSON.stringify(indices, null, 2));

  let completed = 0;
  indices.forEach(idx => {
    db.all(`PRAGMA index_info(${idx.name})`, (err, info) => {
      console.log(`\n--- Info for ${idx.name} ---`);
      console.log(JSON.stringify(info, null, 2));
      completed++;
      if (completed === indices.length) {
        db.close();
      }
    });
  });
  if (indices.length === 0) db.close();
});
