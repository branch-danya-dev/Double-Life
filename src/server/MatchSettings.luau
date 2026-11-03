-- Explicit staging gate. Never auto-enable network transport or production stores.
return {
    targetSize = 8, lobbyDensity = 6, maxMimics = 8, aiWorkers = 2,
    readySeconds = 3, queueSeconds = 900, retrySeconds = 5,
    ticketLease = 45, assignmentLease = 90, poolLimit = 64,
    crossServerEnabled = false, stagingUniverseId = 0, stagingPlaceId = 0,
    memoryNamespace = "DoubleLife_M9_Staging_v1",
}
