const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const db = new sqlite3.Database(path.join(__dirname, 'time_tracker.db'));

const tables = ['users', 'attendance', 'leaves', 'holidays', 'settings', 'notifications', 'leave_types', 'leave_balances', 'shifts', 'holiday_responses'];

console.log('--- Multi-Tenancy Schema Audit ---');

let completed = 0;
tables.forEach(table => {
  db.all(`PRAGMA table_info(${table})`, (err, columns) => {
    if (err) {
      console.log(`[${table}] Table not found or error.`);
    } else {
      const hasCompany = columns.some(c => c.name === 'company');
      const hasCompanyId = columns.some(c => c.name === 'companyId');
      console.log(`[${table}]: ${hasCompany || hasCompanyId ? '✅ Isolated' : '❌ Lacks Company Column'}`);
      if (hasCompanyId) console.log(`   (Uses companyId instead of company)`);
    }
    completed++;
    if (completed === tables.length) {
      db.close();
    }
  });
});
