#!/bin/bash

# Function to handle termination signal
term_handler() {
  echo "Termination signal received, stopping services..."
  
  # Call your stop script to stop all services gracefully
  /opt/dbmarlin/stop.sh
  
  # Exit the script
  exit 0
}

# Trap SIGTERM signal
trap 'term_handler' SIGTERM

pwd
whoami
ls -l

if [ -n $DOCKER ]
then
  # Only copy from /dbmarlin-install to /opt/dbmarlin if we run docker
  cp -r /dbmarlin-install/dbmarlin/* /opt/dbmarlin
fi

# Change ownership of the data directory needed
chmod 750 /opt/dbmarlin/postgresql/data

# Run the configure script
./configure.sh -a -n9090 -t9080 -p9070 -sSmall -u

# Copy the start-and-tail.sh script to the /opt/dbmarlin directory (can get deleted by configure.sh)
cp /dbmarlin-install/dbmarlin/start-and-tail.sh /opt/dbmarlin

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
