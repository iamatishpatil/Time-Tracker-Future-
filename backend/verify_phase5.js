const http = require('http');

const makeRequest = (path, method = 'GET', body = null) => {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: path,
      method: method,
      headers: { 'Content-Type': 'application/json' },
    };
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(data) }); }
        catch (e) { resolve({ status: res.statusCode, body: data }); }
      });
    });
    req.on('error', (e) => reject(e));
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
};

const verify = async () => {
  console.log('--- Verifying Phase 5: Advanced Attendance Management ---\n');

  // 1. GET admin/attendance (no filter)
  console.log('1. GET /api/admin/attendance (no filter)...');
  const all = await makeRequest('/api/admin/attendance');
  if (all.status === 200 && Array.isArray(all.body)) {
    console.log(`   ✅ Returns ${all.body.length} records`);
  } else {
    console.error('   ❌ Failed:', all.body);
  }

  // 2. GET admin/attendance with userId filter
  console.log('\n2. GET /api/admin/attendance?userId=1...');
  const filtered = await makeRequest('/api/admin/attendance?userId=1');
  if (filtered.status === 200 && Array.isArray(filtered.body)) {
    console.log(`   ✅ Returns ${filtered.body.length} records for userId=1`);
  } else {
    console.error('   ❌ Failed:', filtered.body);
  }

  // 3. POST /api/admin/attendance (manual entry)
  console.log('\n3. POST /api/admin/attendance (manual entry)...');
  const now = new Date();
  const checkIn = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 9, 0, 0).toISOString();
  const checkOut = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 17, 0, 0).toISOString();
  const manual = await makeRequest('/api/admin/attendance', 'POST', {
    userId: 1,
    checkInTime: checkIn,
    checkOutTime: checkOut,
    status: 'Present',
    adminId: 1,
  });
  if (manual.status === 200 && manual.body.id) {
    console.log(`   ✅ Manual entry created with id=${manual.body.id}`);

    // 4. PUT /api/admin/attendance/:id (edit)
    console.log('\n4. PUT /api/admin/attendance/:id (edit)...');
    const edit = await makeRequest(`/api/admin/attendance/${manual.body.id}`, 'PUT', {
      checkInTime: checkIn,
      checkOutTime: checkOut,
      status: 'Late',
      overtimeHours: 0,
      adminId: 1,
    });
    if (edit.status === 200 && edit.body.message === 'Attendance updated') {
      console.log('   ✅ Attendance record edited successfully');
    } else {
      console.error('   ❌ Edit failed:', edit.body);
    }
  } else {
    console.error('   ❌ Manual entry failed:', manual.body);
  }

  // 5. GET admin/attendance with date filter
  console.log('\n5. GET /api/admin/attendance with date range...');
  const today = now.toISOString().split('T')[0];
  const dateFiltered = await makeRequest(`/api/admin/attendance?startDate=${today}&endDate=${today}`);
  if (dateFiltered.status === 200 && Array.isArray(dateFiltered.body)) {
    console.log(`   ✅ Date filter returns ${dateFiltered.body.length} records for today`);
  } else {
    console.error('   ❌ Date filter failed:', dateFiltered.body);
  }

  console.log('\n--- Verification Complete ---');
};

verify().catch(console.error);
