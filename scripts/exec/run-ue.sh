#!/usr/bin/env bash
set -euo pipefail

_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE}")" && pwd -P)"

source "$_SCRIPT_DIR/../helpers/args.sh"
source "$_SCRIPT_DIR/../helpers/terminal.sh"
source "$_SCRIPT_DIR/../helpers/setcap.sh" 

if [ $EXEC_REL_ERR_PARSED = 1 ]; then 
    echo "EXEC_REL_ERR_PARSED eq 1. exit.."
    exit 1
fi 

EXEC_PATH="$_SCRIPT_DIR/../../build"

echo "running run-epc.sh..." 

# sudo ip netns add ue1

if [ $EXEC_REL_ON_RELEASE = 1 ]; then  
    EXEC_PATH="$EXEC_PATH/release"

    if [ "$(has_file_caps "$EXEC_PATH/srsue/src/srsue" "cap_sys_admin,cap_sys_nice,cap_ipc_lock,cap_net_admin,cap_net_bind_service,cap_net_raw+eip" )" = 0 ]; then 
        sudo setcap cap_sys_admin,cap_sys_nice,cap_ipc_lock,cap_net_admin,cap_net_bind_service,cap_net_raw+eip "$EXEC_PATH/srsue/src/srsue"
    else 
        echo "setcap cap_sys_admin,cap_sys_nice,cap_ipc_lock,cap_net_admin,cap_net_bind_service,cap_net_raw+eip capabillities already exists"
    fi 

    open_in_console_gui "$EXEC_PATH/srsue/src/srsue" "$_SCRIPT_DIR/../../srsconfig/ue/ue1/ue.conf"
fi 

if [ $EXEC_REL_ON_DEBUG = 1 ]; then 
    EXEC_PATH="$EXEC_PATH/debug"

    if [ "$(has_file_caps "$EXEC_PATH/srsue/src/srsue" "cap_sys_admin,cap_sys_nice,cap_ipc_lock,cap_net_admin,cap_net_bind_service,cap_net_raw+eip" )" = 0 ]; then 
        sudo setcap cap_sys_admin,cap_sys_nice,cap_ipc_lock,cap_net_admin,cap_net_bind_service,cap_net_raw+eip "$EXEC_PATH/srsue/src/srsue"
    else 
        echo "setcap cap_sys_admin,cap_sys_nice,cap_ipc_lock,cap_net_admin,cap_net_bind_service,cap_net_raw+eip capabillities already exists"
    fi 

    if [ $GDB_ON = 1 ]; then 
        open_in_console_gui gdbserver --once "${GDB_ADDR:-:2365}" "$EXEC_PATH/srsue/src/srsue" "$_SCRIPT_DIR/../../srsconfig/ue/ue1/ue.conf"
    else 
        open_in_console_gui "$EXEC_PATH/srsue/src/srsue" "$_SCRIPT_DIR/../../srsconfig/ue/ue1/ue.conf"
	open_in_console_gui "$EXEC_PATH/srsue/src/srsue" "$_SCRIPT_DIR/../../srsconfig/ue/ue2/ue.conf"
    	open_in_console_gui "$EXEC_PATH/srsue/src/srsue" "$_SCRIPT_DIR/../../srsconfig/ue/ue3/ue.conf"
    fi 
fi 
