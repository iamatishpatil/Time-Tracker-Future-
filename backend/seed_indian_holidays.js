const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const db = new sqlite3.Database(path.join(__dirname, 'time_tracker.db'));

const holidays = [
  // January
  { name: "New Year Day", date: "2026-01-01", type: "Optional", duration: "Full Day" },
  { name: "Lohri", date: "2026-01-13", type: "Optional", duration: "Full Day" },
  { name: "Makar Sankranti", date: "2026-01-14", type: "Optional", duration: "Full Day" },
  { name: "Republic Day", date: "2026-01-26", type: "Public", duration: "Full Day" },

  // February
  { name: "Maha Shivaratri", date: "2026-02-15", type: "Public", duration: "Full Day" }, // Adj for 2026

  // March
  { name: "Holi", date: "2026-03-04", type: "Public", duration: "Full Day" }, // Adj for 2026
  { name: "Gudi Padwa", date: "2026-03-19", type: "Optional", duration: "Full Day" }, // Adj for 2026
  { name: "Id-ul-Fitr", date: "2026-03-20", type: "Public", duration: "Full Day" }, // Adj for 2026

  // April
  { name: "Ram Navami", date: "2026-03-27", type: "Public", duration: "Full Day" }, // Adj for 2026
  { name: "Mahavir Jayanti", date: "2026-03-31", type: "Public", duration: "Full Day" }, // Adj for 2026
  { name: "Hanuman Jayanti", date: "2026-04-02", type: "Optional", duration: "Full Day" }, // Adj for 2026
  { name: "Good Friday", date: "2026-04-03", type: "Public", duration: "Full Day" }, // Adj for 2026
  { name: "Ambedkar Jayanti", date: "2026-04-14", type: "Public", duration: "Full Day" },

  // May
  { name: "Buddha Purnima", date: "2026-05-01", type: "Public", duration: "Full Day" }, // Adj for 2026

  // June
  { name: "Id-ul-Zuha (Bakrid)", date: "2026-05-27", type: "Public", duration: "Full Day" }, // Adj for 2026

  // July
  { name: "Muharram", date: "2026-06-25", type: "Public", duration: "Full Day" }, // Adj for 2026

  // August
  { name: "Independence Day", date: "2026-08-15", type: "Public", duration: "Full Day" },
  { name: "Raksha Bandhan", date: "2026-08-28", type: "Optional", duration: "Half Day" }, // Adj
  { name: "Janmashtami", date: "2026-09-04", type: "Public", duration: "Full Day" }, // Adj

  // September
  { name: "Ganesh Chaturthi", date: "2026-09-14", type: "Public", duration: "Full Day" }, // Adj
  { name: "Onam", date: "2026-08-26", type: "Optional", duration: "Full Day" }, // Adj

  // October
  { name: "Gandhi Jayanti", date: "2026-10-02", type: "Public", duration: "Full Day" }, // Add back logic
  { name: "Dussehra", date: "2026-10-20", type: "Public", duration: "Full Day" }, // Adj
  { name: "Valmiki Jayanti", date: "2026-10-25", type: "Optional", duration: "Full Day" }, // Adj
  { name: "Karwa Chauth", date: "2026-10-29", type: "Optional", duration: "Half Day" }, // Adj

  // November
  { name: "Dhanteras", date: "2026-11-06", type: "Optional", duration: "Full Day" }, // Adj
  { name: "Choti Diwali", date: "2026-11-07", type: "Optional", duration: "Half Day" }, // Adj
  { name: "Diwali", date: "2026-11-08", type: "Public", duration: "Full Day" }, // Adj
  { name: "Govardhan Puja", date: "2026-11-09", type: "Optional", duration: "Full Day" }, // Adj
  { name: "Bhai Dooj", date: "2026-11-10", type: "Optional", duration: "Half Day" }, // Adj
  { name: "Chhath Puja", date: "2026-11-15", type: "Optional", duration: "Full Day" }, // Adj
  { name: "Guru Nanak Jayanti", date: "2026-11-24", type: "Public", duration: "Full Day" }, // Adj

  // December
  { name: "Christmas", date: "2026-12-25", type: "Public", duration: "Full Day" },
  { name: "New Year's Eve", date: "2026-12-31", type: "Optional", duration: "Half Day" }
];

db.serialize(() => {
  const stmt = db.prepare('INSERT OR REPLACE INTO holidays (name, date, type, duration) VALUES (?, ?, ?, ?)');
  
  db.run('BEGIN TRANSACTION');
  
  holidays.forEach(h => {
    stmt.run(h.name, h.date, h.type, h.duration, (err) => {
      if (err) console.error(`Error inserting ${h.name}:`, err.message);
    });
  });

  stmt.finalize();
  
  db.run('COMMIT', (err) => {
    if (err) {
      console.error('Transaction commit failed:', err.message);
    } else {
      console.log(`Successfully seeded ${holidays.length} comprehensive Indian holidays (including Half Days) for 2026.`);
    }
  });
});

db.close();
