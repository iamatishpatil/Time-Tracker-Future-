const axios = require('axios');

const baseUrl = 'http://localhost:3000/api';
const testCompany = 'Alpha Beta ' + Date.now();

async function runTest() {
  console.log(`--- Testing Auto-Provisioning for: ${testCompany} ---`);
  
  try {
    // 1. Register a new Admin for the company
    console.log('1. Registering Admin...');
    const regRes = await axios.post(`${baseUrl}/register`, {
      fullName: 'Alpha Admin',
      email: `admin@${testCompany.replace(/ /g, '').toLowerCase()}.com`,
      mobileNumber: `9${Math.floor(Math.random() * 900000000)}`,
      password: 'password123',
      role: 'Admin',
      company: testCompany,
      isActive: 1
    });
    console.log('✅ Admin Registered');

    // 2. Verify Settings auto-provisioning
    console.log('2. Verifying Premium Settings auto-provisioning...');
    const settingsRes = await axios.get(`${baseUrl}/settings?company=${encodeURIComponent(testCompany)}`);
    if (settingsRes.data && settingsRes.data.workingDays) {
      const s = settingsRes.data;
      const isPremium = s.geofenceEnabled === 0 && s.themeColor === '#2196F3';
      if (isPremium) {
        console.log('✅ Premium Settings Auto-Provisioned (Geofence: OFF, Theme: Blue)');
      } else {
        console.error('❌ Settings NOT Premium:', { geofence: s.geofenceEnabled, theme: s.themeColor });
        process.exit(1);
      }
    } else {
      console.error('❌ Settings MISSING or Incorrect');
      process.exit(1);
    }

    // 3. Verify Shifts auto-provisioning
    console.log('3. Verifying Multi-Shift auto-provisioning...');
    const shiftsRes = await axios.get(`${baseUrl}/admin/shifts?company=${encodeURIComponent(testCompany)}`);
    if (shiftsRes.data && shiftsRes.data.length >= 3) {
      console.log('✅ Multi-Shifts Auto-Provisioned (Count:', shiftsRes.data.length, ')');
    } else {
      console.error('❌ Shifts MISSING or Incomplete (Count:', shiftsRes.data ? shiftsRes.data.length : 0, ')');
      process.exit(1);
    }

    // 4. Verify Leave Policies
    console.log('4. Verifying Leave Policies auto-provisioning...');
    const leaveRes = await axios.get(`${baseUrl}/admin/leave-policies?company=${encodeURIComponent(testCompany)}`);
    if (leaveRes.data && leaveRes.data.length >= 10) {
      console.log('✅ Leave Policies Auto-Provisioned (Count:', leaveRes.data.length, ')');
    } else {
      console.error('❌ Leave Policies MISSING or Incomplete (Count:', leaveRes.data ? leaveRes.data.length : 0, ')');
      process.exit(1);
    }

    console.log('\n🎉 ALL FEATURES VERIFIED & STANDARDIZED!');
  } catch (err) {
    console.error('❌ Test Failed:', err.response ? err.response.data : err.message);
    process.exit(1);
  }
}

runTest();
