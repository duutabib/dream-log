# dream-log

A Bash utility to log and manage dream entries in a Notion database via the Notion API.

---

## Requirements

- [`curl`](https://curl.se/)
- [`jq`](https://stedolan.github.io/jq/)
- A Notion integration token and a database shared with that integration

---

## Setup

**1. Create a Notion integration**

Go to [notion.so/my-integrations](https://www.notion.so/my-integrations), create a new integration, and copy the token.

**2. Share your database with the integration**

Open your Notion database → `...` → **Connections** → add your integration.

**3. Configure `.env`**

Create a `.env` file in the project root:

```
NOTION_TOKEN=your_integration_token
DATABASE_ID=your_database_id
API_URL=https://api.notion.com/v1
NOTION_VERSION=2022-06-28
```

> The `DATABASE_ID` is the 32-character hex ID from your database URL — strip any `?v=...` view parameter.

---

## Commands

```
Usage: ./dream_logger.sh {query|log|update|delete} [arguments]

  query                            List all entries in the database
  log <title> <msg>                Add a new dream entry
  update <page_id> <msg> <status>  Update a dream's notes and status
  del <page_id>                    Delete (archive) a dream entry
```

---

## Usage

### Query — list all entries

```bash
$ ./dream_logger.sh query

Querying database...
{
  "id": "36ec4fd1-da0d-813a-97c3-d550fce7d7e6",
  "title": "Flying over mountains",
  "status": "Done"
}
```

### Log — add a new entry

```bash
$ ./dream_logger.sh log 'Flying over mountains' 'I was soaring above snowy peaks at dusk.'

Adding page with title 'Flying over mountains'...
Page added successfully: 36ec4fd1-da0d-813a-97c3-d550fce7d7e6
```

### Update — change notes and status

```bash
$ ./dream_logger.sh update '36ec4fd1-da0d-813a-97c3-d550fce7d7e6' 'Vivid colours, felt very real.' 'Done'

Updating page '36ec4fd1-da0d-813a-97c3-d550fce7d7e6'...
Page updated successfully: 36ec4fd1-da0d-813a-97c3-d550fce7d7e6
```

> Valid status values: `New`, `Reviewed`, `Done`

### Del — remove an entry

```bash
$ ./dream_logger.sh del '36ec4fd1-da0d-813a-97c3-d550fce7d7e6'

Deleting page '36ec4fd1-da0d-813a-97c3-d550fce7d7e6'...
Page deleted successfully: 36ec4fd1-da0d-813a-97c3-d550fce7d7e6
```

---

## Database schema

The script expects the following properties on your Notion database:

| Property    | Type      |
|-------------|-----------|
| Name        | Title     |
| Description | Rich text |
| Status      | Select    |
