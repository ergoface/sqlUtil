/* Bulk update Subscription Ownership from Old user to New user 
    This only converts email subscriptions, but can be used for other types if you drop event type and 
    DeliveryExtentsion criteria. */   
USE ReportServer
GO
DECLARE @OldUserID uniqueidentifier
DECLARE @NewUserID uniqueidentifier
SELECT @OldUserID = UserID FROM dbo.Users WHERE UserName = 'CORP\Davbent'
SELECT @NewUserID = UserID FROM dbo.Users WHERE UserName = 'CORP\A1OKCSQLAppDev4'
UPDATE dbo.Subscriptions SET OwnerID = @NewUserID WHERE OwnerID = @OldUserID AND EventType = 'TimedSubscription' AND DeliveryExtension = 'Report Server Email'