const { DataTypes } = require("sequelize");
const { sequelize } = require("../config/database");

const AuctionPlayers = sequelize.define(
  "AuctionPlayers",
  {
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    auctionId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: "Auctions",
        key: "id",
      },
    },
    playerId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: "Players",
        key: "id",
      },
    },
  },
  {
    tableName: "AuctionPlayers",
    indexes: [
      {
        unique: true,
        fields: ["auctionId", "playerId"],
      },
    ],
  }
);

module.exports = AuctionPlayers;
