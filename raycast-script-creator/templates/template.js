#!/usr/bin/env node

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title My First Script
// @raycast.mode fullOutput

// Optional parameters:
// @raycast.icon 🤖
// @raycast.packageName Raycast Scripts
// @raycast.description Write a nice and descriptive summary about your script command here

// Documentation:
// @raycast.author ruzzel
// @raycast.authorURL https://raycast.com/ruzzel

// Arguments arrive as process.argv.slice(2)
const [arg1] = process.argv.slice(2)

console.log(`Hello from My First Script: ${arg1 ?? ""}`)
