const express = require("express");
const os = require("os");
const app = express();
const apiMetrics = require("prometheus-api-metrics");
app.use(apiMetrics());
app.use(express.json());

const client = require("prom-client");

// Create Prometheus Gauge metric
const gauge = new client.Gauge({
  name: "custom_metric_counter_total_by_pod",
  help: "Custom metric: Count per Pod",
  labelNames: ["pod"],
});

app.post("/api/count", (req, res) => {
  // Set metric to count value...and label to "pod name" (hostname)
  gauge.set({ pod: os.hostname }, req.body.count);
  res.status(200).send("Counter at: " + req.body.count);
});

app.listen(4000, () => {
  console.log("Server is running on port 4000");
  // initialize gauge
  gauge.set({ pod: os.hostname }, 1);
});
