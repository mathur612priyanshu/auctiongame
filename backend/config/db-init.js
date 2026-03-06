const sequelize = require("./database");
require("../models/user.model"); // ✅ this registers User model

// Import other models as needed

const initializeDatabase = async () => {
  try {
    // Create tables in the correct order
    await sequelize.sync({ alter: false });
  } catch (error) {
    console.error("Database initialization error:", error);
  }
};

module.exports = initializeDatabase;
