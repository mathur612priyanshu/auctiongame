const { DataTypes } = require("sequelize");
const { sequelize } = require("../config/database");

const PlayerPoints = sequelize.define(
  "PlayerPoints",
  {
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    playerId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: "Players",
        key: "id",
      },
    },
    playerGroup: {
      type: DataTypes.STRING,
      allowNull: false,
      comment: "Group name to identify which tournament/season",
    },
    category: {
      type: DataTypes.STRING,
      allowNull: false,
      comment: "Sport category: cricket, football, basketball, etc.",
    },
    // Raw stats from Excel
    stats: {
      type: DataTypes.JSON,
      allowNull: false,
      defaultValue: {},
      comment:
        "Raw stats: {runs: 50, wickets: 2} or {goals: 3, assists: 1, saves: 5}",
    },
    // Calculated points
    totalPoints: {
      type: DataTypes.FLOAT,
      allowNull: false,
      defaultValue: 0,
      comment: "Total calculated points based on scoring rules",
    },
    pointsBreakdown: {
      type: DataTypes.JSON,
      allowNull: true,
      defaultValue: {},
      comment: "Points breakdown: {runs: 50, wickets: 4, total: 54}",
    },
    lastUpdated: {
      type: DataTypes.DATE,
      defaultValue: DataTypes.NOW,
    },
  },
  {
    tableName: "PlayerPoints",
    indexes: [
      {
        unique: true,
        fields: ["playerId", "playerGroup"],
      },
      {
        fields: ["playerGroup"],
      },
      {
        fields: ["category"],
      },
    ],
  }
);

module.exports = PlayerPoints;
