require("dotenv").config(); // 👈 Load environment variables from .env

module.exports = {
  development: {
    username: "root",
    password: "admin",
    database: "auctiondb",
    host: "localhost",
    dialect: "mysql",
  },
  test: {
    username: process.env.DBUSER,
    password: process.env.DBPASS,
    database: process.env.DBNAME,
    host: process.env.DB_HOST,
    dialect: "mysql",
  },
  production: {
    username: process.env.DBUSER,
    password: process.env.DBPASS,
    database: process.env.DBNAME,
    host: process.env.DB_HOST,
    dialect: "mysql",
  },
};
3;
