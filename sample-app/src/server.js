const express = require("express");
const app = express();

const PORT = process.env.PORT || 3000;
const AUTHOR = "Rajamohan";

// Root endpoint
app.get("/", (req, res) => {
  res.json({
    message: "Enterprise DevSecOps Platform Running",
    author: AUTHOR,
    timestamp: new Date(),
    status: "healthy"
  });
});

// Health check endpoint
app.get("/health", (req, res) => {
  res.status(200).json({
    status: "UP",
    service: "DevSecOps Sample App",
    author: AUTHOR
  });
});

// Info endpoint
app.get("/info", (req, res) => {
  res.json({
    application: "Enterprise DevSecOps Platform",
    version: "1.0.0",
    author: AUTHOR,
    environment: process.env.NODE_ENV || "dev"
  });
});

app.listen(PORT, () => {
  console.log(`🚀 App started by ${AUTHOR}`);
  console.log(`Listening on port ${PORT}`);
});