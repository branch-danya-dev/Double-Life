local n = require("./m120/Timeline").run(require("../src/shared/Config"), require("../src/server/RoundPolicy"), require("../src/shared/RoundTime"))
print("M12.0 timeline PASS: " .. n .. " assertions")
