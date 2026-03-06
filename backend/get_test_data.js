const { Pool } = require('pg');
require('dotenv').config({ path: 'c:/Users/admin/Desktop/Time Tracker/backend/.env.development' });

const pool = new Pool({
  user: process.env.PGUSER,
  host: process.env.PGHOST,
  database: process.env.PGDATABASE,
  password: process.env.PGPASSWORD,
  port: process.env.PGPORT,
});

async function run() {
  try {
    const res = await pool.query('SELECT id, "fullName", role, company, "mobileNumber" FROM users LIMIT 10');
    console.log(JSON.stringify(res.rows, null, 2));
    
    const settings = await pool.query('SELECT * FROM settings LIMIT 5');
    console.log('Settings:');
    console.log(JSON.stringify(settings.rows, null, 2));
  } catch (err) {
    console.error(err);
  } finally {
    await pool.end();
  }
}

run();
