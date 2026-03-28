#!/bin/bash

# 1. Set local variables from environment variables

# Check that all required variables are set (not empty)
if [[ -z "$BUDIBASE_SOURCE_TENANT" ]]; then
  echo "Error: BUDIBASE_SOURCE_TENANT is required but not set."
  exit 1
fi
if [[ -z "$BUDIBASE_DESTINATION_TENANT" ]]; then
  echo "Error: BUDIBASE_DESTINATION_TENANT is required but not set."
  exit 1
fi
if [[ -z "$BUDIBASE_SOURCE_API_KEY" ]]; then
  echo "Error: BUDIBASE_SOURCE_API_KEY is required but not set."
  exit 1
fi
if [[ -z "$BUDIBASE_DESTINATION_API_KEY" ]]; then
  echo "Error: BUDIBASE_DESTINATION_API_KEY is required but not set."
  exit 1
fi
if [[ -z "$BUDIBASE_SOURCE_APP_ID" ]]; then
  echo "Error: BUDIBASE_SOURCE_APP_ID is required but not set."
  exit 1
fi
if [[ -z "$BUDIBASE_DESTINATION_APP_ID" ]]; then
  echo "Error: BUDIBASE_DESTINATION_APP_ID is required but not set."
  exit 1
fi
if [[ -z "$BUDIBASE_PUBLISH_DESTINATION_APP" ]]; then
  BUDIBASE_PUBLISH_DESTINATION_APP="false" # Default to false if not set
fi


# 2. Check for the existence of curl
if ! command -v curl &> /dev/null; then
    echo "curl could not be found."

    # 3. If curl does not exist, download it
    echo "Installing curl..."
    # Check for sudo privileges, as installing packages usually requires them.
    if [[ $EUID -ne 0 ]]; then
       echo "This script must be run as root to install curl."
       exit 1
    fi
    apt-get update && apt-get install -y curl
else
    echo "curl is already installed."
fi

# 4. Use curl to download the app export
echo "Exporting app export from $BUDIBASE_SOURCE_TENANT and app ID: $BUDIBASE_SOURCE_APP_ID..."


echo $BUDIBASE_SOURCE_TENANT/api/public/v1/applications/$BUDIBASE_SOURCE_APP_ID/export


HTTP_STATUS_EXPORT=$(curl \
     --silent \
     --write-out "%{http_code}" \
     --request POST \
     --url $BUDIBASE_SOURCE_TENANT/api/public/v1/applications/$BUDIBASE_SOURCE_APP_ID/export \
     --header 'accept: application/gzip' \
     --header 'content-type: application/json' \
     --header "x-budibase-api-key: $BUDIBASE_SOURCE_API_KEY" \
     --data '{"excludeRows":true}' \
     --output ./export.tar.gz)


echo "Export HTTP status: $HTTP_STATUS_EXPORT"
if [[ "$HTTP_STATUS_EXPORT" -ne 200 ]]; then
    echo "Error: Failed to export app. HTTP status code: $HTTP_STATUS_EXPORT"
    exit 1
else
  echo "App export successful. HTTP status code: $HTTP_STATUS_EXPORT"
  echo "App export saved to export.tar.gz"
fi

# 5. Use curl to import the app export
echo "Importing app export into $BUDIBASE_DESTINATION_TENANT and app ID: $BUDIBASE_DESTINATION_APP_ID..."

HTTP_STATUS_IMPORT=$(curl \
     --silent \
     --output /dev/null \
     --write-out "%{http_code}" \
     --request POST \
     --url $BUDIBASE_DESTINATION_TENANT/api/public/v1/applications/$BUDIBASE_DESTINATION_APP_ID/import \
     --header 'content-type: multipart/form-data' \
     --header "x-budibase-api-key: $BUDIBASE_DESTINATION_API_KEY" \
     --form 'appExport=@export.tar.gz;type=application/gzip')


if [[ "$HTTP_STATUS_IMPORT" -ne 200 && "$HTTP_STATUS_IMPORT" -ne 204  ]]; then
    echo "Error: Failed to import app. HTTP status code: $HTTP_STATUS_IMPORT"
    exit 1
else
    echo "App import successful. HTTP status code: $HTTP_STATUS_IMPORT"
fi

#6 Optionally- publish the app in the destination environment
if [[ "$BUDIBASE_PUBLISH_DESTINATION_APP" == "true" ]]; then
  echo "Publishing destination app with ID: $BUDIBASE_DESTINATION_APP_ID..."
  HTTP_STATUS_PUBLISH=$(curl \
     --silent \
     --output /dev/null \
     --write-out "%{http_code}" \
     --request POST \
     --url $BUDIBASE_DESTINATION_TENANT/api/public/v1/applications/$BUDIBASE_DESTINATION_APP_ID/publish \
     --header 'accept: application/json' \
     --header "x-budibase-api-key: $BUDIBASE_DESTINATION_API_KEY")
  if [[ "$HTTP_STATUS_PUBLISH" -ne 200 ]]; then
      echo "Error: Failed to publish app. HTTP status code: $HTTP_STATUS_PUBLISH. Your new app exists in the destination but is not published. You can publish or revert manually via Budibase."
      exit 1
  else
      echo "Destination app published successfully."
  fi
else
  echo "Skipping publishing of destination app - please publish manually via Budibase."
fi
