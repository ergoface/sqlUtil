/* Show info for all file share subscriptions */
SELECT Subscriptions.InactiveFlags
     ,Subscriptions.ExtensionSettings
     ,Subscriptions.ModifiedDate
     ,Subscriptions.Description
     ,Subscriptions.LastStatus
     ,Subscriptions.LastRunTime
     ,Subscriptions.Parameters
     ,Subscriptions.DeliveryExtension
     ,Users.UserName
     ,Users.AuthType
     ,Users.UserType
     ,C.Path
   FROM Subscriptions
      INNER JOIN Catalog C
         ON Subscriptions.Report_OID = C.ItemID 
      INNER JOIN Users
         ON Subscriptions.OwnerID = Users.UserID
   WHERE ( Subscriptions.DeliveryExtension = 'Report Server FileShare' )
   ORDER BY LastStatus