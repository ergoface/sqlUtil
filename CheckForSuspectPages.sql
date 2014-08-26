/* Check for Suspect Pages in an Instance */
SELECT * FROM msdb..suspect_pages
   WHERE (event_type = 1 OR event_type = 2 OR event_type = 3);
GO