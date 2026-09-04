const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const { authenticateToken } = require('../middleware/auth');

router.use(authenticateToken);

router.post('/apply', adminController.applyLeave);
router.get('/types', adminController.getLeaveTypes);
router.get('/balance/:userId', adminController.getLeaveBalance);
router.get('/:userId', adminController.getUserLeaves);
router.put('/:id/cancel', adminController.cancelLeave);

module.exports = router;
