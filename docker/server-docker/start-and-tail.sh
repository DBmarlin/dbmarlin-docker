#!/bin/bash

pwd
whoami
ls -l

# Start DBmarlin application in the background
/opt/dbmarlin/start.sh &

# Wait a bit for the app to initialize and logs to be created if needed
sleep 5

# Use a while loop to continuously check for new log files and tail them
# This is a simplistic approach; consider enhancing for production use
while true; do
  tail -n 100 -F /opt/dbmarlin/tomcat/logs/localhost.$(date +%Y-%m-%d).log
  sleep 60 # Check for a new file every 60 seconds
done
