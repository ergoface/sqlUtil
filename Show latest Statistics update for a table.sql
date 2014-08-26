/* Show the latest Statistics Update on a given Table */

SELECT name AS stats_name, 
    STATS_DATE(object_id, stats_id) AS statistics_update_date
FROM sys.stats 
WHERE object_id = OBJECT_ID('NetGain');