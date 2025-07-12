rem Written By: Tim Chapman
rem Go find the location of the System Path for the system health session
rem And Copy those files out.

rem %1 = location to copy to
rem %2 = filename to execute
rem %3 = server instnace to connect to

for /F usebackq %%z in (`sqlcmd -E -S "%3" -h-1 -i "%2"`) do (
    for %%i in (%%z) do (
     copy %%i "%1"
)
)
