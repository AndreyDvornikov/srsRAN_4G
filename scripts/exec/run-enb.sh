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

echo "running run-enb.sh..." 

if [ $EXEC_REL_ON_RELEASE = 1 ]; then  
    EXEC_PATH="$EXEC_PATH/release"

    if [ "$(has_file_caps "$EXEC_PATH/srsenb/src/srsenb" "cap_sys_admin,cap_sys_nice,cap_ipc_lock,cap_net_admin,cap_net_bind_service,cap_net_raw+eip" )" = 0 ]; then 
        sudo setcap cap_sys_admin,cap_sys_nice,cap_ipc_lock,cap_net_admin,cap_net_bind_service,cap_net_raw+eip "$EXEC_PATH/srsenb/src/srsenb"
    else 
        echo "setcap cap_sys_admin,cap_sys_nice,cap_ipc_lock,cap_net_admin,cap_net_bind_service,cap_net_raw+eip capabillities already exists"
    fi 

    open_in_console_gui "$EXEC_PATH/srsenb/src/srsenb" "$_SCRIPT_DIR/../../srsconfig/enb/enb1/enb.conf"\
        --enb_files.sib_config="$_SCRIPT_DIR/../../srsconfig/enb/enb1/sib.conf"\
        --enb_files.rr_config="$_SCRIPT_DIR/../../srsconfig/enb/enb1/rr.conf"\
        --enb_files.rb_config="$_SCRIPT_DIR/../../srsconfig/enb/enb1/rb.conf"
fi 

if [ $EXEC_REL_ON_DEBUG = 1 ]; then 
    EXEC_PATH="$EXEC_PATH/debug"

    if [ "$(has_file_caps "$EXEC_PATH/srsenb/src/srsenb" "cap_sys_admin,cap_sys_nice,cap_ipc_lock,cap_net_admin,cap_net_bind_service,cap_net_raw+eip" )" = 0 ]; then 
        sudo setcap cap_sys_admin,cap_sys_nice,cap_ipc_lock,cap_net_admin,cap_net_bind_service,cap_net_raw+eip "$EXEC_PATH/srsenb/src/srsenb"
    else 
        echo "setcap cap_sys_admin,cap_sys_nice,cap_ipc_lock,cap_net_admin,cap_net_bind_service,cap_net_raw+eip capabillities already exists"
    fi 

    if [ $GDB_ON = 1 ]; then 
        open_in_console_gui gdbserver --once "${GDB_ADDR:-:2355}" "$EXEC_PATH/srsenb/src/srsenb" "$_SCRIPT_DIR/../../srsconfig/enb/enb1/enb.conf"\
            --enb_files.sib_config="$_SCRIPT_DIR/../../srsconfig/enb/enb1/sib.conf"\
            --enb_files.rr_config="$_SCRIPT_DIR/../../srsconfig/enb/enb1/rr.conf"\
            --enb_files.rb_config="$_SCRIPT_DIR/../../srsconfig/enb/enb1/rb.conf"
    else 
        open_in_console_gui "$EXEC_PATH/srsenb/src/srsenb" "$_SCRIPT_DIR/../../srsconfig/enb/enb1/enb.conf"\
            --enb_files.sib_config="$_SCRIPT_DIR/../../srsconfig/enb/enb1/sib.conf"\
            --enb_files.rr_config="$_SCRIPT_DIR/../../srsconfig/enb/enb1/rr.conf"\
            --enb_files.rb_config="$_SCRIPT_DIR/../../srsconfig/enb/enb1/rb.conf"
    fi 
fi