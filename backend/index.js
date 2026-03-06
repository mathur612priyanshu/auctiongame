require("dotenv").config();
const cors = require("cors");

const express = require("express");
const http = require("http");
const initializeDatabase = require("./config/db-init");

const { Server } = require("socket.io");
const { createClient } = require("redis");
const { createAdapter } = require("@socket.io/redis-adapter");

const { connectToDatabase } = require("./config/database");
// const { startAuctionCron } = require("./crons/auctionlivestatus.js");
const createAuctionSocketController = require("./sockets/auction.socket.js");
const { connectRedis } = require("./config/redis.js");

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

(async () => {
  await connectRedis(); // Initialize Redis connection
})();
app.use("/api", require("./routes/auth.route"));
app.use("/api/users", require("./routes/user.route"));

app.use("/api/auction", require("./routes/auction.route"));
app.use("/api/player", require("./routes/player.route"));
app.use("/api/points", require("./routes/points.route"));
app.use("/api/leaderboard", require("./routes/leaderboard.routes"));

const auctionSocketController = createAuctionSocketController(io);
// (async () => {
//   const pubClient = createClient({ url: "redis://localhost:6379" });
//   const subClient = pubClient.duplicate();
//   await Promise.all([pubClient.connect(), subClient.connect()]);
//   io.adapter(createAdapter(pubClient, subClient));
// })();

io.on("connection", (socket) => {
  console.log("User connected:", socket.id);
  auctionSocketController.handleConnection(socket);

  socket.on("sendMessage", (data) => {
    console.log("Received message:", data);
    io.emit("receiveMessage", data); // broadcast to all
  });

  socket.on("disconnect", () => {
    console.log("User disconnected:", socket.id);
  });
});
let port = 8080;
server.listen(port, async () => {
  console.log(`Server listening on ${port}`);
  await connectToDatabase();

  // startAuctionCron();
});

class log {
  static success() {
    console.log("hii");
  }
  static heelo() {
    console.log("hii");
  }
  static success() {
    console.log("hii");
  }
}
