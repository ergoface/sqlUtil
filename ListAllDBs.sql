/***************************************
* List All Databases for an Instance
* Uses Check to distinguish between 2000 and 2000+ since the info is stored differently
*
****************************************/

Declare @version Decimal(10,2)
SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS')PhysicalServerName, COALESCE(SERVERPROPERTY('INSTANCE'),'Default') Instance, @@SERVERNAME ConnectionName,
SERVERPROPERTY('productversion') ProductVersion, SERVERPROPERTY('productlevel')ProductLevel, SERVERPROPERTY('edition') SQLServerEdition,
SERVERPROPERTY('IsClustered') IsClustered, SERVERPROPERTY('IsIntegratedSecurityOnly') IntegratedSecurityOnly,
SERVERPROPERTY('LicenseType') LicenseType, SERVERPROPERTY('NumLicenses') NumLicenses, SERVERPROPERTY('MachineName') MachineName
SELECT @version = CAST(LEFT(CAST(SERVERPROPERTY('productversion') AS VARCHAR(20)),2)AS Decimal(10,2))

if  @version < 9
	Begin
		select 'SQL 2000'
		USE master
		select name ,
				crdate ,
				cmptlevel ,
				filename ,
				version 
				from master..sysdatabases
	end
ELSE
	Begin
        select 'SQL 2005+'
        SELECT	d.name,
				d.create_date,
				d.compatibility_level,
				d.recovery_model_desc,
				d.database_id
			FROM master.sys.databases AS D 
			WHERE d.database_id > 4
			ORDER BY name
			
		
	END
	
