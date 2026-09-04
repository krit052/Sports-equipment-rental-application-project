const mongoose = require("mongoose");

const counterSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  seq: { type: Number, default: 0 },
});

const Counter = mongoose.model("Counter", counterSchema);

// Produces sequential integer IDs (user_id / asset_id / request_id) instead of
// Mongo ObjectIds, because the Flutter app treats these ids as ints
// (JWT payload['user_id'] as int, int.parse(request_id), etc).
async function nextSequence(name) {
  const doc = await Counter.findByIdAndUpdate(
    name,
    { $inc: { seq: 1 } },
    { returnDocument: "after", upsert: true }
  );
  return doc.seq;
}

module.exports = { Counter, nextSequence };
