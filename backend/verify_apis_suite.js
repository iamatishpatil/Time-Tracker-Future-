const axios = require('axios');

const BASE_URL = 'http://localhost:3000/api';
const ADMIN_MOBILE = '+919876543210';
const USER_MOBILE = '+917676594276';
const PASSWORD = 'password123';

async function testApis() {
  console.log('--- Starting API Verification ---');
  
  let adminToken, userToken, userId, adminId;
  let company = 'Tech Corp';

  // 1. Login Admin
  try {
    console.log(`Testing Login (Admin: ${ADMIN_MOBILE})...`);
    const loginRes = await axios.post(`${BASE_URL}/login`, {
      mobileNumber: ADMIN_MOBILE,
      password: PASSWORD
    });
    adminToken = loginRes.data.token;
    adminId = loginRes.data.user.id;
    console.log('✅ Admin Login Successful');
  } catch (err) {
    console.log(`❌ Admin Login Failed: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
    // Try to reset password if failed
    console.log('Attempting to reset password for Admin using OTP 9999...');
    try {
        await axios.post(`${BASE_URL}/reset-password`, {
            mobileNumber: ADMIN_MOBILE,
            otp: '9999',
            newPassword: PASSWORD
        });
        const retryLogin = await axios.post(`${BASE_URL}/login`, {
            mobileNumber: ADMIN_MOBILE,
            password: PASSWORD
        });
        adminToken = retryLogin.data.token;
        adminId = retryLogin.data.user.id;
        console.log('✅ Admin Login Successful after reset');
    } catch (resetErr) {
        console.log(`❌ Admin Password Reset Failed: ${resetErr.response ? JSON.stringify(resetErr.response.data) : resetErr.message}`);
    }
  }

  // 2. Login User
  try {
    console.log(`Testing Login (User: ${USER_MOBILE})...`);
    const loginRes = await axios.post(`${BASE_URL}/login`, {
      mobileNumber: USER_MOBILE,
      password: PASSWORD
    });
    userToken = loginRes.data.token;
    userId = loginRes.data.user.id;
    console.log('✅ User Login Successful');
  } catch (err) {
     console.log(`❌ User Login Failed: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
     // Try to reset password if failed
     console.log('Attempting to reset password for User using OTP 9999...');
     try {
         await axios.post(`${BASE_URL}/reset-password`, {
             mobileNumber: USER_MOBILE,
             otp: '9999',
             newPassword: PASSWORD
         });
         const retryLogin = await axios.post(`${BASE_URL}/login`, {
             mobileNumber: USER_MOBILE,
             password: PASSWORD
         });
         userToken = retryLogin.data.token;
         userId = retryLogin.data.user.id;
         console.log('✅ User Login Successful after reset');
     } catch (resetErr) {
         console.log(`❌ User Password Reset Failed: ${resetErr.response ? JSON.stringify(resetErr.response.data) : resetErr.message}`);
     }
  }

  if (!adminToken || !userToken) {
    console.log('CRITICAL: Could not obtain tokens. Aborting further tests.');
    return;
  }

  const userHeaders = { Authorization: `Bearer ${userToken}` };
  const adminHeaders = { Authorization: `Bearer ${adminToken}` };

  // 3. User - Get Profile
  try {
    console.log(`Testing Get User Profile (ID: ${userId})...`);
    const res = await axios.get(`${BASE_URL}/user/${userId}`, { headers: userHeaders });
    console.log('✅ Get Profile Successful');
  } catch (err) {
    console.log(`❌ Get Profile Failed: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
  }

  // 4. User - Attendance Status
  try {
    console.log('Testing Get Attendance Status...');
    const res = await axios.get(`${BASE_URL}/attendance/status/${userId}`, { headers: userHeaders });
    console.log(`✅ Get Attendance Status Successful: ${JSON.stringify(res.data)}`);
  } catch (err) {
    console.log(`❌ Get Attendance Status Failed: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
  }

  // 5. User - Check-in (Mock Lat/Long)
  try {
    console.log('Testing Check-in...');
    // We'll use id 2 and fake coordinates
    const res = await axios.post(`${BASE_URL}/checkin`, {
        userId: userId,
        lat: 12.8916959,
        long: 77.6419436,
        address: 'Test Office'
    }, { headers: userHeaders });
    console.log(`✅ Check-in Successful: ${JSON.stringify(res.data)}`);
  } catch (err) {
    console.log(`❌ Check-in Failed: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
  }

  // 6. User - Dashboard Stats
  try {
    console.log('Testing Get Dashboard Stats...');
    const res = await axios.get(`${BASE_URL}/attendance/stats/${userId}`, { headers: userHeaders });
    console.log(`✅ Get Dashboard Stats Successful: ${JSON.stringify(res.data)}`);
  } catch (err) {
    console.log(`❌ Get Dashboard Stats Failed: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
  }

  // 7. Admin - Stats
  try {
    console.log('Testing Admin Get Stats...');
    const res = await axios.get(`${BASE_URL}/admin/stats`, { headers: adminHeaders });
    console.log(`✅ Get Admin Stats Successful: ${JSON.stringify(res.data)}`);
  } catch (err) {
    console.log(`❌ Get Admin Stats Failed: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
  }

  // 8. Admin - All Employees
  try {
    console.log('Testing Admin Get All Employees...');
    const res = await axios.get(`${BASE_URL}/admin/users`, { headers: adminHeaders });
    console.log(`✅ Get All Employees Successful (Count: ${res.data.length})`);
  } catch (err) {
    console.log(`❌ Get All Employees Failed: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
  }

  // 9. Admin - All Leave Requests
  try {
    console.log('Testing Admin Get All Leave Requests...');
    const res = await axios.get(`${BASE_URL}/admin/leaves`, { headers: adminHeaders });
    console.log(`✅ Get All Leave Requests Successful (Count: ${res.data.length})`);
  } catch (err) {
    console.log(`❌ Get All Leave Requests Failed: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
  }

  // 10. User - Attendance History
  try {
    console.log('Testing Get My Attendance History...');
    const res = await axios.get(`${BASE_URL}/attendance/${userId}`, { headers: userHeaders });
    console.log(`✅ Get Attendance History Successful (Count: ${res.data.length})`);
  } catch (err) {
    console.log(`❌ Get Attendance History Failed: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
  }

  // 11. User - Leave Balance
  try {
    console.log('Testing Get Leave Balance...');
    const res = await axios.get(`${BASE_URL}/leaves/balance/${userId}`, { headers: userHeaders });
    console.log(`✅ Get Leave Balance Successful: ${JSON.stringify(res.data.remaining)} remaining`);
  } catch (err) {
    console.log(`❌ Get Leave Balance Failed: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
  }

  // 12. User - Leave Types
  try {
    console.log('Testing Get Leave Types...');
    const res = await axios.get(`${BASE_URL}/leaves/types?company=${company}`, { headers: userHeaders });
    console.log(`✅ Get Leave Types Successful: ${res.data.length} types found`);
  } catch (err) {
    console.log(`❌ Get Leave Types Failed: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
  }

  // 13. User - Notifications
  try {
    console.log('Testing Get My Notifications...');
    const res = await axios.get(`${BASE_URL}/notifications/${userId}`, { headers: userHeaders });
    console.log(`✅ Get Notifications Successful (Count: ${res.data.length})`);
  } catch (err) {
    console.log(`❌ Get Notifications Failed: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
  }

  // 14. Shared - Company Settings
  try {
    console.log('Testing Get Company Settings...');
    const res = await axios.get(`${BASE_URL}/settings?company=${company}`, { headers: userHeaders });
    console.log(`✅ Get Settings Successful: ${res.data.companyName}`);
  } catch (err) {
    console.log(`❌ Get Settings Failed: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
  }

  // 15. Shared - Holidays
  try {
    console.log('Testing Get Holidays...');
    const res = await axios.get(`${BASE_URL}/admin/holidays?company=${company}`, { headers: userHeaders });
    console.log(`✅ Get Holidays Successful (Count: ${res.data.length})`);
  } catch (err) {
    console.log(`❌ Get Holidays Failed: ${err.response ? JSON.stringify(err.response.data) : err.message}`);
  }

  console.log('--- API Verification Completed ---');
}

testApis();
