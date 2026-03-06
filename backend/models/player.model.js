const { DataTypes } = require("sequelize");
const { sequelize } = require("../config/database");

const Player = sequelize.define("Player", {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  basePrice: {
    type: DataTypes.FLOAT,
    allowNull: false,
  },

  team: {
    type: DataTypes.STRING, // e.g., "India", "Australia", "Brazil"
  },
  category: {
    type: DataTypes.STRING, // e.g., "cricket", "football", "basketball"
    allowNull: false,
  },
  type: {
    type: DataTypes.STRING, // e.g., "batsman", "bowler", "midfielder", "striker"
    allowNull: false,
  },
  // Flexible metadata field for sport-specific statistics
  statistics: {
    type: DataTypes.JSON,
    allowNull: true,
    defaultValue: {},
    comment: "Sport-specific statistics like runs, wickets, goals, etc.",
  },
  // Additional metadata for any extra information
  metadata: {
    type: DataTypes.JSON,
    allowNull: true,
    defaultValue: {},
    comment: "Additional player information like age, nationality, etc.",
  },
  matches: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    require: false,
    comment: "Number of matches played by the player",
  },
  imageurl: {
    type: DataTypes.TEXT,
    allowNull: true,
    comment: "URL or path to the player's image",
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
  },
  playerGroup: {
    type: DataTypes.STRING,
    allowNull: true,
    comment: "Group name for bulk operations (e.g., 'IPL_2024_BATCH_1')",
  },
});

// Define association in a static method
Player.associate = function(models) {
  Player.belongsTo(models.PlayerGroup, {
    foreignKey: 'playerGroup',
    targetKey: 'groupName',
    as: 'groupInfo',
    constraints: false // Add this if you don't want to enforce foreign key constraints
  });
};

Player.sync({ alter: false })
  .then(() => {
    console.log("Player table created");
  })
  .catch((error) => {
    console.log("Error creating Player table:", error);
  });

module.exports = Player;
