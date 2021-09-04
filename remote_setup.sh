set -euo pipefail


function is_google_cloud_ok(){
  ssh -q -o StrictHostKeyChecking=no -o BatchMode=yes  -o ConnectTimeout=4 \
    -i id_rha_foundation0 kiosk@$EXTERNAL_IP exit
}

function start_vm() {
  STEP=$1
  VMNAME=$2

  echo -e "$STEP: attempting to start nested VM named\
  \033[1;32m$VMNAME\033[0m on $EXTERNAL_IP"

  MSG=`ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@$EXTERNAL_IP \
  "source /usr/local/lib/rhttool.shlib && 
  is_running $VMNAME && echo $VMNAME already running || rht-vmctl start $VMNAME"`

  echo -e "\\033[1;32m$MSG\\033[0;39m"
  echo
}

# this function checks if the VNC port is alrady used
function check_forward(){
   local PORT=$1
   netstat -tulpn 2> /dev/null | grep LISTEN | grep :$PORT
}


function is_online(){
  VM=$1
  ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 kiosk@$EXTERNAL_IP \
      "source /usr/local/lib/rhttool.shlib && is_running $VM"
}


# this function does port forward so that VNC client could be used to connect to workstation VM
function start_vnc_forward() {
  STEP=$1
  if ! check_forward $PORT; then 
     echo "$STEP attempting to port forward local port $PORT to $EXTERNAL_IP"
     echo "      once you see foundation0 prompt you can try to use " 
     echo -e "    \\033[1;35mVNCViewer\\033[0;39m client from your local computer \\033[1;35mvnc://localhost:5902\\033[0;39m"
     echo -e "    \\033[1;35m-------------------------------------------------------------\\033[0;39m"
     echo -e "               make sure to use VNC port \\033[1;33m $PORT  \\033[0;39m"
     echo
     ssh -i ./id_rha_foundation0 -L $PORT\:localhost\:$PORT kiosk@$EXTERNAL_IP || echo -e "\\033[1;31mError\\033[0;39m"
  else
    echo -e "\\033[1;33m Looks like $PORT is already in use, you probably have 
        another terminal window open that is already doing port forwarding \\033[0;39m
        try using VNCViewer to connect to localhost:$PORT"
  fi
}


function basic_boot(){
  echo -e "\nUsing ssh client to connect to $EXTERNAL_IP address to: 
    STEP1 start bastion 
    STEP2 start workstation  
    STEP3 port forward for VNC connection\n"

  start_vm "STEP1" "bastion"
  sleep 5

  start_vm "STEP2" "workstation"
  sleep 5

  get_vnc_port "workstation"

  start_vnc_forward "STEP3"
  echo Done
}


function setup_for_web_login(){
  local PORT=9090
  if ! check_forward $PORT; then
    echo -e "use your browser to navigate to \\033[1;32mhttp://localhost:9090\\033[0;39m"

    ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 \
        -L $PORT\:localhost\:$PORT kiosk@$EXTERNAL_IP || echo -e "\\033[1;31mError\\033[0;39m"
  else
    echo -e "\\033[1;33m Looks like $PORT is already in use, you probably have
     another terminal window open that is already doing port forwarding \\033[0;39m
     use your browser to navigate to http://localhost:9090"
  fi
}

function stop_all_nested_vms(){
  ssh -i ./id_rha_foundation0 kiosk@$EXTERNAL_IP "rht-vmctl stop all "|| echo -e "\\033[1;31mError\\033[0;39m"
  echo "if you are done, also make sure to shutdown the VM instance in Google Cloud"
}

function get_vnc_port(){
  VMNAME=$1
  # this request only makes sense if bastion and workstation are online
  if is_online "bastion" && is_online $VMNAME; then
    PORT=`ssh -o StrictHostKeyChecking=no -i id_rha_foundation0 \
          kiosk@$EXTERNAL_IP  "virsh -c 'qemu:///system' vncdisplay $VMNAME"`

    PORT=590"${PORT: -1}"
    echo -e $VMNAME is using the following vnc port: $PORT
  else
    echo $VMNAME  is offline, therefore vnc is not available 
  fi
}

function get_status(){

   VM="bastion"
   is_online $VM && echo -e "$VM \\033[1;32monline\\033[0;39m" || \
                          echo -e "$VM \\033[1;31moffline\\033[0;39m"
   VM="workstation"
   is_online $VM && echo -e "$VM \\033[1;32monline\\033[0;39m" || \
                          echo -e "$VM \\033[1;31moffline\\033[0;39m"
 
   if is_online "workstation" ; then 
      get_vnc_port "workstation"
      check_forward $PORT && echo -e "$PORT \\033[1;32malready forwarding\\033[0;39m" || \
                          echo -e "$PORT \\033[1;31mnot forwarding\\033[0;39m"
   else
      echo -e "vnc port is \\033[1;31mnot forwarding\\033[0;39m forwarding since workstation vm is offline"
   fi

   local PORT=9090
   check_forward $PORT && echo -e "weblogin $PORT is \\033[1;32malready forwarding\\033[0;39m" || \
                          echo -e "$PORT \\033[1;31mnot forwarding\\033[0;39m"

   VM="servera"
   is_online $VM && echo -e "$VM \\033[1;32monline\\033[0;39m" || \
                          echo -e "$VM \\033[1;31moffline\\033[0;39m"

   VM="serverb"
   is_online $VM && echo -e "$VM \\033[1;32monline\\033[0;39m" || \
                          echo -e "$VM \\033[1;31moffline\\033[0;39m"

}


usage()
{
    cat <<EOF
Usage:
        $0 <EXTERNAL_IP> command 
option:
        -h                - this usage

where command is one of the following:
        weblogin          - port forward for web login on port 9090
        basic             - will start bastion,workstation and do port forward for VNC
        serveraUP         - bring up servera nested VM
       	serverbUP         - bring up serverb nested VM
        stopall           - stop all nested VMs
        vncport           - get vnc port information that is used by nested workstation VM
        status            - show current status of nested VMs and port Forwarding

EOF
    exit 1
}

if [[ $# < 2 ]]; then
    usage;
fi

EXTERNAL_IP=$1

echo $EXTERNAL_IP

if is_google_cloud_ok; then

  if [ $2 = 'basic' ] ; then
      basic_boot

  elif [ $2 = 'serveraUP' ] ; then
      start_vm "SRV" "servera"

  elif [ $2 = 'serverbUP' ] ; then
      start_vm "SRV" "serverb"

  elif [ $2 = 'weblogin' ] ; then
      setup_for_web_login

  elif [ $2 = 'stopall' ] ; then
      stop_all_nested_vms

  elif [ $2 = 'vncport' ] ; then
      get_vnc_port "workstation"

  elif [ $2 = 'status' ] ; then
      get_status


  else
    echo -e "\n\\033[1;31m$2\\033[0;39m is not a valid command";
    echo; 
    usage;

  fi
else
  echo -e "It looks like \\033[1;31m$EXTERNAL_IP\\033[0;39m is \\033[1;31moffline\\033[0;39m are you sure that your 
  VM instance on Google Cloud is RUNNING and that you have provided the correct EXTERNAL_IP address"
fi
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCeGBm06IaOq2QetMZOoHrK4+TZD/lI/NmiBVwAgNKN8jzofu7rIlfjI8v9RdZc5uM6igCyYbXCgy3CzLP34QXtYxcorDRt0OnyQ6+OoY/buXGep4qFPdU0I7rTt89SiUgwI8bGeORxJX/go8meqEG5iYTKVJhHrUQ5xqDQQCz1rR01v9NoIlqsuNgVDzNGZ1IKvF14exsPYyrMN0ebXscinWcm8BoQ22Quf1WGLQnNIcIbrXbC75HRdsD6RqiUv0uVOU1kZDfDVDHXx5nmyJjmRRaXktn67sFeLNoSHXpf3l4I6UTHr4zJrFQ0gy4gnWAOhcr5MrjGIkQXnvH+bHo92CfUxxZ765xoa53i44vAxSY8GfF9hTAsMTUjWXMPUrgypOIeTrGJZJv0xpn80J8VHrixgWJkqasG8VRMUIFrKW1NpO4/bXbDLV9GES+caT/hoxwfqTDt4RLI3i053Z4Kf4zqZuNfi0I8KCKZ2n9p6OjgY/MO4IVWdcTW0rlcxn8= user203265@telehouse-moboware.dmarc.si1.atlanticmetro.net
