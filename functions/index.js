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

// Send winner notification emails when a quarter score is entered
exports.sendWinnerNotifications = onCall(async (request) => {
  const { quarter, homeScore, awayScore } = request.data;

  if (quarter === undefined || homeScore === undefined || awayScore === undefined) {
    throw new HttpsError("invalid-argument", "quarter, homeScore, and awayScore are required");
  }

  try {
    // Get active board numbers
    const boardNumbersSnapshot = await db.collection("board_numbers")
      .where("isActive", "==", true)
      .limit(1)
      .get();

    if (boardNumbersSnapshot.empty) {
      console.log("No active board numbers found - skipping winner notifications");
      return { success: true, message: "No board numbers set yet", emailsSent: 0 };
    }

    const boardNumbers = boardNumbersSnapshot.docs[0].data();
    const homeNumbers = boardNumbers.homeNumbers;
    const awayNumbers = boardNumbers.awayNumbers;

    // Get game config for team names
    const configSnapshot = await db.collection("game_config")
      .where("isActive", "==", true)
      .limit(1)
      .get();

    let homeTeamName = "Home";
    let awayTeamName = "Away";
    if (!configSnapshot.empty) {
      const config = configSnapshot.docs[0].data();
      homeTeamName = config.homeTeamName || "Home";
      awayTeamName = config.awayTeamName || "Away";
    }

    // Calculate last digits
    const homeLastDigit = homeScore % 10;
    const awayLastDigit = awayScore % 10;

    // Find winning grid position
    const winningRow = homeNumbers.indexOf(homeLastDigit);
    const winningCol = awayNumbers.indexOf(awayLastDigit);

    if (winningRow === -1 || winningCol === -1) {
      console.log("Could not find winning position in board numbers");
      return { success: false, message: "Invalid board numbers configuration", emailsSent: 0 };
    }

    // Calculate all winning positions (winner, adjacent, diagonal)
    const winningPositions = [];

    // Main winner ($2400)
    winningPositions.push({ row: winningRow, col: winningCol, type: "winner", prize: 2400 });

    // Adjacent squares ($150 each) - with wrapping
    winningPositions.push({ row: (winningRow + 1) % 10, col: winningCol, type: "adjacent", prize: 150 });
    winningPositions.push({ row: (winningRow - 1 + 10) % 10, col: winningCol, type: "adjacent", prize: 150 });
    winningPositions.push({ row: winningRow, col: (winningCol + 1) % 10, type: "adjacent", prize: 150 });
    winningPositions.push({ row: winningRow, col: (winningCol - 1 + 10) % 10, type: "adjacent", prize: 150 });

    // Diagonal squares ($100 each) - with wrapping
    winningPositions.push({ row: (winningRow + 1) % 10, col: (winningCol + 1) % 10, type: "diagonal", prize: 100 });
    winningPositions.push({ row: (winningRow + 1) % 10, col: (winningCol - 1 + 10) % 10, type: "diagonal", prize: 100 });
    winningPositions.push({ row: (winningRow - 1 + 10) % 10, col: (winningCol + 1) % 10, type: "diagonal", prize: 100 });
    winningPositions.push({ row: (winningRow - 1 + 10) % 10, col: (winningCol - 1 + 10) % 10, type: "diagonal", prize: 100 });

    // Reverse + 5 bonus prize ($200) - only for Q2 (halftime) and Q4 (final)
    // Rule: 1) Swap home/away scores, 2) Add 5 to each, 3) Take last digits
    // Example: Score 10-3 → Reverse to 3-10 → Add 5 → 8-15 → Last digits: 8 and 5
    if (quarter === 2 || quarter === 4) {
      const bonusHomeDigit = (awayScore + 5) % 10;  // Reversed: away becomes home, then add 5
      const bonusAwayDigit = (homeScore + 5) % 10;  // Reversed: home becomes away, then add 5

      const bonusRow = homeNumbers.indexOf(bonusHomeDigit);
      const bonusCol = awayNumbers.indexOf(bonusAwayDigit);

      // Only add if valid position and different from the main winner
      if (bonusRow !== -1 && bonusCol !== -1 &&
          (bonusRow !== winningRow || bonusCol !== winningCol)) {
        winningPositions.push({ row: bonusRow, col: bonusCol, type: "reverse", prize: 200 });
      }
    }

    // Get all selections for this quarter
    const selectionsSnapshot = await db.collection("square_selections")
      .where("quarter", "==", quarter)
      .get();

    const selectionsByPosition = {};
    selectionsSnapshot.forEach((doc) => {
      const data = doc.data();
      const key = `${data.row}-${data.col}`;
      selectionsByPosition[key] = data;
    });

    // Find winners and collect their info
    const winnersToNotify = [];
    for (const pos of winningPositions) {
      const key = `${pos.row}-${pos.col}`;
      const selection = selectionsByPosition[key];
      if (selection) {
        winnersToNotify.push({
          ...pos,
          userId: selection.userId,
          userName: selection.userName,
          entryNumber: selection.entryNumber || 1,
        });
      }
    }

    if (winnersToNotify.length === 0) {
      console.log("No winners found for quarter", quarter);
      return { success: true, message: "No winners to notify", emailsSent: 0 };
    }

    // Get unique user IDs to fetch their emails
    const userIds = [...new Set(winnersToNotify.map((w) => w.userId))];
    const usersSnapshot = await db.collection("users")
      .where(admin.firestore.FieldPath.documentId(), "in", userIds)
      .get();

    const userEmails = {};
    usersSnapshot.forEach((doc) => {
      const userData = doc.data();
      if (userData.email) {
        userEmails[doc.id] = userData.email;
      }
    });

    // Group wins by user for consolidated emails
    const winsByUser = {};
    for (const winner of winnersToNotify) {
      if (!winsByUser[winner.userId]) {
        winsByUser[winner.userId] = {
          userName: winner.userName,
          email: userEmails[winner.userId],
          wins: [],
        };
      }
      winsByUser[winner.userId].wins.push(winner);
    }

    // Send emails to each winner
    let emailsSent = 0;
    const quarterNames = ["", "1st Quarter", "2nd Quarter", "3rd Quarter", "4th Quarter/Final"];

    for (const userId of Object.keys(winsByUser)) {
      const userWins = winsByUser[userId];
      if (!userWins.email) {
        console.log(`No email found for user ${userId}`);
        continue;
      }

      const totalPrize = userWins.wins.reduce((sum, w) => sum + w.prize, 0);
      const winDetails = userWins.wins.map((w) => {
        const typeLabel = w.type === "winner" ? "WINNING SQUARE" :
          w.type === "adjacent" ? "Adjacent Square" :
          w.type === "diagonal" ? "Diagonal Square" :
          w.type === "reverse" ? "REVERSE SCORE BONUS" : "Winner";
        return `<li>${typeLabel}: $${w.prize}</li>`;
      }).join("");

      const mailOptions = {
        from: `"Super Bowl Squares" <${process.env.GMAIL_EMAIL}>`,
        to: userWins.email,
        subject: `Congratulations! You won $${totalPrize} in ${quarterNames[quarter]}!`,
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background: linear-gradient(135deg, #1a472a 0%, #228B22 100%); padding: 20px; text-align: center;">
              <h1 style="color: #FFD700; margin: 0;">Super Bowl Squares</h1>
              <p style="color: #fff; margin: 10px 0 0 0;">Winner Notification</p>
            </div>
            <div style="padding: 30px; background: #f9f9f9;">
              <h2 style="color: #1a472a; text-align: center;">Congratulations, ${userWins.userName}!</h2>
              <div style="background: #FFD700; color: #1a472a; font-size: 28px; font-weight: bold; padding: 20px; text-align: center; border-radius: 10px; margin: 20px 0;">
                You won $${totalPrize}!
              </div>
              <div style="background: #fff; padding: 20px; border-radius: 10px; margin: 20px 0;">
                <h3 style="color: #1a472a; margin-top: 0;">${quarterNames[quarter]} Results</h3>
                <p style="font-size: 18px; margin: 10px 0;">
                  <strong>${homeTeamName}:</strong> ${homeScore} &nbsp;&nbsp;|&nbsp;&nbsp;
                  <strong>${awayTeamName}:</strong> ${awayScore}
                </p>
                <p style="font-size: 14px; color: #666;">
                  Winning numbers: ${homeLastDigit} - ${awayLastDigit}
                </p>
                <hr style="border: none; border-top: 1px solid #ddd; margin: 15px 0;">
                <p style="font-size: 16px; margin: 10px 0;"><strong>Your Winning Squares:</strong></p>
                <ul style="font-size: 14px; color: #333;">
                  ${winDetails}
                </ul>
              </div>
              <p style="font-size: 14px; color: #666; text-align: center;">
                Contact the game administrator to collect your winnings.
              </p>
            </div>
            <div style="background: #1a472a; padding: 15px; text-align: center;">
              <p style="color: #fff; margin: 0; font-size: 12px;">Super Bowl Squares - Congratulations on your win!</p>
            </div>
          </div>
        `,
      };

      try {
        await transporter.sendMail(mailOptions);
        emailsSent++;
        console.log(`Winner notification sent to ${userWins.email} for $${totalPrize}`);
      } catch (emailError) {
        console.error(`Failed to send email to ${userWins.email}:`, emailError);
      }
    }

    return {
      success: true,
      message: `Winner notifications sent for Q${quarter}`,
      emailsSent: emailsSent,
      totalWinners: Object.keys(winsByUser).length,
    };
  } catch (error) {
    console.error("Error sending winner notifications:", error);
    throw new HttpsError("internal", "Failed to send winner notifications");
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
