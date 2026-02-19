const http = require('http');

const makeRequest = (path, method = 'GET', body = null) => {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: path,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve(data);
        }
      });
    });

    req.on('error', (e) => reject(e));

    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
};

const verify = async () => {
  try {
    console.log('--- Verifying Phase 4 Features ---');

    // 1. Check Admin Stats (Late Count)
    console.log('\nChecking Admin Stats...');
    const stats = await makeRequest('/api/admin/stats');
    console.log('Stats:', stats);
    if (stats.lateToday !== undefined) {
      console.log('✅ Late Today count present');
    } else {
      console.error('❌ Late Today count MISSING');
    }

    // 2. Check Notifications
    console.log('\nChecking Notifications (User 1)...');
    const notifications = await makeRequest('/api/notifications/1');
    console.log('Notifications:', notifications);
    if (Array.isArray(notifications)) {
      console.log('✅ Notifications endpoint works');
    } else {
      console.error('❌ Notifications endpoint failed');
    }

    // 3. Check Reports
    console.log('\nChecking Reports...');
    const report = await makeRequest('/api/admin/reports/attendance?startDate=2023-01-01&endDate=2026-12-31');
    if (Array.isArray(report)) {
      console.log(`✅ Report endpoint returned ${report.length} records`);
    } else {
      console.log('Report Response:', report);
      console.error('❌ Report endpoint failed');
    }

    // 4. Leave Cancellation (Mock test)
    // We need a pending leave first.
    console.log('\nTesting Leave Cancellation...');
    const leave = await makeRequest('/api/leaves/apply', 'POST', {
      userId: 1,
      startDate: '2026-05-01',
      endDate: '2026-05-02',
      reason: 'Test Leave for Cancellation'
    });
    console.log('Applied Leave:', leave);
    
    if (leave.id) {
        const cancel = await makeRequest(`/api/leaves/${leave.id}/cancel`, 'PUT', { userId: 1 });
        console.log('Cancel Response:', cancel);
        if (cancel.message === 'Leave cancelled') {
            console.log('✅ Leave cancellation successful');
        } else {
            console.error('❌ Leave cancellation failed');
        }
    }

  } catch (e) {
    console.error('Verification Error:', e);
  }
};

verify();
