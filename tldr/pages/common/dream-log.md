# dream-log

> Log and manage dream journal entries in a Notion database via the Notion API.
> More information: <https://github.com/duutabib/dream-log>.

- List all dream entries in the database:

`dream-log query`

- Add a new dream entry:

`dream-log log "{{title}}" "{{description}}"`

- Look up the page ID of an entry by its title:

`dream-log get-id "{{title}}"`

- Update an entry's notes and status by page ID:

`dream-log update {{page_id}} "{{notes}}" {{New|Reviewed|Done}}`

- Update the notes and status of the most recently added entry:

`dream-log amend "{{notes}}" {{New|Reviewed|Done}}`

- Delete (archive) an entry by page ID:

`dream-log del {{page_id}}`

- Look up an entry by title and delete it in one step:

`dream-log del $(dream-log get-id "{{title}}")`
