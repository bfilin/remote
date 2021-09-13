echo off
set "filename=%~nx0"

IF "%~1" == "" GOTO ExitLabel

IF "%~2" == "" GOTO ExitLabel

set EXTERNAL_IP=%1%
set "ok2go=NOK"


IF "%2%"=="basic" (GOTO Basic) ELSE ^
IF "%2%"=="serveraUP" (GOTO StartServerA) ELSE ^
IF "%2%"=="serverbUP" (GOTO StartServerB) ELSE ^
IF "%2%"=="stopall" (GOTO StopAll) ELSE ^
IF "%2%"=="vncport" (GOTO getVNCPort) ELSE ^
IF "%2%"=="status" (GOTO ShowStatus) ELSE ^
GOTO ExitLabel

:checkGoOn
ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP% "source /usr/local/lib/rhttool.shlib && is_running bastion" || GOTO ExitBastion
ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP% "source /usr/local/lib/rhttool.shlib && is_running workstation" || GOTO ExitWorkstation
set "ok2go=OK"
GOTO %ret%

:getVNCPort
if "%ok2go%" == "NOK" (set "ret=getVNCPort" && GOTO :checkGoOn) ELSE (echo 'OK Basion and Workstation are running')

ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP% "virsh -c 'qemu:///system' vncdisplay workstation" > tmpval.txt
set /p port=<tmpval.txt
set port=590%port::=%
echo vnc port is: %port%
set "ok2go=NOK"
GOTO Done


:Basic
echo attempting to start bastion nested VM on %EXTERNAL_IP%

ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP% "source /usr/local/lib/rhttool.shlib && is_running bastion && echo bastion is alrady running || rht-vmctl start bastion" || GOTO ExitBastion
echo --
echo attempting to start workstation nested VM on %EXTERNAL_IP%
ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP% "source /usr/local/lib/rhttool.shlib && is_running workstation && echo workstation is alrady running || rht-vmctl start workstation" || GOTO ExitWorkstation
echo --

call :getVNCPort
echo --

echo attempting to ssh into %EXTERNAL_IP% and port forward port %port%
ssh -C -i ./id_rha_foundation0 -L %port%:localhost:%port% kiosk@%EXTERNAL_IP% || GOTO ExitVNC
EXIT /B 0
GOTO Done


:StartServerA
if "%ok2go%" == "NOK" (set "ret=StartServerA" && GOTO :checkGoOn) ELSE (echo 'OK Basion and Workstation are running')
ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP%  "rht-vmctl start servera"
set "ok2go=NOK"
GOTO Done


:StartServerB
if "%ok2go%" == "NOK" (set "ret=StartServerB" && GOTO :checkGoOn) ELSE (echo 'OK Basion and Workstation are running')
ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP%  "rht-vmctl start serverb"
set "ok2go=NOK"
GOTO Done


:StopAll
echo attempting to stop all nested VMs on %EXTERNAL_IP%
ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP% "rht-vmctl stop all" || GOTO ExitStopAll
echo if you are done, also make sure to shutdown the VM instance in Google Cloud
GOTO Done


:ShowStatus
echo attempting to stop all nested VMs on %EXTERNAL_IP%
ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP% "source /usr/local/lib/rhttool.shlib && is_running bastion && echo bastion ONLINE || echo bastion OFFLINE"
ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP% "source /usr/local/lib/rhttool.shlib && is_running workstation && echo workstation ONLINE || echo workstation OFFLINE"
ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP% "source /usr/local/lib/rhttool.shlib && is_running servera && echo servera ONLINE || echo servera OFFLINE"
ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP% "source /usr/local/lib/rhttool.shlib && is_running serverb && echo serverb ONLINE || echo serverb OFFLINE"

GOTO Done


:ExitLabel
echo Usage: %filename% ^<EXTERNAL_IP^> command

echo where command is one of the following:
echo        basic             - will start bastion,workstation and do port forward for VNC
echo        serveraUP         - bring up servera nested VM
echo        serverbUP         - bring up serverb nested VM
echo        stopall           - stop all nested VMs
echo        status            - print status information about nested VMs
GOTO Done


:ExitWorkstation
echo workstation is not running, are you sure you have provided the correct IP address and that VM is ON
EXIT /B 1

:ExitBastion
echo bastion is not running, are you sure you have provided the correct IP address and that VM is ON
EXIT /B 1


:ExitServerA
echo Could not start servera, are you sure you have provided the correct IP address and that VM is ON
EXIT /B 1

:ExitServerB
echo Could not start serverb, are you sure you have provided the correct IP address and that VM is ON
EXIT /B 1

:ExitStopAll
echo Could not stop the nested VMs
GOTO Done

:ExitVNC
echo Could not port forward
GOTO Done


:Done
EXIT /B 0