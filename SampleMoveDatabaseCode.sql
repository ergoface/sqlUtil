--- On First Server
   BACKUP DATABASE ksar_tui TO DISK = 'D:\MSSQL\TUI.bak'
	WITH  FORMAT
	
--- On Destination Server
RESTORE FILELISTONLY FROM DISK =  N'C:\Users\davbent\Desktop\TUI.bak'

-- Use results from this to specify the filenames to change for the new server. Use appropriate data locatipons

RESTORE DATABASE ksar_tui FROM DISK = N'C:\Users\davbent\Desktop\TUI.bak' 
	WITH MOVE 'ksar_tui' TO 'D:\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\DATA\ksar_tui.mdf',
	 MOVE 'ksar_tui_log' TO 'D:\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\LOG\ksar_tui.ldf'