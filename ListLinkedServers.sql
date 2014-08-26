-- Return a list of linked servers for a given instance


-- 2000+
EXEC sp_linkedservers

-- 2005+
select * from sysservers
order by srvname