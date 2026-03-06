const { DataTypes } = require("sequelize");
const { sequelize } = require("../config/database");

const Otp = sequelize.define("Otp", {
  otp: {
    type: DataTypes.STRING,
  },
  phoneNumber: {
    type: DataTypes.STRING,
  },
  otpType: {
    type: DataTypes.STRING,
    // can be for different purposes
  },
  used: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  expiresat: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW, // or use a function for custom expiry
    expires: 1000,
  },
});

Otp.sync({ force: false })

  .then(() => {
    console.log("Otp table created");
  })
  .catch((error) => {
    console.error("Error creating User table:", error);
  });

module.exports = Otp;
