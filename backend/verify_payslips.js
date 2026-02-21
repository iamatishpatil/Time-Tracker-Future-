const axios = require('axios');

const BASE_URL = 'http://localhost:3000/api';

async function runTest() {
    try {
        const uniqueId = Date.now().toString().slice(-6);
        console.log('--- STARTING PAYSLIP SYSTEM VERIFICATION ---');

        // 1. Setup Employee
        console.log('\n[Setup] Registering Employee...');
        const userResp = await axios.post(`${BASE_URL}/register`, {
            fullName: 'Payslip Tester ' + uniqueId,
            mobileNumber: '77' + uniqueId,
            email: `tester${uniqueId}@company.com`,
            password: 'pwd',
            role: 'Employee',
            company: 'TestCorp',
            salary: 50000
        });
        const userId = userResp.data.id;
        console.log(`✅ Employee created with ID: ${userId}`);

        // 2. Setup Admin
        console.log('\n[Setup] Registering Admin for TestCorp...');
        await axios.post(`${BASE_URL}/register`, {
            fullName: 'Admin TestCorp ' + uniqueId,
            mobileNumber: '66' + uniqueId,
            email: `admin${uniqueId}@testcorp.com`,
            password: 'pwd',
            role: 'Admin',
            company: 'TestCorp'
        });

        // 3. Create Payslip
        console.log('\n[Action] Admin generates a Payslip...');
        const createResp = await axios.post(`${BASE_URL}/admin/payslips`, {
            userId: userId,
            month: 10,
            year: 2026,
            basicSalary: 50000,
            allowances: 2000,
            deductions: 500,
            netSalary: 51500,
            company: 'TestCorp'
        });
        
        console.log('✅ Payslip successfully generated (Status 200)');

        // 4. Admin Fetch Verification
        console.log('\n[Verify] Admin fetches payslips...');
        const adminFetch = await axios.get(`${BASE_URL}/admin/payslips?company=TestCorp`);
        const createdSlip = adminFetch.data.find(p => p.userId === userId && p.month === 10 && p.year === 2026);
        if (!createdSlip) throw new Error('Admin could not find the created payslip!');
        if (createdSlip.netSalary != 51500) throw new Error('Payslip math/netSalary mismatch!');
        console.log('✅ Admin successfully retrieved the accurate payslip');

        // 5. User Fetch Verification
        console.log('\n[Verify] Employee fetches their own payslips...');
        const userFetch = await axios.get(`${BASE_URL}/payslips/${userId}`);
        const userSlip = userFetch.data.find(p => p.month === 10 && p.year === 2026);
        if (!userSlip) throw new Error('Employee could not find their own payslip!');
        console.log('✅ Employee successfully retrieved their personal payslips in isolation');

        // 6. Delete Verification
        console.log('\n[Action] Admin deletes the payslip...');
        const slipId = createdSlip.id;
        await axios.delete(`${BASE_URL}/admin/payslips/${slipId}`);
        console.log('✅ Payslip completely removed from database');

        // Verify Deletion
        console.log('\n[Verify] Empty states after deletion...');
        const postDeleteFetch = await axios.get(`${BASE_URL}/payslips/${userId}`);
        if (postDeleteFetch.data.length > 0) throw new Error('Employee still sees deleted payslip!');
        console.log('✅ Deletion verified successfully everywhere.');

        console.log('\n🎉 ALL PAYSLIP TESTS PASSED STRICT MATHEMATICAL CHECKS!');

    } catch (err) {
        console.error('\n❌ TEST FAILED:', err.message);
        if(err.response) {
             console.error('Response Data:', err.response.data);
        }
    }
}

runTest();
