const sqlite3 = require('sqlite3').verbose();
const bcrypt = require('bcryptjs');

const db = new sqlite3.Database('./time_tracker.db');

async function addUsers() {
  const users = [
    {
      fullName: 'Regular User',
      email: 'user@example.com',
      mobileNumber: '+917676594276',
      password: 'User@123',
      role: 'User',
      gender: 'Male',
      company: 'Tech Corp',
      department: 'Engineering',
      experience: '3 years',
      technologies: 'Flutter, Dart, Firebase',
      address: '123 Main Street, Bangalore, Karnataka'
    },
    {
      fullName: 'Admin User',
      email: 'admin@example.com',
      mobileNumber: '+919876543210',
      password: 'Admin@123',
      role: 'Admin',
      gender: 'Male',
      company: 'Tech Corp',
      department: 'Management',
      experience: '5 years',
      technologies: 'Node.js, Express, SQLite',
      address: '456 Park Avenue, Bangalore, Karnataka'
    }
  ];

  for (const user of users) {
    const hashedPassword = await bcrypt.hash(user.password, 10);
    
    db.run(
      `INSERT INTO users (fullName, email, mobileNumber, password, role, gender, company, department, experience, technologies, address, createdAt) 
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))`,
      [user.fullName, user.email, user.mobileNumber, hashedPassword, user.role, user.gender, user.company, user.department, user.experience, user.technologies, user.address],
      function(err) {
        if (err) {
          console.error(`Error adding ${user.role}:`, err.message);
        } else {
          console.log(`✅ ${user.role} added successfully! ID: ${this.lastID}`);
          console.log(`   Mobile: ${user.mobileNumber}`);
          console.log(`   Password: ${user.password}`);
        }
      }
    );
  }

  setTimeout(() => {
    db.close((err) => {
      if (err) {
        console.error(err.message);
      } else {
        console.log('\n✅ Database connection closed.');
        console.log('\n📱 You can now login with:');
        console.log('User: +917676594276 / User@123');
        console.log('Admin: +919876543210 / Admin@123');
      }
    });
  }, 1000);
}

addUsers();
