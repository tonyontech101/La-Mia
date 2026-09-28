import { Resend } from "resend";

/**
 * Returns a styled HTML email for delivering a 6-digit OTP code.
 */
export function getOtpEmailHtml(code: string, purpose: string): string {
  let title = "Verify Your Email";
  let description =
    "Thank you for joining La Mia! Use the 6-digit code below to complete your registration and activate your account.";

  if (purpose === "change_password") {
    title = "Password Change Request";
    description =
      "We received a request to change the password for your La Mia account. Enter this verification code to proceed.";
  } else if (purpose === "change_email") {
    title = "Verify Your New Email";
    description =
      "We received a request to update your email address on La Mia. Enter this code to verify your new email.";
  }

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
  <style>
    body {
      margin: 0;
      padding: 0;
      background-color: #FAF7F2;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      color: #2D241E;
    }
    .container {
      max-width: 520px;
      margin: 40px auto;
      background: #FFFFFF;
      border-radius: 16px;
      overflow: hidden;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.06);
      border: 1px solid #F0ECE4;
    }
    .header {
      background: #D97706;
      padding: 32px 24px;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      color: #FFFFFF;
      font-size: 26px;
      font-weight: 800;
      letter-spacing: -0.5px;
    }
    .header p {
      margin: 6px 0 0 0;
      color: rgba(255, 255, 255, 0.9);
      font-size: 13px;
      text-transform: uppercase;
      letter-spacing: 1.5px;
    }
    .content {
      padding: 36px 32px;
      text-align: center;
    }
    .content h2 {
      margin: 0 0 12px 0;
      font-size: 20px;
      font-weight: 700;
      color: #1E1B18;
    }
    .content p {
      margin: 0 0 24px 0;
      font-size: 15px;
      line-height: 1.6;
      color: #6B5E55;
    }
    .code-box {
      display: inline-block;
      margin: 12px auto 24px auto;
      padding: 16px 28px;
      background-color: #FEF3C7;
      border: 2px dashed #F59E0B;
      border-radius: 12px;
      font-family: 'SFMono-Regular', Consolas, 'Liberation Mono', Menlo, monospace;
      font-size: 36px;
      font-weight: 700;
      letter-spacing: 10px;
      color: #92400E;
    }
    .footer {
      padding: 20px 32px;
      background-color: #FBF9F6;
      border-top: 1px solid #F0ECE4;
      font-size: 13px;
      color: #8C7F75;
      text-align: center;
      line-height: 1.5;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>La Mia</h1>
      <p>Discover & Cook Delicious Recipes</p>
    </div>
    <div class="content">
      <h2>${title}</h2>
      <p>${description}</p>
      <div class="code-box">${code}</div>
      <p style="font-size: 14px; color: #8C7F75; margin-bottom: 0;">
        ⏱️ This code expires in <strong>10 minutes</strong>.<br>
        If you didn't request this email, you can safely ignore it.
      </p>
    </div>
    <div class="footer">
      This is an automated security notification from La Mia.<br>
      Please do not reply directly to this email.
    </div>
  </div>
</body>
</html>
  `.trim();
}

/**
 * Dispatches a verification email using Resend API.
 */
export async function sendVerificationEmail(
  to: string,
  code: string,
  purpose: string
): Promise<void> {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey || apiKey === "re_placeholder_key") {
    // In local development or testing without key, log the code clearly
    console.warn(
      `[EmailService] RESEND_API_KEY is not configured. Emulating email delivery:\n` +
      `To: ${to}\nPurpose: ${purpose}\nCode: ${code}`
    );
    return;
  }

  const resend = new Resend(apiKey);
  const html = getOtpEmailHtml(code, purpose);

  let subject = "Your La Mia Verification Code";
  if (purpose === "change_password") {
    subject = "La Mia — Password Change Verification Code";
  } else if (purpose === "change_email") {
    subject = "La Mia — Verify Your New Email Address";
  }

  // onboarding@resend.dev is the default verified sender for testing on Resend
  const fromEmail = process.env.RESEND_FROM_EMAIL || "La Mia <onboarding@resend.dev>";

  const response = await resend.emails.send({
    from: fromEmail,
    to: [to],
    subject,
    html,
  });

  if (response.error) {
    console.error("[EmailService] Resend API error:", response.error);
    throw new Error(`Failed to send verification email: ${response.error.message}`);
  }

  console.log(`[EmailService] Verification email sent to ${to}. Email ID: ${response.data?.id}`);
}
