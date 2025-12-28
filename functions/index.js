const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

const db = admin.firestore();

// Configure Gmail SMTP transporter
// Set these in functions/.env file:
// GMAIL_EMAIL=your-email@gmail.com
// GMAIL_PASSWORD=your-app-password
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.GMAIL_EMAIL,
    pass: process.env.GMAIL_PASSWORD,
  },
});

// Generate a 6-digit verification code
function generateCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Send verification code to user's email
exports.sendVerificationCode = onCall(async (request) => {
  const { email, userId } = request.data;

  if (!email || !userId) {
    throw new HttpsError("invalid-argument", "Email and userId are required");
  }

  const code = generateCode();
  const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes from now

  try {
    // Store the verification code in Firestore
    await db.collection("verification_codes").doc(userId).set({
      code: code,
      email: email.toLowerCase(),
      expiresAt: expiresAt,
      attempts: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send email
    const mailOptions = {
      from: `"Super Bowl Squares" <${process.env.GMAIL_EMAIL}>`,
      to: email,
      subject: "Your Super Bowl Squares Verification Code",
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <div style="background: linear-gradient(135deg, #1a472a 0%, #228B22 100%); padding: 20px; text-align: center;">
            <h1 style="color: #FFD700; margin: 0;">Super Bowl Squares</h1>
          </div>
          <div style="padding: 30px; background: #f9f9f9;">
            <h2 style="color: #1a472a;">Your Verification Code</h2>
            <p style="font-size: 16px; color: #333;">Enter this code to access your account:</p>
            <div style="background: #1a472a; color: #FFD700; font-size: 32px; font-weight: bold; letter-spacing: 8px; padding: 20px; text-align: center; border-radius: 10px; margin: 20px 0;">
              ${code}
            </div>
            <p style="font-size: 14px; color: #666;">This code expires in 10 minutes.</p>
            <p style="font-size: 14px; color: #666;">If you didn't request this code, please ignore this email.</p>
          </div>
          <div style="background: #1a472a; padding: 15px; text-align: center;">
            <p style="color: #fff; margin: 0; font-size: 12px;">Super Bowl Squares - Good luck!</p>
          </div>
        </div>
      `,
    };

    await transporter.sendMail(mailOptions);

    return { success: true, message: "Verification code sent" };
  } catch (error) {
    console.error("Error sending verification code:", error);
    throw new HttpsError("internal", "Failed to send verification code");
  }
});

// Verify the code entered by user
exports.verifyCode = onCall(async (request) => {
  const { userId, code } = request.data;

  if (!userId || !code) {
    throw new HttpsError("invalid-argument", "userId and code are required");
  }

  try {
    const docRef = db.collection("verification_codes").doc(userId);
    const doc = await docRef.get();

    if (!doc.exists) {
      throw new HttpsError(
        "not-found",
        "No verification code found. Please request a new code."
      );
    }

    const docData = doc.data();

    // Check if too many attempts
    if (docData.attempts >= 5) {
      await docRef.delete();
      throw new HttpsError(
        "permission-denied",
        "Too many attempts. Please request a new code."
      );
    }

    // Check if expired
    if (Date.now() > docData.expiresAt) {
      await docRef.delete();
      throw new HttpsError(
        "deadline-exceeded",
        "Code has expired. Please request a new code."
      );
    }

    // Check if code matches
    if (docData.code !== code) {
      // Increment attempts
      await docRef.update({
        attempts: admin.firestore.FieldValue.increment(1),
      });
      throw new HttpsError("invalid-argument", "Invalid code. Please try again.");
    }

    // Code is valid - delete it and mark user as verified
    await docRef.delete();

    // Update user's email verification status
    await db.collection("users").doc(userId).update({
      emailVerified: true,
      emailVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: true, message: "Email verified successfully" };
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    console.error("Error verifying code:", error);
    throw new HttpsError("internal", "Failed to verify code");
  }
});
