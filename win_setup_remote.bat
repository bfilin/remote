echo off
set "filename=%~nx0"

IF "%~1" == "" GOTO ExitLabel

IF "%~2" == "" GOTO ExitLabel

set EXTERNAL_IP=%1

IF "%2%"=="basic" (GOTO Basic) ELSE ^
IF "%2%"=="serveraUP" (GOTO CheckServerA) ELSE ^
IF "%2%"=="serverbUP" (GOTO CheckServerB) ELSE ^
IF "%2%"=="stopall" (GOTO StopAll) ELSE ^
IF "%2%"=="status" (GOTO ShowStatus) ELSE ^
GOTO ExitLabel



:Basic
echo attempting to start bastion nested VM on %EXTERNAL_IP%
ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP% "rht-vmctl start bastion" || GOTO ExitBastion

echo attempting to start workstation nested VM on %EXTERNAL_IP%
ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP% "rht-vmctl start workstation" || GOTO ExitWorkstation

echo attempting to ssh into %EXTERNAL_IP% and port forward port 5902
ssh -C -i ./id_rha_foundation0 -L 5902:localhost:5902 kiosk@%EXTERNAL_IP% || GOTO Exit5902
EXIT /B 0
GOTO Done


:StartServerA
ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP%  "rht-vmctl start servera"
GOTO Done

:CheckServerA
echo attempting to start servera nested VM on %EXTERNAL_IP%
ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP% "source /usr/local/lib/rhttool.shlib && is_running bastion && is_running workstation && echo OK || echo NOK" > tmpval.txt
set /p r=<tmpval.txt
if "%r%" == "OK" (del tmpval.txt && GOTO StartServerA) ELSE (del tmpval.txt && echo Not possible, you need to run basic command first)
GOTO Done



:StartServerB
ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP%  "rht-vmctl start serverb"
GOTO Done

:CheckServerB
echo attempting to start serverb nested VM on %EXTERNAL_IP%
ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@%EXTERNAL_IP% "source /usr/local/lib/rhttool.shlib && is_running bastion && is_running workstation && echo OK || echo NOK" > tmpval.txt
set /p r=<tmpval.txt
if "%r%" == "OK" (del tmpval.txt && GOTO StartServerB) ELSE (del tmpval.txt && echo Not possible, you need to run basic command first)
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
echo Could not start workstation, are you sure you have provided the correct IP address and that VM is ON
GOTO Done

:ExitBastion
echo Could not start bastion, are you sure you have provided the correct IP address and that VM is ON
GOTO Done

:ExitServerA
echo Could not start servera, are you sure you have provided the correct IP address and that VM is ON
GOTO Done

:ExitServerB
echo Could not start serverb, are you sure you have provided the correct IP address and that VM is ON
GOTO Done

:ExitStopAll
echo Could not stop the nested VMs
GOTO Done

:Exit5902
echo Could not port forward
GOTO Done


:Done
EXIT /B 0