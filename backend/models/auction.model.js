const { DataTypes } = require("sequelize");
const { sequelize } = require("../config/database");

const Auction = sequelize.define("Auction", {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  category: {
    type: DataTypes.STRING,
    allowNull: false,
  },
  type: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  minPlayers: {
    type: DataTypes.INTEGER,
    allowNull: false,
  },
  // maxPlayers: {
  //   type: DataTypes.INTEGER,
  //   allowNull: false,
  // },
  status: {
    type: DataTypes.ENUM("upcoming", "ongoing", "completed"),
    defaultValue: "upcoming",
  },
  startTime: {
    type: DataTypes.DATE,
  },
  currentPlayerIndex: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
  },
  currentBid: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
  },
  highestBidder: {
    type: DataTypes.STRING,
    allowNull: true,
  },
  highestBidderId: {
    type: DataTypes.INTEGER,
  },
  createdBy: {
    type: DataTypes.INTEGER,
    allowNull: true,
    references: {
      model: "Users",
      key: "id",
    },
  },
  timeRemaining: {
    type: DataTypes.INTEGER,
    defaultValue: 30,
  },
  winnerId: DataTypes.INTEGER,
  finalBid: DataTypes.INTEGER,
  runPoint: {
    type: DataTypes.INTEGER,
    defaultValue: 1,
    allowNull: false,
  },
  wicketPoint: {
    type: DataTypes.INTEGER,
    defaultValue: 10,
    allowNull: false,
  },
  maxPlayerAllowed: {
    type: DataTypes.INTEGER,
    allowNull: true,
  },
  countedPlayers: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
  },
  entryAmount: {
    type: DataTypes.INTEGER,
    allowNull: true,
  },
  captainPoints: {
    type: DataTypes.INTEGER,
    allowNull: true,
  },
  viceCaptainPoints: {
    type: DataTypes.INTEGER,
    allowNull: true,
  },
  // endTime: {
  //   type: DataTypes.DATE,
  // },
});

Auction.sync({ alter: false })

  .then(() => {
    console.log("Auction table created");
  })
  .catch((error) => {
    console.error("Error creating Auction table:", error);
  });

module.exports = Auction;
