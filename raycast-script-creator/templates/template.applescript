#!/usr/bin/osascript

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title My First Script
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 🤖
# @raycast.packageName Raycast Scripts
# @raycast.description Write a nice and descriptive summary about your script command here

# Documentation:
# @raycast.author ruzzel
# @raycast.authorURL https://raycast.com/ruzzel

on run argv
	log "Hello from My First Script: " & (item 1 of argv)
end run
