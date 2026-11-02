return {
    storeName = "DoubleLife_Profile_v1",
    leaseSeconds = 120,
    autosaveSeconds = 35, -- staggered by up to 10 s; well below the lease
    recoverySeconds = 180, -- asynchronous reconnect attempts; each store call still has bounded retries
    -- Explicit opt-in only in a separately published test universe. Never reuse the live namespace.
    studioEnabled = false,
    studioUniverseId = 0,
    studioStoreName = "DoubleLife_M4_ISOLATED_TEST_v1",
}
