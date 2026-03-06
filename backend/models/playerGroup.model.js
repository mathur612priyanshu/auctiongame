const { DataTypes } = require("sequelize");
const { sequelize } = require("../config/database");

const PlayerGroup = sequelize.define("PlayerGroup", {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  groupName: {
    type: DataTypes.STRING,
    allowNull: false,
    unique: true,
    comment: "Unique name for the player group",
  },
  category: {
    type: DataTypes.STRING,
    allowNull: false,
    comment: "Sport category (e.g., cricket, football, basketball)",
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: true,
    comment: "Optional description for the group",
  },
  isActive: {
    type: DataTypes.BOOLEAN,
    defaultValue: true,
    allowNull: false,
    comment: "Whether the group is active and should be displayed",
  },
  playerCount: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    comment: "Cached count of players in this group",
  },
  auctionCount: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    comment: "Cached count of auctions for this group",
  },
  metadata: {
    type: DataTypes.JSON,
    allowNull: true,
    defaultValue: {},
    comment: "Additional metadata for the group",
  },
  createdBy: {
    type: DataTypes.STRING,
    allowNull: true,
    comment: "User who created this group",
  },
  disabledAt: {
    type: DataTypes.DATE,
    allowNull: true,
    comment: "Timestamp when the group was disabled",
  },
  disabledBy: {
    type: DataTypes.STRING,
    allowNull: true,
    comment: "User who disabled this group",
  },
});

// Define association in a static method
PlayerGroup.associate = function(models) {
  PlayerGroup.hasMany(models.Player, {
    foreignKey: 'playerGroup',
    sourceKey: 'groupName',
    as: 'players',
    constraints: false
  });
};

PlayerGroup.sync({ alter: false })
  .then(() => {
    console.log("PlayerGroup table created/updated");
  })
  .catch((error) => {
    console.log("Error creating PlayerGroup table:", error);
  });

module.exports = PlayerGroup;
