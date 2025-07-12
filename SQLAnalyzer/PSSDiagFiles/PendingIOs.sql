SET NOCOUNT ON

WHILE(1=1)
BEGIN
PRINT '-- PendingIOs'
SELECT Runtime = GETDATE(), *
FROM sys.dm_io_pending_io_requests
WAITFOR DELAY '0:0:5'
END