const axios = require("axios");
const TWOFACTOR_API_KEY = process.env.TWOFACTOR_API_KEY; // Add this to .env

const send2FactorOTP = async (phoneNumber, verificationCode) => {
  try {
    console.log(phoneNumber);
    const response = await axios.get(
      `https://2factor.in/API/V1/${TWOFACTOR_API_KEY}/SMS/${phoneNumber}/${verificationCode}/OTP1`
    );
    console.log("2Factor response:", response.data);
  } catch (error) {
    console.error(
      "Error sending SMS via 2Factor:",
      error.response?.data || error.message
    );
    throw error;
  }
};

const sendSMS = async (
  phoneNumber,
  verificationCode,
  type = "login",
  message
) => {
  await send2FactorOTP(phoneNumber, verificationCode); // 2Factor doesn't accept '+'
};

module.exports = sendSMS;
