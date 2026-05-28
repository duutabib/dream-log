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
    echo "Usage: $0 {query|log|update|amend|del|get-id} [arguments]"
    echo "Commands:"
    echo "  query                            Query the database and list entries"
    echo "  log <title> <msg>                Add a new page to the database"
    echo "  update <page_id> <msg> <status>  Update a page"
    echo "  amend <msg> <status>             Update the most recent log entry"
    echo "  del <page_id>                    Delete a page"
    echo "  get-id <title>                   Get the page ID for a given title"
    echo "Example:"
    echo "  $0 query"
    echo "  $0 log 'Flying' 'I was flying over mountains'"
    echo "  $0 update 'abc123' 'Updated notes' 'Done'"
    echo "  $0 amend 'Updated notes' 'Done'"
    echo "  $0 get-id 'Flying'"
    echo "  $0 del 'abc123'"
    exit 1
}

# build payload function
_build_page_payload() {
    local page_title="$1"
    local msg="$2"
    local status="${3:-}"
    local parent_id="${4-$DATABASE_ID}"

    if [[ -n "$parent_id" ]]; then
        # for new pages (add_page)
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
        --arg msg "$msg" \
        --arg status "$status" \
        '{
            "properties": {
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
    local error_msg
    error_msg=$(echo "$response" | jq -r 'if .object == "error" then .message else "" end')
    if [[ -n "$error_msg" ]]; then
        echo "Error: API request failed - $error_msg"
        echo "$response"
        exit 1
    fi

    echo "$response"
}

# Function to query the database
query_database() {
    echo "Querying database..."
    local data
    local response
    data='{}'
    response=$(make_api_request "POST" "/databases/$DATABASE_ID/query" "$data")
    echo "$response" | jq '.results[] | {id: .id, title: .properties.Name.title[0].text.content, status: .properties.Status.select.name}'
}

# Function to amend the most recent log entry
amend_recent() {
    local msg="$1"
    local status="$2"

    if [[ -z "$msg" || -z "$status" ]]; then
        echo "Error: Message and status are required."
        usage
    fi

    local response page_id
    response=$(make_api_request "POST" "/databases/$DATABASE_ID/query" \
        '{"sorts": [{"timestamp": "created_time", "direction": "descending"}], "page_size": 1}')
    page_id=$(echo "$response" | jq -r '.results[0].id')

    if [[ -z "$page_id" || "$page_id" == "null" ]]; then
        echo "Error: No entries found in the database."
        exit 1
    fi

    echo "Amending most recent entry '$page_id'..."
    local data
    data=$(_build_page_payload "" "$msg" "$status" "")
    make_api_request "PATCH" "/pages/$page_id" "$data" > /dev/null
    echo "Entry updated successfully: $page_id"
}

# Function to get a page ID by title
get_id() {
    local title="$1"

    if [[ -z "$title" ]]; then
        echo "Error: Title is required."
        usage
    fi

    local response
    response=$(make_api_request "POST" "/databases/$DATABASE_ID/query" '{}')
    local id
    id=$(echo "$response" | jq -r --arg title "$title" \
        '.results[] | select(.properties.Name.title[0].text.content == $title) | .id')

    if [[ -z "$id" ]]; then
        echo "No entry found with title: $title"
        exit 1
    fi

    echo "$id"
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
    local status=""
    local data
    local response
    data=$(_build_page_payload "$page_title" "$msg" "$status")
    response=$(make_api_request "POST" "/pages" "$data")
    echo "Page added successfully: $(echo "$response" | jq -r '.id')"
}

# Function to update a page
update_page() {
    local page_id="$1"
    local msg="$2"
    local status="$3"

    # Validate inputs
    if [[ -z "$page_id" || -z "$msg" || -z "$status" ]]; then
        echo "Error: Page ID, message and status are required for updating a page."
        usage
    fi

    local data
    local response
    echo "Updating page '$page_id' with '$msg' and status '$status'..."
    data=$(_build_page_payload "$page_id" "$msg" "$status" "")
    response=$(make_api_request "PATCH" "/pages/$page_id" "$data")
    echo "Page updated successfully: $(echo "$response" | jq -r '.id')"
}

# Function to delete (archive) a page
delete_page() {
    local page_id="$1"

    if [[ -z "$page_id" ]]; then
        echo "Error: Page ID is required for deleting a page."
        usage
    fi

    echo "Deleting page '$page_id'..."
    local response
    response=$(make_api_request "PATCH" "/pages/$page_id" '{"archived": true}')
    echo "Page deleted successfully: $(echo "$response" | jq -r '.id')"
}

# Main logic
case "$1" in
    query)
        query_database
        ;;
    log)
        add_page "$2" "$3"
        ;;
    update)
        update_page "$2" "$3" "$4"
        ;;
    amend)
        amend_recent "$2" "$3"
        ;;
    del)
        delete_page "$2"
        ;;
    get-id)
        get_id "$2"
        ;;
    *)
        usage
        ;;
esac

exit 0
