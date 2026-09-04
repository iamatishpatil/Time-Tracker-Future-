const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const { authenticateToken } = require('../middleware/auth');
const upload = require('../middleware/upload');

router.use(authenticateToken);

// User Management
router.patch('/users/:id/active', adminController.updateUserActive);
router.patch('/users/:id/approve', adminController.updateUserApproval);
router.get('/stats', adminController.getStats);
router.get('/users', adminController.getUsers);
router.delete('/users/:id', adminController.deleteUser);
router.post('/users', upload.single('profilePicture'), adminController.createUser);

// Attendance Management
router.get('/attendance', adminController.getAttendance);
router.post('/attendance', adminController.createAttendance);
router.put('/attendance/:id', adminController.updateAttendance);
router.get('/absent', adminController.getAbsentUsers);

// Shift Management
router.get('/shifts', adminController.getShifts);
router.post('/shifts', adminController.createShift);
router.put('/shifts/:id', adminController.updateShift);
router.delete('/shifts/:id', adminController.deleteShift);

// Holidays Management
router.get('/holidays', adminController.getHolidays);
router.post('/holidays', adminController.createHoliday);
router.delete('/holidays/:id', adminController.deleteHoliday);

// Leave Policies & Balances
router.get('/leave-policies', adminController.getLeavePolicies);
router.post('/leave-policies', adminController.createLeavePolicy);
router.put('/leave-balance', adminController.updateLeaveBalance);
router.get('/leave-balance/:userId', adminController.getUserLeaveBalance);
router.get('/leaves', adminController.getAdminLeaves);
router.put('/leaves/:id', adminController.updateLeaveStatus);

// Reports
router.get('/reports/overtime', adminController.getOvertimeReport);
router.get('/reports/salary-hours', adminController.getSalaryHoursReport);
router.get('/reports/payroll', adminController.getPayrollReport);
router.get('/reports/attendance', adminController.getAttendanceReport);

// Payslips & Reminders
router.post('/payslips', adminController.createPayslip);
router.get('/payslips', adminController.getCompanyPayslips);
router.delete('/payslips/:id', adminController.deletePayslip);
router.post('/notifications/reminders', adminController.sendCheckoutReminders);

module.exports = router;
