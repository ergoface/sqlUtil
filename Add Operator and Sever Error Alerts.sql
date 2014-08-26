/*** Add Alerts for Severe Errors 
     This script will create an operator 'Test Operator', name and email can/should be changed.
     Based on scripts from Brent Ozar and a couple of other sources.
****/
USE [msdb] ;
GO
-- Create the Operator
/*
IF NOT EXISTS ( SELECT  1
                FROM    msdb.dbo.sysoperators
                WHERE   name = N'Test Operator' )
    BEGIN
        EXEC msdb.dbo.sp_add_operator @name = NN'Test Operator',
            @enabled = 1, @email_address = N'*** Email Address Here ***'
    END ;
GO
*/
-- Alert 823 - Hard I/O Corruption
IF EXISTS ( SELECT  name
            FROM    msdb.dbo.sysalerts
            WHERE   name = N'823 - Hard I/O Corruption' )
    EXEC msdb.dbo.sp_delete_alert @name = N'823 - Hard I/O Corruption' ;
GO
EXEC msdb.dbo.sp_add_alert @name = N'823 - Hard I/O Corruption',
    @message_id = 823, @severity = 0, @enabled = 1,
    @delay_between_responses = 0, @include_event_description_in = 5,
    @notification_message = N'This is where SQL Server has asked the OS to read the page but it just cant',
    @category_name = N'[Uncategorized]',
    @job_id = N'00000000-0000-0000-0000-000000000000' ;
GO
-- Add Notification
EXEC msdb.dbo.sp_add_notification @alert_name = N'823 - Hard I/O Corruption',
    @operator_name = N'DBA', @notification_method = 1 ;
GO

-- Alert [824 - Soft I/O Corruption]
IF EXISTS ( SELECT  name
            FROM    msdb.dbo.sysalerts
            WHERE   name = N'824 - Soft I/O Corruption' )
    EXEC msdb.dbo.sp_delete_alert @name = N'824 - Soft I/O Corruption' ;
GO
EXEC msdb.dbo.sp_add_alert @name = N'824 - Soft I/O Corruption',
    @message_id = 824, @severity = 0, @enabled = 1,
    @delay_between_responses = 0, @include_event_description_in = 5,
    @notification_message = N'This is where the OS could read the page but SQL Server decided that the page was corrupt - for example with a page checksum failure',
    @category_name = N'[Uncategorized]',
    @job_id = N'00000000-0000-0000-0000-000000000000' ;
GO
-- Add Notification
EXEC msdb.dbo.sp_add_notification @alert_name = N'824 - Soft I/O Corruption',
    @operator_name = N'DBA', @notification_method = 1 ;
GO

-- Alert Corruption: Read/Retry 825
IF EXISTS ( SELECT  name
            FROM    msdb.dbo.sysalerts
            WHERE   name = N'Corruption: Read/Retry 825' )
    EXEC msdb.dbo.sp_delete_alert @name = N'Corruption: Read/Retry 825' ;
GO
EXEC msdb.dbo.sp_add_alert @name = N'Corruption: Read/Retry 825',
    @message_id = 825, @severity = 0, @enabled = 1,
    @delay_between_responses = 600, @include_event_description_in = 5,
    @notification_message = N'This is where either an 823 or 824 occured, SQL server retried the IO automatically and it succeeded. This error is written to the errorlog only - you need to be aware of these as they''re a sign of your IO subsystem going awry. There''s no way to turn off read-retry and force SQL Server to ''fail-fast'' - whether this behavior is a good or bad thing can be argued both ways - personally I don''t like it',
    @category_name = N'[Uncategorized]',
    @job_id = N'00000000-0000-0000-0000-000000000000' ;
GO
-- Add Notification
EXEC msdb.dbo.sp_add_notification @alert_name = N'Corruption: Read/Retry 825',
    @operator_name = N'DBA', @notification_method = 1 ;
GO

IF EXISTS ( SELECT  name
            FROM    msdb.dbo.sysalerts
            WHERE   name = N'Severity 017' )
    EXEC msdb.dbo.sp_delete_alert @name = N'Severity 017' ;
GO
EXEC msdb.dbo.sp_add_alert @name=N'Severity 017',
@message_id=0,
@severity=17,
@enabled=1,
@delay_between_responses=60,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 017', @operator_name=N'DBA', @notification_method = 7;
GO
IF EXISTS ( SELECT  name
            FROM    msdb.dbo.sysalerts
            WHERE   name = N'Severity 018' )
    EXEC msdb.dbo.sp_delete_alert @name = N'Severity 018' ;
GO
EXEC msdb.dbo.sp_add_alert @name=N'Severity 018',
@message_id=0,
@severity=18,
@enabled=1,
@delay_between_responses=60,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 018', @operator_name=N'DBA', @notification_method = 7;
GO
IF EXISTS ( SELECT  name
            FROM    msdb.dbo.sysalerts
            WHERE   name = N'Severity 019' )
    EXEC msdb.dbo.sp_delete_alert @name = N'Severity 019' ;
GO
EXEC msdb.dbo.sp_add_alert @name=N'Severity 019',
@message_id=0,
@severity=19,
@enabled=1,
@delay_between_responses=60,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 019', @operator_name=N'DBA', @notification_method = 7;
GO
IF EXISTS ( SELECT  name
            FROM    msdb.dbo.sysalerts
            WHERE   name = N'Severity 020' )
    EXEC msdb.dbo.sp_delete_alert @name = N'Severity 020' ;
GO
EXEC msdb.dbo.sp_add_alert @name=N'Severity 020',
@message_id=0,
@severity=20,
@enabled=1,
@delay_between_responses=60,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 020', @operator_name=N'DBA', @notification_method = 7;
GO
IF EXISTS ( SELECT  name
            FROM    msdb.dbo.sysalerts
            WHERE   name = N'Severity 021' )
    EXEC msdb.dbo.sp_delete_alert @name = N'Severity 021' ;
GO
EXEC msdb.dbo.sp_add_alert @name=N'Severity 021',
@message_id=0,
@severity=21,
@enabled=1,
@delay_between_responses=60,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 021', @operator_name=N'DBA', @notification_method = 7;
GO
IF EXISTS ( SELECT  name
            FROM    msdb.dbo.sysalerts
            WHERE   name = N'Severity 022' )
    EXEC msdb.dbo.sp_delete_alert @name = N'Severity 022' ;
GO
EXEC msdb.dbo.sp_add_alert @name=N'Severity 022',
@message_id=0,
@severity=22,
@enabled=1,
@delay_between_responses=60,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 022', @operator_name=N'DBA', @notification_method = 7;
GO
IF EXISTS ( SELECT  name
            FROM    msdb.dbo.sysalerts
            WHERE   name = N'Severity 023' )
    EXEC msdb.dbo.sp_delete_alert @name = N'Severity 023' ;
GO
EXEC msdb.dbo.sp_add_alert @name=N'Severity 023',
@message_id=0,
@severity=23,
@enabled=1,
@delay_between_responses=60,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 023', @operator_name=N'DBA', @notification_method = 7;
GO
IF EXISTS ( SELECT  name
            FROM    msdb.dbo.sysalerts
            WHERE   name = N'Severity 024' )
    EXEC msdb.dbo.sp_delete_alert @name = N'Severity 024' ;
GO
EXEC msdb.dbo.sp_add_alert @name=N'Severity 024',
@message_id=0,
@severity=24,
@enabled=1,
@delay_between_responses=60,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 024', @operator_name=N'DBA', @notification_method = 7;
GO
IF EXISTS ( SELECT  name
            FROM    msdb.dbo.sysalerts
            WHERE   name = N'Severity 025' )
    EXEC msdb.dbo.sp_delete_alert @name = N'Severity 025' ;
GO
EXEC msdb.dbo.sp_add_alert @name=N'Severity 025',
@message_id=0,
@severity=25,
@enabled=1,
@delay_between_responses=60,
@include_event_description_in=1,
@job_id=N'00000000-0000-0000-0000-000000000000';
GO
EXEC msdb.dbo.sp_add_notification @alert_name=N'Severity 025', @operator_name=N'DBA', @notification_method = 7;
GO
-- Alert Error - 9100 (Index Corruption)
IF EXISTS ( SELECT  name
            FROM    msdb.dbo.sysalerts
            WHERE   name = N'Error - 9100 (Index Corruption)' )
    EXEC msdb.dbo.sp_delete_alert @name = N'Error - 9100 (Index Corruption)' ;
GO
EXEC msdb.dbo.sp_add_alert @name = N'Error - 9100 (Index Corruption)',
    @message_id = 9100, @severity = 0, @enabled = 1,
    @delay_between_responses = 180, @include_event_description_in = 7,
    @category_name = N'[Uncategorized]',
    @job_id = N'00000000-0000-0000-0000-000000000000' ;
GO
-- Add Notification
EXEC msdb.dbo.sp_add_notification @alert_name = N'Error - 9100 (Index Corruption)',
    @operator_name = N'DBA', @notification_method = 1 ;
GO