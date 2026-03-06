const { DataTypes } = require("sequelize");
const { sequelize } = require("../config/database");

const BidHistory = sequelize.define("BidHistory", {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  auctionId: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: "Auctions", key: "id" },
  },
  playerId: {
    type: DataTypes.INTEGER,
    allowNull: false,
    references: { model: "Players", key: "id" },
  },
  bidderId: {
    type: DataTypes.INTEGER,
    allowNull: false,
  },
  bidderName: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  amount: {
    type: DataTypes.FLOAT,
    allowNull: false,
  },
  previousBid: {
    type: DataTypes.FLOAT,
    defaultValue: 0,
  },
  timestamp: {
    type: DataTypes.DATE,
    defaultValue: DataTypes.NOW,
  },
});

BidHistory.sync({ alter: false })
  .then(() => {
    console.log("BidHistory table created");
  })
  .catch((error) => {
    console.error("Error creating BidHistory table:", error);
  });

module.exports = BidHistory;
