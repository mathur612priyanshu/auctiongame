const { DataTypes } = require("sequelize");
const { sequelize } = require("../config/database");

const UserLeaderboard = sequelize.define(
  "UserLeaderboard",
  {
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    userId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: "Users",
        key: "id",
      },
    },
    auctionId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: "Auctions",
        key: "id",
      },
    },
    playerGroup: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    totalPoints: {
      type: DataTypes.FLOAT,
      allowNull: false,
      defaultValue: 0,
    },
    playersCount: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    totalSpent: {
      type: DataTypes.FLOAT,
      defaultValue: 0,
    },
    rank: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    playerDetails: {
      type: DataTypes.JSON,
      allowNull: true,
      comment: "Array of player details with their individual points",
    },
    lastUpdated: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
    },
  },
  {
    tableName: "UserLeaderboard",
    indexes: [
      {
        unique: true,
        fields: ["userId", "auctionId", "playerGroup"],
      },
      {
        fields: ["playerGroup"],
      },
      {
        fields: ["totalPoints"],
      },
    ],
  }
);

module.exports = UserLeaderboard;
