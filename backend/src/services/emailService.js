const nodemailer = require('nodemailer');

let transporter = null;

function getTransporter() {
  if (transporter) return transporter;

  const host = process.env.SMTP_HOST || 'smtp.gmail.com';
  const port = parseInt(process.env.SMTP_PORT || '587');
  const user = process.env.SMTP_USER || process.env.GMAIL_USER;
  const pass = process.env.SMTP_PASS || process.env.GMAIL_PASS;

  if (user && pass) {
    transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass }
    });
    console.log(`[EmailService] Transporter configured using ${user}`);
  }
  return transporter;
}

/**
 * Send an OTP code to a recipient's email address
 * @param {string} email - Recipient email
 * @param {string} otp - 4 to 6 digit OTP string
 */
async function sendOtpEmail(email, otp) {
  const mailer = getTransporter();

  if (!mailer) {
    console.log(`[EmailService] SMTP credentials not set. Simulated Email OTP to ${email}: ${otp}`);
    return { success: true, simulated: true };
  }

  const mailOptions = {
    from: `"Trackzo Security" <${process.env.SMTP_FROM || process.env.GMAIL_USER}>`,
    to: email,
    subject: `🔐 Your Trackzo Verification Code: ${otp}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 10px;">
        <h2 style="color: #7C4DFF; text-align: center;">Trackzo Verification</h2>
        <p style="font-size: 16px; color: #333;">Hello,</p>
        <p style="font-size: 15px; color: #555;">Use the verification code below to complete your registration or password reset on Trackzo:</p>
        <div style="background: #f4f0ff; padding: 15px; text-align: center; border-radius: 8px; font-size: 28px; font-weight: bold; letter-spacing: 5px; color: #7C4DFF; margin: 20px 0;">
          ${otp}
        </div>
        <p style="font-size: 13px; color: #888; text-align: center;">This code will expire in 10 minutes. If you did not request this code, please ignore this email.</p>
      </div>
    `
  };

  try {
    const info = await mailer.sendMail(mailOptions);
    console.log(`[EmailService] OTP email sent to ${email} (MessageId: ${info.messageId})`);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error(`[EmailService] Failed to send OTP email to ${email}:`, error.message);
    return { success: false, error: error.message };
  }
}

module.exports = {
  sendOtpEmail
};
