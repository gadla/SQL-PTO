PRINT '-- BackupHistory'

SELECT 
    databasename = bs.database_name,
    filegroupname = bf.filegroup_name,
    pagesize = bf.page_size,
    filenumber = bf.file_number,
    backeduppagecount = bf.backed_up_page_count,
    filetype = bf.file_type,
    sourcefileblocksize = bf.source_file_block_size,
    filesize = bf.file_size,
    logicalname = bf.logical_name,
    physicaldrive = bf.physical_drive,
    physicalname = bf.physical_name,
    state = bf.[state],
    statedesc = bf.state_desc,
    BackupFilebackupsize = bf.backup_size,
    BackupFileisreadonly = bf.is_readonly,
    ispresent = bf.is_present,
    position = bs.[position],
    expirationdate = bs.expiration_date,
    softwarevendorid = bs.software_vendor_id,
    name = bs.name,
    username = bs.user_name,
    databasecreationdate = bs.database_creation_date,
    backupstartdate = bs.backup_start_date,
    backupfinishdate = bs.backup_finish_date,
    type = bs.type,
    compatibilitylevel = bs.compatibility_level,
    databaseversion = bs.database_version,
    BackupSetbackupsize = bs.backup_size,
    servername = bs.server_name,
    machinename = bs.machine_name,
    collationname = bs.collation_name,
    ispasswordprotected = bs.is_password_protected,
    recoverymodel = bs.recovery_model,
    hasbulkloggeddata = bs.has_bulk_logged_data,
    issnapshot = bs.is_snapshot,
    BackupSetisreadonly = bs.is_readonly,
    issingleuser = bs.is_single_user,
    hasbackupchecksums = bs.has_backup_checksums,
    isdamaged = bs.is_damaged,
    beginslogchain = bs.begins_log_chain,
    isforceoffline = bs.is_force_offline,
    iscopyonly = bs.is_copy_only,
    compressedbackupsize = bs.compressed_backup_size,
    mirror = bm.mirror, 
	physical_device_name

FROM
    msdb..backupfile bf
    JOIN msdb..backupset bs
    ON bf.backup_set_id = bs.backup_set_id
    JOIN msdb..backupmediafamily bm
    ON bs.media_set_id = bm.media_set_id
ORDER BY
    backup_finish_date DESC