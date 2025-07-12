
PRINT '-- RGConfig'
select * from sys.dm_resource_governor_configuration

PRINT '-- RGPools'
select * from sys.dm_resource_governor_resource_pools

PRINT '-- RGWorkloadGroups'
select * from sys.dm_resource_governor_workload_groups
