const { DataTypes, INTEGER, STRING } = require("sequelize");
const { sequelize } = require("../config/database");
const User = sequelize.define("User", {
  phone: { type: DataTypes.BIGINT },
  name: { type: DataTypes.STRING },
  email: { type: DataTypes.STRING },
  points: { type: DataTypes.INTEGER, defaultValue: 0 },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  dob: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  profilepic: {
    type: DataTypes.TEXT,
    allowNull: true,
  },
});

User.sync({ alter: false })

  .then(() => {
    console.log("User table created");
  })
  .catch((error) => {
    console.error("Error creating User table:", error);
  });

module.exports = User;
