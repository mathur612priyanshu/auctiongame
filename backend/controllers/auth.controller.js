require("dotenv").config();
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");
const { Op } = require("sequelize");

const User = require("../models/user.model");
const sendSMS = require("../helpers/sms");
const Otp = require("../models/otp.model");
const { generateRandom6DigitNumber } = require("../helpers/commonfn");
const { uploadToS3 } = require("../helpers/aws");

const send_verification_code = async (req, res) => {
  const { phoneNumber } = req.body;
  console.log(phoneNumber);
  // if (phoneNumber == "1234567899" || phoneNumber == "+911234567899") {
  //   return res
  //     .status(200)
  //     .json({ message: "Verification code sent successfully" });
  // }
  if (!phoneNumber) {
    return res.status(400).json({ error: "Missing phone number" });
  }
  try {
    const verificationCode = generateRandom6DigitNumber();
    if (phoneNumber) {
      await sendSMS(`+${phoneNumber}`, verificationCode);
    }

    const otps = await Otp.create({
      otp: verificationCode,
      phoneNumber: phoneNumber,
      otpType: "login",
    });

    console.log(verificationCode);
    res.status(200).json({ message: "Verification code sent successfully" });
  } catch (err) {
    console.log("some error occured", err);
    res.status(400).json({ error: "Verification code not sent" });
  }
};

const userdetail = async (req, res) => {
  try {
    // Support static admin user which doesn't exist in DB
    if (req.user && req.user.id === "admin") {
      return res.status(200).json({
        success: true,
        user: {
          id: "admin",
          name: "Admin",
          email: "admin@example.com",
          role: "admin",
          profilecompleted: true,
        },
      });
    }

    const user = await User.findByPk(req.user.id, {
      attributes: { exclude: ["password", "updatedAt", "createdAt"] },
    });
    if (!user) {
      return res
        .status(404)
        .json({ success: false, message: "User not found" });
    }

    const profilecompleted = !!user.profilepic;
    const userdata = {
      ...user.toJSON(),
      profilecompleted,
    };

    res.status(200).json({
      success: true,
      user: userdata,
    });
  } catch (error) {
    console.log("here", error);
    res.status(500).json({ success: false, error: "Internal Server Error" });
  }
};
const verify_otp = async (req, res) => {
  const { otp, phoneNumber } = req.body;

  if (!otp || !phoneNumber) {
    return res.status(400).json({ error: "Missing OTP or phone number" });
  }

  try {
    // Find the OTP and check if it's unused
    const check = await Otp.findOne({
      where: { otp, used: false },
    });

    if (!check) {
      return res.status(400).json({ error: "Invalid or expired OTP" });
    }

    // Find or create the user
    let user = await User.findOne({
      where: { phone: phoneNumber },
    });

    if (!user) {
      user = await User.create({ phone: phoneNumber });
    }

    // Mark OTP as used
    await check.update({ used: true });
    if (!user.isActive) {
      return res
        .status(400)
        .json({ error: "Your account has been made inactive" });
    }
    // Generate JWT token
    const token = jwt.sign({ id: user.id, phoneNumber }, "secretKey", {
      expiresIn: "5d",
    });

    return res.status(200).json({
      message: "Login successful",
      token,
      user,
      phoneNumber,
      role: "user",
    });
  } catch (error) {
    console.error("Error during OTP verification:", error);
    return res.status(500).json({ error: "Internal server error" });
  }
};

const updateUserProfile = async (req, res) => {
  const userId = req.user.id;
  const file = req.file;
  var profilepic;
  if (req.file) {
    profilepic = await uploadToS3(
      req.file.buffer,
      req.file.originalname,
      "profile_pic",
      req.file.mimetype
    );
  }
  const { name, email, dob } = req.body;

  try {
    const user = await User.findByPk(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }
    var profilepic;
    if (req.file) {
      profilepic = await uploadToS3(
        req.file.buffer,
        req.file.originalname,
        "profile-image",
        req.file.mimetype
      );
    }
    console.log("profilepic==>", profilepic);
    const updates = {
      name,
      email,
      dob,
      profilepic,
    };

    await user.update(updates);

    const updatedUser = await User.findByPk(userId, {
      attributes: { exclude: ["password", "updatedAt", "createdAt"] },
    });

    const profilecompleted = !!(updatedUser.name && updatedUser.email);

    return res.status(200).json({
      message: "Profile updated successfully",
      user: {
        ...updatedUser.toJSON(),
        profilecompleted,
      },
    });
  } catch (error) {
    console.error("Error updating profile:", error);
    return res.status(500).json({ message: "Internal server error" });
  }
};

// Static admin login for admin-panel access
const static_login = async (req, res) => {
  try {
    const { email, username, password } = req.body;
    const userIdInput = (username || email || "").trim();
    const passInput = (password || "").trim();

    // Static credentials
    const STATIC_USERNAME = process.env.ADMIN_USERNAME || "admin";
    const STATIC_PASSWORD = process.env.ADMIN_PASSWORD || "asdfghjkl";

    if (!userIdInput || !passInput) {
      return res
        .status(400)
        .json({
          success: false,
          message: "Username and password are required",
        });
    }

    if (userIdInput !== STATIC_USERNAME || passInput !== STATIC_PASSWORD) {
      return res
        .status(401)
        .json({ success: false, message: "Invalid credentials" });
    }

    const payload = { id: "admin", role: "admin" };
    const secret = process.env.JWT_SECRET || "secretKey"; // fallback aligns with other usages
    const token = jwt.sign(payload, secret, { expiresIn: "5d" });

    return res.status(200).json({
      success: true,
      message: "Login successful",
      token,
      user: {
        id: "admin",
        name: "Admin",
        email: "admin@example.com",
        role: "admin",
      },
    });
  } catch (error) {
    console.error("Static login error:", error);
    return res
      .status(500)
      .json({ success: false, message: "Internal server error" });
  }
};

module.exports = {
  send_verification_code,
  verify_otp,
  userdetail,
  updateUserProfile,
  static_login,
};
