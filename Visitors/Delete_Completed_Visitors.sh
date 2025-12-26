#!/bin/bash

# API Endpoint and Authentication
VISITOR_API="https://10.X.X.X:12445/api/v1/developer/visitors"
AUTH_HEADER="Authorization: Bearer <API_KEY>"

# Get the current Unix timestamp
CURRENT_TIMESTAMP=$(date +%s)

echo "Fetching all visitors..."

# Fetch all visitors from the API
VISITOR_RESPONSE=$(curl -s -k "$VISITOR_API" -H "$AUTH_HEADER")

# Check for curl errors
if [ $? -ne 0 ]; then
  echo "Error: Failed to fetch data from the API."
  exit 1
fi

echo "Filtering for completed visitors..."

# Use jq to filter for completed visitors and extract their IDs into a bash array.
# The 'read -r -d ""' is a safe way to read the whole output from jq.
# The 'mapfile -t' reads the lines of output into an array.
mapfile -t COMPLETED_VISITOR_IDS < <(echo "$VISITOR_RESPONSE" | jq -r --argjson now "$CURRENT_TIMESTAMP" '
  .data[] | 
  select(.end_time != null and .end_time < $now) | 
  .id
')

# Get the count of visitors to delete
VISITOR_COUNT=${#COMPLETED_VISITOR_IDS[@]}

# If there are no visitors to delete, exit
if [ "$VISITOR_COUNT" -le 0 ]; then
  echo "No completed visitors found to delete."
  exit 0
fi

# Ask for confirmation
read -p "Are you sure you want to complete this action? This will delete $VISITOR_COUNT old visitors (y/n): " -n 1 -r
echo # Move to a new line

# If the user says yes, proceed with deletion
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Starting deletion..."
  
  # Loop through the array of IDs and delete each visitor
  for visitor_id in "${COMPLETED_VISITOR_IDS[@]}"; do
    if [ -n "$visitor_id" ]; then
      echo "Deleting visitor with ID: $visitor_id"
      
      # Construct the full API URL for deletion with is_force=true
      DELETE_URL="$VISITOR_API/$visitor_id?is_force=true"
      
      # Send the DELETE request
      response=$(curl -s -k -X DELETE "$DELETE_URL" -H "$AUTH_HEADER")
      
      # Display the response from the server
      echo "Response: $response"
      echo # Add a newline for better readability
    fi
  done
  
  echo "Deletion process completed."
else
  echo "Deletion cancelled."
fi
