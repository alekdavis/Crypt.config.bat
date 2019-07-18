@echo off
rem ------------------------------------------------------------------
rem Uses .NET Framework's aspnet_regiis.exe utility to encrypt or
rem decrypt sensitive settings in the application configuration files,
rem create or delete RSA key containers, grant or revoke access to the
rem RSA key containers for users or groups, and export or import
rem RSA keys to or from files.
rem
rem To see usage help information, run this script with the '?' switch.
rem
rem For licensing, run this script with the 'license' switch.
rem
rem For an overview, see https://github.com/alekdavis/Crypt.config.bat.
rem

@if not "%ECHO%"=="" echo %ECHO%
@if not "%OS%"=="Windows_NT" goto :DOSEXIT

rem Set local scope and call MAIN procedure
setlocal & pushd >nul & set RET=

set SCRIPT_VERSION=1.1.0
set SCRIPT_YEAR=2019
set SCRIPT_COMPANY=
set SCRIPT_AUTHOR=Alek Davis

rem ------------------------------------------------------------------
rem INITIALIZE RUNTIME DEFAULTS:
rem

rem Path to folder holding configuration file.
rem If not set, the script folder will be used.
set DEFAULT_DIR=

rem Names or file masks to identify the configuration file to be
rem processed. Separate multiple values by colons (:).
rem Names will be appended to the folder to build the full path.
set DEFAULT_INCLUDE=*.exe.config:web.config

rem Names of files to be excluded. Uses the same format as DEFAULT_INCLUDE.
set DEFAULT_EXCLUDE=

rem Name of the RSA key container used for encryption/decryption.
set DEFAULT_CONTAINER=

rem Named RSA encryption provider, as defined in the configuration file.
set DEFAULT_PROVIDER=

rem Section of the configuration file to be encrypted/decrypted.
set DEFAULT_SECTION=secureAppSettings

rem Path to the export/import file holding the serialized RSA key.
set DEFAULT_KEY=

rem Identity of the application user or group account.
set DEFAULT_ACCOUNT=NT AUTHORITY\NETWORK SERVICE

rem External files to back up before performing encryption/decryption.
rem Uses the same format as DEFAULT_INCLUDE.
set DEFAULT_BACKUP=

rem Extension for backup file(s).
set DEFAULT_BAK=.bak

rem Extension of the key container file.
set DEFAULT_XML=.xml

rem Indicates whether we must back up files.
set DEFAULT_MUSTBACKUP=0

rem Indicates whether to create new RSA key container as non-exportable.
set DEFAULT_NOEXPORT=0

rem
rem END OF RUNTIME DEFAULT INITIALIZATION.
rem ------------------------------------------------------------------

rem Define error exit codes.
set ERROR_INVALID_OPERATION=1
set ERROR_FILE_NOT_FOUND=2
set ERROR_ASPNETREGIIS_NOT_FOUND=3
set ERROR_MISSING_REQUIRED_PARAM=4
set ERROR_FILE_RENAME=5
set ERROR_FILE_BACKUP=6
set ERROR_ASPNET_REGIIS=7

rem Set script's path parts.
set SCRIPTNAME=%~n0%~x0
set SCRIPTPATH=%~f0
set SCRIPTDIR=%~dp0
set SCRIPTEXT=%~x0

rem Use %TRACE% to log debug statements.
if "%DEBUG%"=="1" (set TRACE=echo) else (set TRACE=rem)

rem Display help or license info, if needed.
if /i "%1"=="/help"         set OPERATION=help
if /i "%1"=="/?"            set OPERATION=help
if /i "%1"=="/h"            set OPERATION=help
if /i "%1"=="/license"      set OPERATION=license
if /i "%1"=="/copyright"    set OPERATION=license

rem Invoke the Main method.
if /i "%OPERATION%"=="help" (
    call :MAIN help
) else (
    call :MAIN %*
)

rem We're done.
:EXIT
popd & endlocal & set RET=%RET%
goto :EOF

rem ------------------------------------------------------------------
rem MAIN PROCEDURE
rem
:MAIN
if defined TRACE %TRACE% [proc %0 %*]

rem If the folder is not specified, use the script folder.
if "%DEFAULT_DIR%"=="" (
    set dir=%SCRIPTDIR%
) else (
    set dir=%DEFAULT_DIR%
)

rem Set runtime variables to default values.
set include=%DEFAULT_INCLUDE%
set exclude=%DEFAULT_EXCLUDE%
set container=%DEFAULT_CONTAINER%
set provider=%DEFAULT_PROVIDER%
set section=%DEFAULT_SECTION%
set key=%DEFAULT_KEY%
set account=%DEFAULT_ACCOUNT%
set bak=%DEFAULT_BAK%
set backup=%DEFAULT_BACKUP%
set mustbackup=%DEFAULT_MUSTBACKUP%
set noexport=%DEFAULT_NOEXPORT%

rem Process command line and set up variables.
set CMDLINE=%*

call :PARSECMDLINE 0

rem The first argument defines the operation.
call :GETARG 1
if "%OPERATION%"=="" set OPERATION=%RET%

rem Process command-line switches
set /a IX=1
:GETSWITCHLOOP
    call :GETSWITCH %IX%

    if "%RET%"=="" goto :GETSWITCHLOOPEND
    set /a IX+=1

    if /i "%RET%"=="/include"   set include=%RETV%
    if /i "%RET%"=="/exclude"   set exclude=%RETV%
    if /i "%RET%"=="/dir"       set dir=%RETV%
    if /i "%RET%"=="/container" set container=%RETV%
    if /i "%RET%"=="/provider"  set provider=%RETV%
    if /i "%RET%"=="/section"   set section=%RETV%
    if /i "%RET%"=="/key"       set key=%RETV%
    if /i "%RET%"=="/account"   set account=%RETV%
    if /i "%RET%"=="/backup"    set mustbackup=1 & set backup=%RETV%
    if /i "%RET%"=="/bak"       set mustbackup=1 & set bak=%RETV%
    if /i "%RET%"=="/quiet"     set quiet=1
    if /i "%RET%"=="/q"         set quiet=1
    if /i "%RET%"=="/silent"    set quiet=1
    if /i "%RET%"=="/s"         set quiet=1
    if /i "%RET%"=="/nologo"    set nologo=1
    if /i "%RET%"=="/print"     set print=1
    if /i "%RET%"=="/noexport"  set noexport=1
    if /i "%RET%"=="/noexp"     set noexport=1

goto :GETSWITCHLOOP
:GETSWITCHLOOPEND

rem Set path to aspnet_regiis.exe.
call :GETASPNETREGIIS
set aspnet_regiis=%ret%

rem Make sure folder ends with a backslash character.
if "%dir%"=="" set dir=.
if not "%dir:~-1%"=="\" set dir=%dir%\

rem Make sure we have a backup extension.
if "%mustbackup%"=="1" (
    if "%bak%"=="" set bak=%DEFAULT_BAK%
    if "%bak%"=="" set bak=.bak
)

rem If key file is not specified, set it to the container name.
if "%key%"=="" (
    rem If container is specified, use it as file name.
    if not "%container%"=="" (
        set key=%dir%%container%%DEFAULT_XML%
    )
) else (
    rem If key contains a backslash char, leave it;
    rem otherwise, add key to the folder to generate full path.
    call :HASBACKSLASH "%key%"
    if not "%ret%"=="1" set key=%dir%%key%
)

rem Print version.
call :VERSION

rem Print runtime parameters, if needed.
if "%print%"=="1" call :PRINT

rem Make sure aspnet_regiis.exe exists.
if "%aspnet_regiis%"==""  (
    call :LOGERROR Cannot find 'aspnet_regiis.exe' in any of the expected .NET Framework's folders.
    call :SETEXITCODE %ERROR_ASPNETREGIIS_NOT_FOUND%
    goto :EOF
)

rem Check the operation type and perform the action.
if /i "%OPERATION%"=="encrypt" (
    call :ENCRYPTDECRYPT %CMDLINE%
) else if /i "%OPERATION%"=="decrypt" (
    call :ENCRYPTDECRYPT %CMDLINE%
) else if /i "%OPERATION%"=="create" (
    call :CREATEDELETE
) else if /i "%OPERATION%"=="delete" (
    call :CREATEDELETE
) else if /i "%OPERATION%"=="export" (
    call :EXPORTIMPORT
) else if /i "%OPERATION%"=="import" (
    call :EXPORTIMPORT
) else if /i "%OPERATION%"=="grant" (
    call :GRANTREVOKE
) else if /i "%OPERATION%"=="revoke" (
    call :GRANTREVOKE
) else if /i "%OPERATION%"=="print" (
    call :PRINT
) else if /i "%OPERATION%"=="help" (
    call :HELP
) else if /i "%OPERATION%"=="?" (
    call :HELP
) else if /i "%OPERATION%"=="license" (
    call :LICENSE
) else if /i "%OPERATION%"=="copyright" (
    call :LICENSE
) else if /i "%OPERATION%"=="version" (
    rem Do nothing since we already printed version.
) else if /i "%OPERATION%"=="" (
    call :ENCRYPTDECRYPT %CMDLINE%
) else (
    call :LOGERROR Invalid operation '%OPERATION%' specified.
    call :LOGERROR Allowed operations:
    call :LOGERROR - encrypt
    call :LOGERROR - decrypt
    call :LOGERROR - create
    call :LOGERROR - delete
    call :LOGERROR - export
    call :LOGERROR - import
    call :LOGERROR - grant
    call :LOGERROR - revoke
    call :LOGERROR - print
    call :LOGERROR - license
    call :LOGERROR - version
    call :LOGERROR Use '%SCRIPTNAME% ?' to see help information.
    call :SETEXITCODE %ERROR_INVALID_OPERATION%
)

goto :EOF

rem ------------------------------------------------------------------
rem MAIN OPERATION METHODS
rem ------------------------------------------------------------------

rem ------------------------------------------------------------------
rem Encrypts/decrypts a configuration section in the .config file(s).
rem
rem Arguments:
rem %*=script command line arguments
rem
:ENCRYPTDECRYPT
setlocal EnableDelayedExpansion
if defined TRACE %TRACE% [proc %0 %*]
    rem Make sure the section name is specified.
    if "%section%"=="" (
        rem If script was invoked with no parameters, show help.
        if "%1"=="" (
            call :HELP
            goto :EXIT_ENCRYPTDECRYPT
        )

        rem Script was invoked with parameters, so something is wrong.
        call :LOGERROR Missing section name.
        call :LOGERROR Use the '/section' switch.
        call :SETEXITCODE %ERROR_MISSING_REQUIRED_PARAM%
        goto :EXIT_ENCRYPTDECRYPT
    )

    rem Back up external files (if needed).
    if not "%backup%"=="" (
        call :BACKUPEXTERNAL
        if not ERRORLEVEL 0 goto :EXIT_ENCRYPTDECRYPT
    )

    Rem save masks of the files that must be processed.
    set masks=%include%

:GETINCLUDEFILES_LOOP
    rem Split file masks (e.g. *.exe.config:web.config) into individual
    rem mask values and process them one at a time, e.g.:
    rem (1) *.exe.config
    rem (2) web.config

    rem Split string by colon (:) delimeters.
    rem Assign the first token to %%A, the rest to %%B.
    for /f "tokens=1* delims=:" %%A in ("%masks%") do (
        rem Copy tokens to named variables.
        set mask=%%A
        set masks=%%B
    )

    call :LOGMESSAGE Processing '%dir%%mask%'.

    rem Check if the mask string contains a wild card character.
    rem If it does, we'll use the FOR loop to iterate through files;
    rem otherwise, we'll just process the single file.
    call :HASWILDCARD "%mask%"
    if "%ret%"=="1" goto :PROCESSINCLUDEWILDCARD

    rem Check if the file exists in the folder.
    if exist "%dir%%mask%" (
        rem Do not print file, since we already did.

        rem Process configuration section.
        call :PROCESSCONFIG "%dir%%mask%"
        if not ERRORLEVEL 0 goto :EXIT_ENCRYPTDECRYPT
    ) else (
        call :LOGMESSAGE File '%dir%%mask%' does not exist.
    )
    goto :GETINCLUDEFILES_NEXT

:PROCESSINCLUDEWILDCARD
    rem Process files matching the search mask.
    for %%I in (%dir%%mask%) do (
        call :LOGMESSAGE Processing '%%I'.

        rem Process configuration section.
        call :PROCESSCONFIG "%%I"
        if not ERRORLEVEL 0 goto :EXIT_ENCRYPTDECRYPT
    )

:GETINCLUDEFILES_NEXT
    if not ERRORLEVEL 0 goto :EOF
    if defined masks goto :GETINCLUDEFILES_LOOP

:EXIT_ENCRYPTDECRYPT
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Encrypts/decrypts a specified .config file.
rem
rem Arguments:
rem %1=path to the configuration file that will be encrypted/decrypted
rem
:PROCESSCONFIG
setlocal
if defined TRACE %TRACE% [proc %0 %*]

    set configfile=%~n1
    set configext=%~x1

    rem Check if the file is in the exclude list.
    call :MUSTEXCLUDE %1
    set skipfile=%ret%

    if "%skipfile%"=="1" (
        call :LOGMESSAGE Skipping '%configfile%%configext%'.
    ) else (
        rem Back up the file if needed.
        if "%mustbackup%"=="1" call :BACKUP %1
        if not ERRORLEVEL 0 goto :EOF

        rem Check if the file is web.config or app.exe.config.
        if /I "%configfile%%configext%"=="web.config" (
            call :PROCESSWEBCONFIG %1
        ) else (
            call :PROCESSAPPCONFIG %1
        )
    )

endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Encrypts/decrypts an app.config file.
rem
rem Arguments:
rem %1=path to the app.config file that will be encrypted/decrypted
rem
:PROCESSAPPCONFIG
setlocal
if defined TRACE %TRACE% [proc %0 %*]

    set configdir=%~dp1
    set webconfig=%configdir%web.config
    set appconfig=%~f1
    set appconfigname=%~n1
    set appconfigext=%~x1

    call :GETTIMESTAMP
    set webconfigbak=%webconfig%.%ret%
    set webconfigbakname=web.config.%ret%

    if exist "%webconfig%" (
        call :LOGMESSAGE Renaming '%webconfig%' to '%webconfigbakname%'.

        attrib -R "%webconfig%"
        rename "%webconfig%" "%webconfigbakname%"
        if not ERRORLEVEL 0 (
            call :SETEXITCODE %ERROR_FILE_RENAME%
            goto :EXIT_PROCESSAPPCONFIG
        )
    )

    call :LOGMESSAGE Renaming '%appconfig%' to 'web.config'.
    attrib -R "%appconfig%"
    rename "%appconfig%" web.config

    if not ERRORLEVEL 0 (
        if exist "%webconfigbak%" (
            call :LOGMESSAGE Renaming '%webconfigbak%' back to 'web.config'.
            rename "%webconfigbak%" web.config

            if not ERRORLEVEL 0 (
                call :LOGERROR Please restore 'web.config' from '%webconfigbakname%' manually.
            )
        )

        call :SETEXITCODE %ERROR_FILE_RENAME%
        goto :EXIT_PROCESSAPPCONFIG
    )

    call :PROCESSWEBCONFIG "%webconfig%"

    call :LOGMESSAGE Renaming '%webconfig%' to '%appconfigname%%appconfigext%'.
    rename "%webconfig%" "%appconfigname%%appconfigext%"
    if not ERRORLEVEL 0 (
        call :LOGERROR Please restore '%appconfig%' from 'web.config' manually.

        if exist "%webconfigbak%" (
            call :LOGERROR Please restore '%webconfig%' from '%webconfigbakname%' manually.
        )

        goto :EXIT_PROCESSAPPCONFIG
    )

    if exist "%webconfigbak%" (
        call :LOGMESSAGE Restoring '%webconfig%' from '%webconfigbakname%'.
        rename "%webconfigbak%" web.config

        if not ERRORLEVEL 0 (
            call :LOGERROR Please restore '%webconfig%' from '%webconfigbakname%' manually.
        )
    )
:EXIT_PROCESSAPPCONFIG
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Processes web.config file.
rem
:PROCESSWEBCONFIG
setlocal
if defined TRACE %TRACE% [proc %0 %*]

    call :NORMALIZEFOLDER "%~dp1"
    set configdir=%ret%

    attrib -R %1

    if "%OPERATION%"=="decrypt" (
        call :LOGMESSAGE Decrypting configuration section '%section%'.
        if "%quiet%"=="1" (
            "%aspnet_regiis%" -pdf "%section%" "%configdir%" 1>nul
        ) else (
            "%aspnet_regiis%" -pdf "%section%" "%configdir%"
        )
    ) else (
        if "%section%"=="" (
            call :HELP
        ) else (
            if "%provider%"=="" (
                call :LOGMESSAGE Encrypting configuration section '%section%' using default provider.
                if "%quiet%"=="1" (
                    "%aspnet_regiis%" -pef "%section%" "%configdir%" 1>nul
                ) else (
                    "%aspnet_regiis%" -pef "%section%" "%configdir%"
                )
            ) else (
                call :LOGMESSAGE Encrypting configuration section '%section%' using provider '%provider%'.
                if "%quiet%"=="1" (
                    "%aspnet_regiis%" -pef "%section%" "%configdir%" -prov "%provider%" 1>nul
                ) else (
                    "%aspnet_regiis%" -pef "%section%" "%configdir%" -prov "%provider%"
                )
            )
        )
    )

    if not ERRORLEVEL 0 call :SETEXITCODE %ERROR_ASPNET_REGIIS%
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Creates/deletes an RSA key container.
rem
:CREATEDELETE
setlocal
if defined TRACE %TRACE% [proc %0 %*]

    if "%container%"=="" (
        call :LOGERROR Missing name of the RSA key container.
        call :LOGERROR Use the '/container' switch.
        call :SETEXITCODE %ERROR_MISSING_REQUIRED_PARAM%
        goto :EXIT_BACKUPEXTERNAL
    )

    if /I "%operation%"=="create" (
        call :CREATE
    ) else (
        call :DELETE
    )
    if not ERRORLEVEL 0 call :SETEXITCODE %ERROR_ASPNET_REGIIS%
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Creates an RSA key container.
rem
:CREATE
setlocal
if defined TRACE %TRACE% [proc %0 %*]

    if "%noexport%"=="1" (
        set exp=
    ) else (
        set exp=-exp
    )

    call :LOGMESSAGE Creating RSA key container '%container%'.
    if "%quiet%"=="1" (
        "%aspnet_regiis%" -pc "%container%" %exp% 1>nul
    ) else (
        "%aspnet_regiis%" -pc "%container%" %exp%
    )
    if not ERRORLEVEL 0 call :SETEXITCODE %ERROR_ASPNET_REGIIS%
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Deletes an RSA key container.
rem
:DELETE
setlocal
if defined TRACE %TRACE% [proc %0 %*]

    call :LOGMESSAGE Deleting RSA key container '%container%'.

    if "%quiet%"=="1" (
        "%aspnet_regiis%" -pz "%container%" 1>nul
    ) else (
        "%aspnet_regiis%" -pz "%container%"
    )
    if not ERRORLEVEL 0 call :SETEXITCODE %ERROR_ASPNET_REGIIS%
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Exports/imports RSA keys to/from a file.
rem
:EXPORTIMPORT
setlocal
if defined TRACE %TRACE% [proc %0 %*]

    if "%container%"=="" (
        call :LOGERROR Missing name of the RSA key container.
        call :LOGERROR Use the '/container' switch.
        call :SETEXITCODE %ERROR_MISSING_REQUIRED_PARAM%
        goto :EXIT_BACKUPEXTERNAL
    )

    if /I "%operation%"=="export" (
        call :EXPORT
    ) else (
        call :IMPORT
    )
    if not ERRORLEVEL 0 call :SETEXITCODE %ERROR_ASPNET_REGIIS%
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Exports RSA keys to a file.
rem
:EXPORT
setlocal
if defined TRACE %TRACE% [proc %0 %*]

    call :LOGMESSAGE Exporting RSA keys from '%container%' into '%key%'.

    if "%quiet%"=="1" (
        "%aspnet_regiis%" -px "%container%" "%key%" -pri 1>nul
    ) else (
        "%aspnet_regiis%" -px "%container%" "%key%" -pri
    )
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Imports RSA key from a file.
rem
:IMPORT
setlocal
if defined TRACE %TRACE% [proc %0 %*]

    call :LOGMESSAGE Importing RSA keys from '%key%' into '%container%'.

    if "%quiet%"=="1" (
        "%aspnet_regiis%" -pi "%container%" "%key%" 1>nul
    ) else (
        "%aspnet_regiis%" -pi "%container%" "%key%"
    )
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Grants/revokes access permission to/from the RSA key container
rem for a user/group.
rem
:GRANTREVOKE
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    set names=%account%

    if "%names%"=="" (
        call :LOGERROR Missing name of user or group account.
        call :LOGERROR Use the '/account' switch.
        call :SETEXITCODE %ERROR_MISSING_REQUIRED_PARAM%
        goto :EXIT_GRANTREVOKE
    )

    if "%container%"=="" (

        call :LOGERROR Missing name of the RSA key container.
        call :LOGERROR Use the '/container' switch.
        call :SETEXITCODE %ERROR_MISSING_REQUIRED_PARAM%
        goto :EXIT_GRANTREVOKE
    )

:GETUSERNAMES_LOOP
    rem Split names (e.g. domain\userX:domain\GroupY) into individual
    rem mask values and process them one at a time, e.g.:
    rem (1) domain\userX
    rem (2) domain\groupY

    rem Split string by colon (:) delimeters.
    rem Assign the first token to %%A, the rest to %%B.
    for /f "tokens=1* delims=:" %%A in ("%names%") do (
        rem Copy tokens to named variables.
        set name=%%A
        set names=%%B
    )

    if /I "%operation%"=="grant" (
        call :GRANT "%name%"
    ) else (
        call :REVOKE "%name%"
    )

    if not ERRORLEVEL 0 goto :EXIT_GRANTREVOKE
    if defined names goto :GETUSERNAMES_LOOP

:EXIT_GRANTREVOKE
    if not ERRORLEVEL 0 call :SETEXITCODE %ERROR_ASPNET_REGIIS%
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Grants access permission to the RSA key container for a user/group.
rem
rem Parameters:
rem %1=user or group account name
rem
:GRANT
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    set name=%~1

    call :LOGMESSAGE Granting '%container%' container access to '%name%'.

    if "%quiet%"=="1" (
        "%aspnet_regiis%" -pa "%container%" "%name%" 1>nul
    ) else (
        "%aspnet_regiis%" -pa "%container%" "%name%"
    )
    if not ERRORLEVEL 0 call :SETEXITCODE %ERROR_ASPNET_REGIIS%
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Removes access permission to the RSA key container from a user/group.
rem
rem Parameters:
rem %1=user or group account name
rem
:REVOKE
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    set name=%~1

    call :LOGMESSAGE Revoking '%container%' container access from '%name%'.

    if "%quiet%"=="1" (
        "%aspnet_regiis%" -pr "%container%" "%name%" 1>nul
    ) else (
        "%aspnet_regiis%" -pr "%container%" "%name%"
    )
    if not ERRORLEVEL 0 call :SETEXITCODE %ERROR_ASPNET_REGIIS%
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Prints runtime parameters for testing purposes.
rem
:PRINT
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    echo AspNetRegIis = %aspnet_regiis%
    echo Include      = %include%
    echo Exclude      = %exclude%
    echo Dir          = %dir%
    echo Container    = %container%
    echo Provider     = %provider%
    echo Section      = %section%
    echo Key          = %key%
    echo Account      = %account%
    echo Backup       = %backup%
    echo Bak          = %bak%
    echo Quiet        = %quiet%
    echo Nologo       = %nologo%
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Displays version information.
rem
:VERSION
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    if "%quiet%"=="1" goto :EXIT_VERSION
    if "%nologo%"=="1" goto :EXIT_VERSION

	if "%SCRIPT_AUTHOR%"=="" (
		echo %SCRIPTNAME% v%SCRIPT_VERSION%
	) else (
		echo %SCRIPTNAME% v%SCRIPT_VERSION% by %SCRIPT_AUTHOR%
	)

    if not "%SCRIPT_COMPANY%"=="" echo Copyright (C) %SCRIPT_YEAR% %SCRIPT_COMPANY%

    echo.

:EXIT_VERSION
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Displays usage information.
rem
:HELP
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    echo ______________________________________________________________________
    echo.
    echo  DESCRIPTION
    echo ______________________________________________________________________
    echo.
    echo %SCRIPTNAME%%SCRIPTEXT% is a command-line tool (batch script) that uses
    echo the .NET Framework's aspnet_regiis.exe utility to:
    echo.
    echo - encrypt or decrypt sensitive data in the application configuration
    echo   (.config) files;
    echo - create or delete RSA key containers;
    echo - grant or revoke access to the RSA key containers for userss or
    echo   groups;
    echo - export or import RSA keys to or from files.
    echo ______________________________________________________________________
    echo.
    echo  SYNTAX
    echo ______________________________________________________________________
    echo.
    echo %SCRIPTNAME% [OPERATION] [SWITCHES]
    echo ______________________________________________________________________
    echo.
    echo  OPERATION
    echo ______________________________________________________________________
    echo.
    echo encrypt
    echo   Encrypt a section in a .config file (default).
    echo.
    echo decrypt
    echo   Decrypt a section in a .config file.
    echo.
    echo create
    echo   Create an RSA key container.
    echo.
    echo delete
    echo   Delete an RSA key container.
    echo.
    echo export
    echo   Export RSA keys to a file.
    echo.
    echo import
    echo   Import RSA keys from a file.
    echo.
    echo grant
    echo   Grant access to RSA key container to user/group.
    echo.
    echo revoke
    echo   Remove access to RSA key container from user/group.
    echo.
    echo print
    echo   Show runtime parameters (for debugging purposes).
    echo.
    echo license
    echo   Display license information.
    echo.
    echo version
    echo   Print version information.
    echo.
    echo help
    echo   Print this help information.
    echo ______________________________________________________________________
    echo.
    echo  SWITCHES
    echo ______________________________________________________________________
    echo.
    echo /section:value
    echo   Name of configuration section in .config file(s) to be encrypted
    echo   or decrypted. Default value: 'secureAppSettings'. Required for
    echo   operations: encrypt, decrypt.
    echo.
    echo /include:value
    echo   Name(s) or mask(s) used identify the configuration file(s) to be
    echo   processed. Separate multiple values by colons (:). Name(s) of the
    echo   file(s) will be appended to the folder (see description of the
    echo   '/dir' switch) to build the full path(s). If not specified, all
    echo   files with extension '.exe.config' found in the folder identified
    echo   by the '/dir' switch will be processed along with the 'web.config'
    echo   file. Default value: *.exe.config:web.config. Optional for
    echo   operations: encrypt, decrypt.
    echo.
    echo /exclude:value
    echo   Name(s) or mask(s) used identify the configuration file(s) to be
    echo   excluded from processing. The value of this switch uses the same
    echo   format as the value of the '/include' switch. Optional for
    echo   operations: encrypt, decrypt.
    echo.
    echo /dir:value
    echo   Path to the folder holding configuration file(s) to be processed.
    echo   If not specified, the folder hosting this batch script will be used.
    echo   Optional for operations: encrypt, decrypt, export, import.
    echo.
    echo /container:value
    echo   Name of the RSA key container. Required for operations: create,
    echo   delete, export, import, grant, revoke.
    echo.
    echo /provider:value
    echo   Name of the RSA cryptographic provider defined in the .config
    echo   file's 'configProtectedData\providers' section. If not specified,
    echo   the default provider set in the 'configProtectedData' section's
    echo   'defaultpProvider' attribute will be used. Optional for operations:
    echo   encrypt.
    echo.
    echo /key:value
    echo   Name or path to the export/import file holding the RSA key. If the
    echo   key is missing, the name will be generated from the name of the RSA
    echo   key container specified via the '/container' switch (it will have
    echo   the '.xml' extension). If the key name contains a folder information
    echo   -- detected by the presense of the backslash (\) character -- it
    echo   will be left as is; otherwise, the name of the folder identified by
    echo   the '/dir' switch or the default folder name will be added at the
    echo   beginning of the key name to generate the absolute path. Optional
    echo   for operations: export, import.
    echo.
    echo /account:value
    echo   Name of user or group account that will have access to the RSA key
    echo   container granted/revoked. To specify multiple account names,
    echo   separate them by colons (:), e.g.
    echo   /account:"NT AUTHORITY\Network Service:NT AUTHORITY\Local Service".
    echo   Default value: NT AUTHORITY\NETWORK SERVICE. Required for operations:
    echo   grant, revoke.
    echo.
    echo /bakup:[value]
    echo   When this switch is set, a backup of the configuration file(s) to
    echo   be processed will be created before running the
    echo   encryption/decryption operation. If the switch does not have a
    echo   value, only configuration file(s) will be processed; otherwise, in
    echo   addition to the configuration file(s) files identified by the switch
    echo   will be processed as well (this could be helpful when configuration
    echo   files reference sections holding sensitive settings from external
    echo   files). The value of this switch uses the same format as the value
    echo   of the '/include' switch. If a generated backup file name points to
    echo   an existing file, the file will be overwritten. Optional for
    echo   operations: export, import.
    echo.
    echo /bak:value
    echo   File extension (such as '.txt') that will be used for naming backup
    echo   files. If this switch is set, it will turn the 'backup' switch on as
    echo   well. Default value: .bak. Optional for operations: export, import.
    echo.
    echo /print
    echo   When this switch is set, the script will print important runtime
    echo   parameters.
    echo.
    echo /quiet
    echo   When this switch is set, informational messages non-essential for
    echo   the intended operaytion will not be displayed. Error messages may
    echo   be displayed regardless.
    echo.
    echo /nologo
    echo   When this switch is set, the script version and copyright info will
	echo   not be displayed.
    echo ______________________________________________________________________
    echo.
    echo  EXAMPLES
    echo ______________________________________________________________________
    echo.
    echo %SCRIPTNAME% encrypt /section:myAppSettings /provider:myRsaProv
    echo.
    echo   Encrypts section 'myAppSettings' in all .exe.config and web.config
    echo   files found in the same directory from which the script runs using
    echo   the provider named 'myRsaProv'.
    echo.
    echo %SCRIPTNAME% encrypt /section:myAppSettings
    echo     /dir:"C:\Program Files\MyApp" /include:MyApp.exe.config
    echo.
    echo   Encrypts section 'myAppSettings' in the MyApp.exe.config file
    echo   located in the 'C:\Program Files\MyApp' folderusing the default
    echo   provider (per configuration file).
    echo.
    echo %SCRIPTNAME% decrypt /section:myAppSettings /dir:.
    echo     /backup:"db.config:secure*.config"
    echo.
    echo   Decrypts section 'myAppSettings' in all .exe.config and web.config
    echo   files found in the current directory using a default provider.
    echo   Before performing the operation, it will copy each affected file to
    echo   a backup file with the .bak extension. It will also back up external
    echo   files (supposedly referenced by the configuration files):
    echo   'db.config' and all files matching the 'secure*.config' mask.
    echo.
    echo %SCRIPTNAME% create /container:myRsaKey
    echo.
    echo   Creates an RSA key container named 'myRsaKey'. The key will be
    echo   exportable, so it can be imported on other machines to allow
    echo   decryption of the same encrypted settings.
    echo.
    echo %SCRIPTNAME% delete /container:myRsaKey
    echo.
    echo   Deletes the RSA key container named 'myRsaKey'.
    echo.
    echo %SCRIPTNAME% grant /container:myRsaKey /account:.\MyAppPoolUsers
    echo.
    echo   Grants access to the RSA key names 'myRsaKey' to a local group
    echo   called 'myAppPoolUsers'.
    echo.
    echo %SCRIPTNAME% revoke /container:myRsaKey /account:.\MyAppPoolUsers
    echo.
    echo   Revokes access to the RSA key names 'myRsaKey' from a local group
    echo   called 'myAppPoolUsers'.
    echo.
    echo %SCRIPTNAME% export /container:myRsaKey /key:myRsaKey.txt
    echo.
    echo   Exports RSA key from container named 'myRsaKey' to the
    echo   'myRsaKey.txt' file in the current directory.
    echo.
    echo %SCRIPTNAME% import /container:myRsaKey /key:myRsaKey.txt
    echo.
    echo   Imports RSA key from the 'myRsaKey.txt' file in the current
    echo   directory into a new container named 'myRsaKey'.
    echo ______________________________________________________________________
    echo.
    echo  REMARKS
    echo ______________________________________________________________________
    echo.
    echo Use the following command to display this help info one echo screen at
    echo a time:
    echo.
    echo %SCRIPTNAME% /? ^| more
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Displays license information.
rem
:HELP
:LICENSE
setlocal
    echo Applies cryptographic functions to the .NET application
    echo configuration files and RSA keys using the .NET Framework's
    echo aspnet_regiis.exe tool.
    echo.
    echo MIT License
    echo.
    echo Permission is hereby granted, free of charge, to any person
    echo obtaining a copy of this software and associated documentation
    echo files (the "Software"), to deal in the Software without restriction,
    echo including without limitation the rights to use, copy, modify, merge,
    echo publish, distribute, sublicense, and/or sell copies of the Software,
    echo and to permit persons to whom the Software is furnished to do so,
    echo subject to the following conditions:
    echo.
    echo The above copyright notice and this permission notice shall be
    echo included in all copies or substantial portions of the Software.
    echo.
    echo THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    echo EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    echo MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    echo IN NO EVENT SHALL THEAUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    echo CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    echo TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    echo SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem HELPER METHODS
rem ------------------------------------------------------------------

rem ------------------------------------------------------------------
rem Sets path to aspnet_regiss.exe.
rem
rem Returbns:
rem %val%=path to aspnet_regiis.exe
:GETASPNETREGIIS
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    set aspnetregiis=aspnet_regiis.exe

    rem .NET 4.0 (64-bit)
    set aspnetregiispath=%windir%\Microsoft.NET\Framework64\v4.0.30319\%aspnetregiis%
    if exist "%aspnetregiispath%" goto :EXIT_GETASPNETREGIIS

    rem .NET 4.0 (32-bit)
    set aspnetregiispath=%windir%\Microsoft.NET\Framework\v4.0.30319\%aspnetregiis%
    if exist "%aspnetregiispath%" goto :EXIT_GETASPNETREGIIS

    rem .NET 2.0, 3.0, 3.5 (64-bit)
    set aspnetregiispath=%windir%\Microsoft.NET\Framework64\v2.0.50727\%aspnetregiis%
    if exist "%aspnetregiispath%" goto :EXIT_GETASPNETREGIIS

    rem .NET 2.0, 3.0, 3.5 (32-bit)
    set aspnetregiispath=%windir%\Microsoft.NET\Framework\v2.0.50727\%aspnetregiis%
    if exist "%aspnetregiispath%" goto :EXIT_GETASPNETREGIIS

    rem .NET 1.1
    set aspnetregiispath=%windir%\Microsoft.NET\Framework\v1.1.4322\%aspnetregiis%
    if exist "%aspnetregiispath%" goto :EXIT_GETASPNETREGIIS

    rem .NET 1.0
    set aspnetregiispath=%windir%\.NET\Framework\v1.0.3705\%aspnetregiis%
    if exist "%aspnetregiispath%" goto :EXIT_GETASPNETREGIIS

    set aspnetregiispath=

:EXIT_GETASPNETREGIIS
    set ret=%aspnetregiispath%
endlocal & set ret=%ret%
goto :EOF

rem -----------------------------------------------------------------
rem Generate current timestamp in the format:
rem
rem Returns:
rem %val%=timestamp
rem
:GETTIMESTAMP
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    for /f "usebackq tokens=1,2 delims==" %%I in (`wmic os get LocalDateTime /value 2^>NUL`) do (
        if '.%%I.'=='.LocalDateTime.' set ldt=%%J
    )

    set ret=%ldt:~0,4%%ldt:~4,2%%ldt:~6,2%%ldt:~8,2%%ldt:~10,2%%ldt:~12,2%%ldt:~15,3%
endlocal & set ret=%ret%
goto :EOF

rem -----------------------------------------------------------------
rem Remove quotes from both ends of the string.
rem
rem Arguments:
rem %1=original string that may contain quotes on both ends
rem
rem Returns:
rem %ret%=string without quotes on both ends
rem
:REMOVEQUOTES
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    set ret=%~1
endlocal & set ret=%ret%
goto :EOF

rem -----------------------------------------------------------------
rem Remove trailing period and backslash from the string.
rem
rem Arguments:
rem %1=original string that may contain period and/or backslash
rem    at the end
rem
rem Returns:
rem %ret%=string without trailing period or backslash
rem
:NORMALIZEFOLDER
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    set ret=%~1
    if "%ret:~-1%"=="." set ret=%ret:~0,-1%
    if "%ret:~-1%"=="\" set ret=%ret:~0,-1%
endlocal & set ret=%ret%
goto :EOF

rem -----------------------------------------------------------------
rem Backs up a configuration file.
rem
rem Arguments:
rem %1=path to the configuration file
rem
:BACKUP
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    if "%bak%"=="" goto :EXIT_BACKUP

    set configpath=%~f1
    set configname=%~n1
    set configext=%~x1
    set configpathbak=%configpath%%bak%

    if not "%bak%"=="" (
        call :LOGMESSAGE Copying '%configpath%' to '%configname%%configext%%bak%'.
        copy /y "%configpath%" "%configpathbak%" 1>nul
    )

    if not ERRORLEVEL 0 (
        call :SETEXITCODE %ERROR_FILE_BACKUP%
    )
:EXIT_BACKUP
endlocal
goto :EOF

rem -----------------------------------------------------------------
rem Backs up external .config file(s) specified via '/backup' switch.
rem
:BACKUPEXTERNAL
setlocal
if defined TRACE %TRACE% [proc %0 %*]

    Rem save masks of the files that must be processed.
    set masks=%backup%

    call :LOGMESSAGE Backing up external configuration files.

:GETBACKUPFILES_LOOP
    rem Split file masks (e.g. *.secure.config:my.config) into individual
    rem mask values and process them one at a time, e.g.:
    rem (1) *.secure.config
    rem (2) my.config

    rem Split string by colon (:) delimeters.
    rem Assign the first token to %%A, the rest to %%B.
    for /f "tokens=1* delims=:" %%A in ("%masks%") do (
        rem Copy tokens to named variables.
        set mask=%%A
        set masks=%%B
    )

    call :LOGMESSAGE Backing up '%dir%%mask%'.

    rem Check if the mask string contains a wild card character.
    rem If it does, we'll use the FOR loop to iterate through files;
    rem otherwise, we'll just process the single file.
    call :HASWILDCARD "%mask%"
    if "%ret%"=="1" goto :PROCESSBACKUPWILDCARD

    rem Check if the file exists in the folder.
    if exist "%dir%%mask%" (
        rem Do not print file, since we already did.

        rem Process configuration section.
        call :BACKUP "%dir%%mask%"
        if not ERRORLEVEL 0 goto :EXIT_BACKUPEXTERNAL
    ) else (
        call :LOGMESSAGE External file '%dir%%mask%' does not exist.
    )
    goto :GETBACKUPFILES_NEXT

:PROCESSBACKUPWILDCARD
    rem Back up files matching the search mask.
    for %%I in (%dir%%mask%) do (
        call :BACKUP "%dir%%%I"
        if not ERRORLEVEL 0 goto :EXIT_BACKUPEXTERNAL
    )

:GETBACKUPFILES_NEXT
    if not ERRORLEVEL 0 goto :EXIT_BACKUPEXTERNAL
    if defined masks goto :GETBACKUPFILES_LOOP

:EXIT_BACKUPEXTERNAL
endlocal
goto :EOF

rem -----------------------------------------------------------------
rem Checks if a string contains wild card characters (* or ?).
rem
rem Arguments:
rem %1=string
rem
rem Returns:
rem %ret%=1 (if a wildcharacter is found); 0 otherwise
rem
:HASWILDCARD
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    set string=%~1

    for /f "tokens=1* delims=*?" %%A in ("%string%") do (
        set token=%%A
    )

    if not {%token%}=={%string%} (
        set ret=1
    ) else (
        set ret=0
    )
endlocal & set ret=%ret%
goto :EOF

rem -----------------------------------------------------------------
rem Checks if a string contains a backslash character (\).
rem
rem Arguments:
rem %1=string
rem
rem Returns:
rem %ret%=1 (if backslash is found); 0 otherwise
rem
:HASBACKSLASH
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    set string=%~1

    for /f "tokens=1* delims=\" %%A in ("%string%") do (
        set token=%%A
    )

    if not {%token%}=={%string%} (
        set ret=1
    ) else (
        set ret=0
    )
endlocal & set ret=%ret%
goto :EOF

rem -----------------------------------------------------------------
rem Checks if the files is in the exclusion list.
rem
rem Arguments:
rem %1=file to check
rem
rem Returns:
rem %ret%=1 (if file must be excluded); 0 otherwise
rem
:MUSTEXCLUDE
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    if "%exclude%"=="" (
        set ret=0
        goto :EXIT_MUSTEXCLUDE
    )

    set name=%~n1
    set ext=%~x1
    set ret=0

    Rem save masks of the files that must be processed.
    set masks=%exclude%

:GETEXCLUDEDFILES_LOOP
    rem Split file masks (e.g. *.prod.exe.config:dummy.config) into individual
    rem mask values and process them one at a time, e.g.:
    rem (1) *.prod.exe.config
    rem (2) dummy.config

    rem Split string by colon (:) delimeters.
    rem Assign the first token to %%A, the rest to %%B.
    for /f "tokens=1* delims=:" %%A in ("%masks%") do (
        rem Copy tokens to named variables.
        set mask=%%A
        set masks=%%B
    )

    rem Check if the mask string contains a wild card character.
    rem If it does, we'll use the FOR loop to iterate through files;
    rem otherwise, we'll just process the single file.
    call :HASWILDCARD "%mask%"
    if "%ret%"=="1" goto :PROCESSEXCLUDEWILDCARD

    rem Compare files.
    if defined TRACE %TRACE% [proc %0: Checking exclusion: %mask%]
    call :ISFILEMATCH %1 "%dir%%mask%"
    goto :GETEXCLUDEFILES_NEXT

:PROCESSEXCLUDEWILDCARD
    rem Process files matching the search mask.

    for %%I in (%dir%%mask%) do (
        if defined TRACE %TRACE% [proc %0: Checking exclusion: %%I]
        rem Compare files.
        call :ISFILEMATCH %1 "%%I"

        if "%ret%"=="1" goto :GETEXCLUDEFILES_NEXT
    )

:GETEXCLUDEFILES_NEXT
    if "%ret%"=="1" goto :EXIT_MUSTEXCLUDE
    if defined masks goto :GETEXCLUDEDFILES_LOOP

:EXIT_MUSTEXCLUDE
    if "%ret%"=="1" (
        call :LOGMESSAGE File '%name%%ext%' matches exclusion '%mask%'.
    )
endlocal & set ret=%ret%
goto :EOF

rem -----------------------------------------------------------------
rem Checks if filenames of two files are the same.
rem
rem Arguments:
rem %1=file path #1
rem %2=file path #2
rem
rem Returns:
rem %ret%=1 (if names match); 0 otherwise
rem
:ISFILEMATCH
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    set file1=%~f1
    set file2=%~f2

    if /I "%file1%"=="%file2%" (
        set ret=1
    ) else (
        set ret=0
    )
endlocal & set ret=%ret%
goto :EOF

rem ------------------------------------------------------------------
rem Exits the script with the specified exit code.
rem
rem Arguments:
rem %1=exit code
:SETEXITCODE
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    exit /b %1%
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Writes message to console (STDOUT).
rem
rem Arguments:
rem %*=message
:LOGMESSAGE
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    if "%quiet%"=="" echo %*
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem Writes message to STDERR.
rem
rem Arguments:
rem %*=message
:LOGERROR
setlocal
if defined TRACE %TRACE% [proc %0 %*]
    echo %* 1>&2
endlocal
goto :EOF

rem ------------------------------------------------------------------
rem General-purpose utility functions from the _mtplib.bat library.
rem

rem ------------------------------------------------------------------
rem VARDEL procedure
rem Delete multiple variables by prefix
rem
rem Arguments:
rem %1=variable name prefix
rem
:VARDEL
if defined TRACE %TRACE% [proc %0 %*]
    for /f "tokens=1 delims==" %%I in ('set %1 2^>nul') do set %%I=
goto :EOF

rem ------------------------------------------------------------------
rem PARSECMDLINE procedure
rem Parse a command line into switches and args
rem
rem Arguments:
rem CMDLINE=command text to parse
rem %1=0 for new parse (def) or 1 to append to existing
rem
rem Returns:
rem CMDARG_n=arguments, CMDSW_n=switches
rem CMDARGCOUNT=arg count, CMDSWCOUNT=switch count
rem RET=total number of args processed
rem
:PARSECMDLINE
if defined TRACE %TRACE% [proc %0 %*]
    if not {%1}=={1} (
        (call :VARDEL CMDARG_)
        (call :VARDEL CMDSW_)
        (set /a CMDARGCOUNT=0)
        (set /a CMDSWCOUNT=0)
    )
    set /a RET=0
    call :PARSECMDLINE1 %CMDLINE%
    set _MTPLIB_T1=
goto :EOF

:PARSECMDLINE1
if {%1}=={} goto :EOF
set _MTPLIB_T1=%1
set _MTPLIB_T1=%_MTPLIB_T1:"=%
set /a RET+=1
shift /1
if "%_MTPLIB_T1:~0,1%"=="/" goto :PARSECMDLINESW
if "%_MTPLIB_T1:~0,1%"=="-" goto :PARSECMDLINESW
set /a CMDARGCOUNT+=1
set CMDARG_%CMDARGCOUNT%=%_MTPLIB_T1%
goto :PARSECMDLINE1

:PARSECMDLINESW
set /a CMDSWCOUNT+=1
set CMDSW_%CMDSWCOUNT%=%_MTPLIB_T1%
goto :PARSECMDLINE1
goto :EOF

rem ------------------------------------------------------------------
rem GETARG procedure
rem Get a parsed argument by index
rem
rem Arguments:
rem %1=argument index (1st arg has index 1)
rem
rem Returns:
rem RET=argument text or empty if no argument
rem
:GETARG
if defined TRACE %TRACE% [proc %0 %*]
    set RET=
    if %1 GTR %CMDARGCOUNT% goto :EOF
    if %1 EQU 0 goto :EOF
    if not defined CMDARG_%1 goto :EOF
    set RET=%%CMDARG_%1%%
    call :RESOLVE
goto :EOF

rem ------------------------------------------------------------------
rem GETSWITCH procedure
rem Get a switch argument by index
rem
rem Arguments:
rem %1=switch index (1st switch has index 1)
rem
rem Returns:
rem RET=switch text or empty if none
rem RETV=switch value (after colon char) or empty
rem
:GETSWITCH
if defined TRACE %TRACE% [proc %0 %*]
    (set RET=) & (set RETV=)
    if %1 GTR %CMDSWCOUNT% goto :EOF
    if %1 EQU 0 goto :EOF
    if not defined CMDSW_%1 goto :EOF
    set RET=%%CMDSW_%1%%
    call :RESOLVE
    for /f "tokens=1* delims=:" %%I in ("%RET%") do (set RET=%%I) & (set RETV=%%J)
goto :EOF

rem ------------------------------------------------------------------
rem FINDSWITCH procedure
rem Finds the index of the named switch
rem
rem Arguments:
rem %1=switch name
rem %2=search start index (def: 1)
rem
rem Returns:
rem RET=index (0 if not found)
rem RETV=switch value (text after colon)
rem
:FINDSWITCH
if defined TRACE %TRACE% [proc %0 %*]
    if {%2}=={} (set /a _MTPLIB_T4=1) else (set /a _MTPLIB_T4=%2)

    :FINDSWITCHLOOP
    call :GETSWITCH %_MTPLIB_T4%
    if "%RET%"=="" (set RET=0) & (goto :FINDSWITCHEND)
    if /i "%RET%"=="%1" (set RET=%_MTPLIB_T4%) & (goto :FINDSWITCHEND)
    set /a _MTPLIB_T4+=1
    goto :FINDSWITCHLOOP

    :FINDSWITCHEND
    set _MTPLIB_T4=
goto :EOF

rem ------------------------------------------------------------------
rem RESOLVE procedure
rem Fully resolve all indirect variable references in RET variable
rem
rem Arguments:
rem RET=value to resolve
rem
rem Returns:
rem RET=as passed in, with references resolved
rem
:RESOLVE
if defined TRACE %TRACE% [proc %0 %*]
    :RESOLVELOOP
    if "%RET%"=="" goto :EOF
    set RET1=%RET%
    for /f "tokens=*" %%I in ('echo %RET%') do set RET=%%I
    if not "%RET%"=="%RET1%" goto :RESOLVELOOP
goto :EOF

rem These must be the FINAL LINES in the script
:DOSEXIT
echo This script requires Windows NT
rem ------------------------------------------------------------------
