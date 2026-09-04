const mongoose = require("mongoose");

async function connectDB() {
  mongoose.set("strictQuery", true);
  const uri = process.env.MONGO_URI || "mongodb://127.0.0.1:27017/project";
  await mongoose.connect(uri);
  console.log("Status: connected to local database successfully");
}

module.exports = connectDB;
