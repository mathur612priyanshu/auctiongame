const { createClient } = require("redis");

let redisClient = null;

const connectRedis = async () => {
  if (!redisClient) {
    redisClient = createClient({ url: "redis://localhost:6379" });

    redisClient.on("error", (err) => {
      console.error("Redis Client Error:", err);
    });

    redisClient.on("connect", () => {
      console.log("Connected to Redis");
    });

    await redisClient.connect();
  }
  return redisClient;
};

const getRedisClient = () => {
  if (!redisClient) {
    throw new Error("Redis client not initialized. Call connectRedis() first.");
  }
  return redisClient;
};

module.exports = {
  connectRedis,
  getRedisClient,
};
