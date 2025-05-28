#!/bin/bash

# Notion API Manager
# A Bash utility to manage Notion updates via the Notion API

# Add to exit on command failure
set -e

#  Check and load environment variables from .env 
if [[ -f .env ]]; then
    source .env
else
    echo "Error: .env file not found. Create it with NOTION_TOKEN and DATABASE_ID."
    exit 1
fi

# Check for required dependencies
command -v curl >/dev/null 2>&1 || { echo "Error: curl is required but not installed."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not installed."; exit 1; }


# Check if NOTION_TOKEN, DATABASE_ID, API_URL, and NOTION_VERSION are set
if [[ -z "$NOTION_TOKEN" || -z "$DATABASE_ID" || -z "$API_URL" || -z "$NOTION_VERSION" ]]; then
    echo "Error: NOTION_TOKEN, DATABASE_ID, API_URL, and NOTION_VERSION does not exist. Set in .env file."
    exit 1
fi

# Function to display usage
usage() {
    echo "Usage: $0 {query|log|update} [arguments]"
    echo "Commands:"
    echo "  query                Query the database and list entries"
    echo "  log <title> <status> Add a new page to the database"
    echo "  update <page_id> <status> Update the status of a page"
    echo "Example:"
    echo "  $0 query"
    echo "  $0 log 'New Task' 'To Do'"
    echo "  $0 update 'page_id' 'Done'"
    exit 1
}

# build payload function
_build_page_payload() {
    local page_title="$1"
    local msg="$2"
    local status="${3:-}"
    local parent_id="${4:-$DATABASE_ID}"
    
    if [[ -n "parent_id"]];
    # for new pages (add_page) 
    then
        jq -n \
            --arg parent_id "$parent_id" \
            --arg page_title "$page_title" \
            --arg msg "$msg" \
        '{
            "parent": { database_id: $parent_id },
            "properties": {
                "Name": {
                    "title": [
                        {
                            "text": {
                                "content": $page_title 
                            } 
                        } 
                    ] 
                },
                "Description": {
                    "rich_text": [  { 
                        "text": {
                            "content": $msg 
                        } 
                    } ] 
                }
            }
        }'
    else 
        # For updates (update_page)
        jq -n \
        --arg page_title "$page_title" \
        --arg msg "$msg" \
        --arg status "$status" \
        '{
            "properties": {
                "Name": { 
                    "title": [
                        {
                            "text": { 
                                "content": $page_title
                            } 
                        } 
                    ] 
                },
                "Description": { 
                    "rich_text": [  { 
                        "text": { 
                            "content": $msg 
                        } 
                    } ] 
                },
                "Status": { 
                    "select": { 
                        "name": $status 
                    } 
                }
            }
        }'
    fi
}
# Function to make API requests
make_api_request() {
    # declare local vars 
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local response

    # set response var to api request  
    response=$(curl -s -X "$method" "$API_URL$endpoint" \
        -H "Authorization: Bearer $NOTION_TOKEN" \
        -H "Notion-Version: $NOTION_VERSION" \
        -H "Content-Type: application/json" \
        --data "$data")

    # Check for API errors
    if echo "$response" | jq -e '.object == "error"' >/dev/null; then
        echo "Error: API request failed - $(echo "$response" | jq -r '.message')"
        printf "$response"
        exit 1
    fi

    echo "$response"
}

# Function to query the database
query_database() {
    echo "Querying database..."
    data=$(_build_page_payload "$page_title" "$msg" "$status" "$DATABASE_ID")
    response=$(make_api_request "POST" "/databases/$DATABASE_ID/query" "$data")
    echo "$response" | jq '.results[] | {id: .id, title: .properties.Name.title[0].text.content, status: .properties.Status.select.name}'
}

# Function to add a page
add_page() {
    local page_title="$1"
    local msg="$2"

    # Validate inputs
    if [[ -z "$page_title" || -z "$msg" ]]; then
        echo "Error: Page title and Message are required for adding a page."
        usage
    fi

    echo "Adding page with title '$page_title' and message '$msg'..."
    data=$(_build_page_payload "$page_title" "$msg" "$status" 
    response=$(make_api_request "POST" "/pages" "$data")
    echo "Page added successfully: $(echo "$response" | jq -r '.id')"
}

# Function to update a page
update_page() {
    local page_title="$1"
    local msg="$2"
    local status="$3"

    # Validate inputs
    if [[ -z "$page_title" || -z "$msg" || -z "$status" ]]; then
        echo "Error: Page title, message and status are required for updating a page."
        usage
    fi


    echo "Updating page '$page_title' with $msg and status '$status'..."
    data=$(_build_page_payload "$page_title" "$msg" "$status" "")
    response=$(make_api_request "PATCH" "/pages/$page_title" "$data")
    echo "Page updated successfully: $(echo "$response" | jq -r '.id')"
}

# Main logic
case "$1" in
    query)
        query_database "$2" "$3" "$4"
        ;;
    log)
        add_page "$2" "$3"
        ;;
    update)
        update_page "$2" "$3" 
        ;;
    *)
        usage
        ;;
esac

exit 0