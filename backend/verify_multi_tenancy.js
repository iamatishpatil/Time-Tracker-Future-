const axios = require('axios');
const fs = require('fs');
const FormData = require('form-data');
const path = require('path');

const BASE_URL = 'http://localhost:3000/api';

async function runTest() {
    try {
        const uniqueIdA = Date.now().toString().slice(-6) + '1';
        const uniqueIdB = Date.now().toString().slice(-6) + '2';
        console.log('--- STARTING MULTI-TENANCY & BRANDING TEST ---');

        // ==== 1. Setup Company A (Apple) ====
        console.log('\n[Company A] Registering Admin...');
        const adminAResponse = await axios.post(`${BASE_URL}/register`, {
            fullName: 'Admin Apple ' + uniqueIdA,
            mobileNumber: '99' + uniqueIdA,
            email: `adminA${uniqueIdA}@apple.com`,
            password: 'pwd',
            role: 'Admin',
            company: 'Apple'
        });
        if (adminAResponse.status !== 200 && adminAResponse.status !== 201) throw new Error('Failed to register A');

        console.log('[Company A] Logging in Admin...');
        const loginA = await axios.post(`${BASE_URL}/login`, {
            mobileNumber: '99' + uniqueIdA,
            password: 'pwd'
        });

        // Ensure "Apple" settings are scoped properly
        console.log('[Company A] Adding Shift...');
        await axios.post(`${BASE_URL}/admin/shifts`, {
            name: `Apple Morning Shift ${uniqueIdA}`,
            startTime: '09:00',
            endTime: '17:00',
            graceTime: 15,
            company: 'Apple'
        });

        console.log('[Company A] Setting Branding...');
        // Create a fake logo file
        fs.writeFileSync('temp_apple_logo.png', 'fake image data');
        const formA = new FormData();
        formA.append('logo', fs.createReadStream('temp_apple_logo.png'));
        formA.append('themeColor', '#FF0000');
        formA.append('company', 'Apple');
        formA.append('companyName', 'Apple');
        await axios.post(`${BASE_URL}/admin/branding`, formA, {
            headers: formA.getHeaders()
        });

        // ==== 2. Setup Company B (Banana) ====
        console.log('\n[Company B] Registering Admin...');
        const adminBResponse = await axios.post(`${BASE_URL}/register`, {
            fullName: 'Admin Banana ' + uniqueIdB,
            mobileNumber: '88' + uniqueIdB,
            email: `adminB${uniqueIdB}@banana.com`,
            password: 'pwd',
            role: 'Admin',
            company: 'Banana'
        });
        if (adminBResponse.status !== 200 && adminBResponse.status !== 201) throw new Error('Failed to register B');

        console.log('[Company B] Logging in Admin...');
        const loginB = await axios.post(`${BASE_URL}/login`, {
            mobileNumber: '88' + uniqueIdB,
            password: 'pwd'
        });

        console.log('[Company B] Adding Shift...');
        await axios.post(`${BASE_URL}/admin/shifts`, {
            name: 'Banana Night Shift',
            startTime: '18:00',
            endTime: '02:00',
            graceTime: 10,
            company: 'Banana'
        });


        // ==== 3. Data Isolation Verification ====
        console.log('\n--- VERIFYING DATA ISOLATION ---');
        
        // Fetch Settings A
        console.log('[Company A] Fetching Settings...');
        const settingsA = await axios.get(`${BASE_URL}/settings?company=Apple`);
        if (settingsA.data.themeColor !== '#FF0000') throw new Error('Company A themeColor mismatch');
        if (!settingsA.data.companyLogo) throw new Error('Company A logo missing');
        console.log('✅ Company A Branding Correct');

        // Fetch Settings B
        console.log('[Company B] Fetching Settings...');
        const settingsB = await axios.get(`${BASE_URL}/settings?company=Banana`);
        if (settingsB.data.themeColor && settingsB.data.themeColor === '#FF0000') throw new Error('Company B leaked Company A branding!');
        console.log('✅ Company B Branding Isolated');

        // Fetch Shifts A
        console.log('[Company A] Fetching Shifts...');
        const shiftsA = await axios.get(`${BASE_URL}/admin/shifts?company=Apple`);
        if (!shiftsA.data.some(s => s.name === `Apple Morning Shift ${uniqueIdA}`)) throw new Error('Company A missing shift');
        if (shiftsA.data.some(s => s.name === 'Banana Night Shift')) throw new Error('Company A sees Company B shift!');
        console.log('✅ Company A Shifts Isolated');

        // Fetch Shifts B
        console.log('[Company B] Fetching Shifts...');
        const shiftsB = await axios.get(`${BASE_URL}/admin/shifts?company=Banana`);
        if (!shiftsB.data.some(s => s.name === 'Banana Night Shift')) throw new Error('Company B missing shift');
        if (shiftsB.data.some(s => s.name === `Apple Morning Shift ${uniqueIdA}`)) throw new Error('Company B sees Company A shift!');
        console.log('✅ Company B Shifts Isolated');

        // Fetch Stats A
        console.log('[Company A] Fetching Stats...');
        const statsA = await axios.get(`${BASE_URL}/admin/stats?company=Apple`);
        console.log('✅ Company A Stats Fetched');

        // --- Leaves Isolation ---
        console.log('[Company A] Applying for Leave...');
        await axios.post(`${BASE_URL}/leaves/apply`, {
            userId: 1, // Example user from Tech Corp/Apple
            leaveType: 'Casual Leave',
            startDate: '2026-03-01',
            endDate: '2026-03-02',
            reason: 'Apple Test'
        });

        console.log('[Company B] Verifying Leaves Isolation...');
        const leavesB = await axios.get(`${BASE_URL}/admin/leaves?company=Banana`);
        if (leavesB.data.some(l => l.reason === 'Apple Test')) throw new Error('Company B leaked Company A leaves!');
        console.log('✅ Leaves Isolated');

        // --- Payslips Isolation ---
        console.log('[Company A] Creating Payslip...');
        await axios.post(`${BASE_URL}/admin/payslips`, {
            userId: 1,
            company: 'Apple',
            month: 'March',
            year: 2026,
            basicSalary: 50000,
            netSalary: 50000
        });

        console.log('[Company B] Verifying Payslips Isolation...');
        const payslipsB = await axios.get(`${BASE_URL}/admin/payslips?company=Banana`);
        if (payslipsB.data.some(p => p.month === 'March' && p.year === 2026)) throw new Error('Company B leaked Company A payslip!');
        console.log('✅ Payslips Isolated');

        // --- Reports Isolation ---
        console.log('[Company B] Verifying Reports Isolation...');
        const reportB = await axios.get(`${BASE_URL}/admin/reports/attendance?company=Banana`);
        if (reportB.data.length > 0) {
             // If there's data, check if any user belongs to Apple
             if (reportB.data.some(r => r.fullName && r.fullName.includes('Apple'))) throw new Error('Company B report leaked Company A users!');
        }
        console.log('✅ Reports Isolated');

        // Test Enforcement: Fetch Stats without company (Should Fail)
        console.log('\n[Security] Testing missing company parameter enforcement...');
        const endpointsToTest = [
            '/admin/stats',
            '/admin/users',
            '/admin/attendance',
            '/admin/holidays',
            '/admin/leaves',
            '/admin/payslips',
            '/admin/reports/overtime'
        ];

        for (const endpoint of endpointsToTest) {
            try {
                process.stdout.write(`   Testing ${endpoint}... `);
                await axios.get(`${BASE_URL}${endpoint}`);
                throw new Error(`Backend allowed access to ${endpoint} without company parameter!`);
            } catch (e) {
                if (e.response && e.response.status === 400) {
                    console.log('Rejected (Success)');
                } else {
                    console.log(`Failed with status ${e.response ? e.response.status : e.message}`);
                    throw e;
                }
            }
        }

        console.log('\n🎉 ALL TESTS PASSED! Multi-Tenancy boundaries are strictly enforced across all modules.');

    } catch (err) {
        console.error('\n❌ TEST FAILED:', err.message);
        if(err.response) {
             console.error('Response Data:', err.response.data);
        }
    } finally {
        if (fs.existsSync('temp_apple_logo.png')) fs.unlinkSync('temp_apple_logo.png');
    }
}

runTest();
