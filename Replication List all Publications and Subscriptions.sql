/* Show all publications and subscriptions running through a given Distributor */
USE Distribution 
GO 
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED 
-- Get the publication name based on article 
SELECT DISTINCT  
srv.srvname publication_server  

, p.publication publication_name 
 
, ss.srvname subscription_server 
, p.publisher_db
, s.subscriber_db 
, CASE WHEN p.publication_type = 0 THEN 'Tran' ELSE 'Snap' END  PublicationType
FROM MSpublications p 
JOIN MSsubscriptions s ON p.publication_id = s.publication_id 
JOIN master..sysservers ss ON s.subscriber_id = ss.srvid 
JOIN master..sysservers srv ON srv.srvid = p.publisher_id 

ORDER BY publication_server, publication, subscription_server