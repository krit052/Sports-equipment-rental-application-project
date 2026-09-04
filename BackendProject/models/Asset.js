const mongoose = require("mongoose");

const assetSchema = new mongoose.Schema({
  asset_id: { type: Number, required: true, unique: true },
  name: { type: String, required: true },
  description: { type: String, default: "" },
  image: { type: String, default: null }, // e.g. "/public/image/xxx.jpg"
  status: {
    type: String,
    enum: ["Available", "Pending", "Borrowed", "Disabled"],
    default: "Available",
  },
  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("Asset", assetSchema);
