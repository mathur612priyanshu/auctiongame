const { DataTypes } = require("sequelize");
const { sequelize } = require("../config/database");

const AuctionResult = sequelize.define("AuctionResult", {
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

  winnerId: {
    type: DataTypes.INTEGER,
    allowNull: true, // null if no bids were placed
    references: {
      model: 'Users',  // This should match the table name in your database
      key: 'id',
    },
    onDelete: 'SET NULL',
  },
  winnerName: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  finalBid: {
    type: DataTypes.FLOAT,
    allowNull: false,
    defaultValue: 0,
  },
  basePrice: {
    type: DataTypes.FLOAT,
    allowNull: false,
  },
  totalBids: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
  },
  auctionStartTime: {
    type: DataTypes.DATE,
    allowNull: false,
  },
  auctionEndTime: {
    type: DataTypes.DATE,
    allowNull: false,
  },
  status: {
    type: DataTypes.ENUM("sold", "unsold"),
    allowNull: false,
  },
});

// Remove the individual sync - let the main database.js handle it
// AuctionResult.sync({ alter: false })
//   .then(() => {
//     console.log("AuctionResult table created");
//   })
//   .catch((error) => {
//     console.error("Error creating AuctionResult table:", error);
//   });

module.exports = AuctionResult;
