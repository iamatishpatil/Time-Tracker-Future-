const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('./time_tracker_dev.db');

const company = 'Test';
const query = 'SELECT * FROM holidays WHERE (company = ? OR company IS NULL)';
const params = [company];

db.all(query, params, (err, rows) => {
  if (err) console.error(err);
  console.log(`Query: ${query}`);
  console.log(`Params: ${JSON.stringify(params)}`);
  console.log(`Results Count: ${rows.length}`);
  if (rows.length > 0) console.log('First result company:', rows[0].company);
  db.close();
});
