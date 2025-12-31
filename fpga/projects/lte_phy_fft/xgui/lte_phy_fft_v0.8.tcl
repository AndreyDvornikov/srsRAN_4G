#
# bel_fft_axi_xgui.tcl
#
#
# This file is part of the "bel_fft" project
#
# Author(s):
#     - Frank Storm (Frank.Storm@gmx.net)
#
#
# Copyright (C) 2013 - 2017 Authors
#
# This source file may be used and distributed without
# restriction provided that this copyright statement is not
# removed from the file and that any derivative work contains
# the original copyright notice and the associated disclaimer.
#
# This source file is free software; you can redistribute it
# and/or modify it under the terms of the GNU Lesser General
# Public License as published by the Free Software Foundation;
# either version 2.1 of the License, or (at your option) any
# later version.
#
# This source is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE.  See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General
# Public License along with this source; if not, download it
# from http://www.gnu.org/licenses/lgpl.html
#
#
# CVS Revision History
#
# $Log$
#

# Definitional proc to organize widgets for parameters.
proc init_gui {IPINST} {
    ipgui::add_param $IPINST -name "Component_Name"
    #Adding Page
    ipgui::add_page $IPINST -name "Page 0"


}

proc update_PARAM_VALUE.C_BASEADDR {PARAM_VALUE.C_BASEADDR} {
    # Procedure called to update C_BASEADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_BASEADDR {PARAM_VALUE.C_BASEADDR} {
    # Procedure called to validate C_BASEADDR
    return true
}

proc update_PARAM_VALUE.C_HIGHADDR {PARAM_VALUE.C_HIGHADDR} {
    # Procedure called to update C_HIGHADDR when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_HIGHADDR {PARAM_VALUE.C_HIGHADDR} {
    # Procedure called to validate C_HIGHADDR
    return true
}

proc update_PARAM_VALUE.C_M_AXI_ADDR_WIDTH {PARAM_VALUE.C_M_AXI_ADDR_WIDTH} {
    # Procedure called to update C_M_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M_AXI_ADDR_WIDTH {PARAM_VALUE.C_M_AXI_ADDR_WIDTH} {
    # Procedure called to validate C_M_AXI_ADDR_WIDTH
    return true
}

proc update_PARAM_VALUE.C_M_AXI_DATA_WIDTH {PARAM_VALUE.C_M_AXI_DATA_WIDTH} {
    # Procedure called to update C_M_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M_AXI_DATA_WIDTH {PARAM_VALUE.C_M_AXI_DATA_WIDTH} {
    # Procedure called to validate C_M_AXI_DATA_WIDTH
    return true
}

proc update_PARAM_VALUE.C_M_AXI_ID_WIDTH {PARAM_VALUE.C_M_AXI_ID_WIDTH} {
    # Procedure called to update C_M_AXI_ID_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M_AXI_ID_WIDTH {PARAM_VALUE.C_M_AXI_ID_WIDTH} {
    # Procedure called to validate C_M_AXI_ID_WIDTH
    return true
}

proc update_PARAM_VALUE.C_M_AXI_PROTOCOL {PARAM_VALUE.C_M_AXI_PROTOCOL} {
    # Procedure called to update C_M_AXI_PROTOCOL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_M_AXI_PROTOCOL {PARAM_VALUE.C_M_AXI_PROTOCOL} {
    # Procedure called to validate C_M_AXI_PROTOCOL
    return true
}

proc update_PARAM_VALUE.C_S_AXI_ADDR_WIDTH {PARAM_VALUE.C_S_AXI_ADDR_WIDTH} {
    # Procedure called to update C_S_AXI_ADDR_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_ADDR_WIDTH {PARAM_VALUE.C_S_AXI_ADDR_WIDTH} {
    # Procedure called to validate C_S_AXI_ADDR_WIDTH
    return true
}

proc update_PARAM_VALUE.C_S_AXI_DATA_WIDTH {PARAM_VALUE.C_S_AXI_DATA_WIDTH} {
    # Procedure called to update C_S_AXI_DATA_WIDTH when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_DATA_WIDTH {PARAM_VALUE.C_S_AXI_DATA_WIDTH} {
    # Procedure called to validate C_S_AXI_DATA_WIDTH
    return true
}

proc update_PARAM_VALUE.C_S_AXI_PROTOCOL {PARAM_VALUE.C_S_AXI_PROTOCOL} {
    # Procedure called to update C_S_AXI_PROTOCOL when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.C_S_AXI_PROTOCOL {PARAM_VALUE.C_S_AXI_PROTOCOL} {
    # Procedure called to validate C_S_AXI_PROTOCOL
    return true
}


proc update_MODELPARAM_VALUE.C_BASEADDR {MODELPARAM_VALUE.C_BASEADDR PARAM_VALUE.C_BASEADDR} {
    # Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
    set_property value [get_property value ${PARAM_VALUE.C_BASEADDR}] ${MODELPARAM_VALUE.C_BASEADDR}
}

proc update_MODELPARAM_VALUE.C_HIGHADDR {MODELPARAM_VALUE.C_HIGHADDR PARAM_VALUE.C_HIGHADDR} {
    # Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
    set_property value [get_property value ${PARAM_VALUE.C_HIGHADDR}] ${MODELPARAM_VALUE.C_HIGHADDR}
}

proc update_MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH {MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH PARAM_VALUE.C_S_AXI_ADDR_WIDTH} {
    # Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
    set_property value [get_property value ${PARAM_VALUE.C_S_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH {MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH PARAM_VALUE.C_S_AXI_DATA_WIDTH} {
    # Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
    set_property value [get_property value ${PARAM_VALUE.C_S_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_S_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_S_AXI_PROTOCOL {MODELPARAM_VALUE.C_S_AXI_PROTOCOL PARAM_VALUE.C_S_AXI_PROTOCOL} {
    # Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
    set_property value [get_property value ${PARAM_VALUE.C_S_AXI_PROTOCOL}] ${MODELPARAM_VALUE.C_S_AXI_PROTOCOL}
}

proc update_MODELPARAM_VALUE.C_M_AXI_ADDR_WIDTH {MODELPARAM_VALUE.C_M_AXI_ADDR_WIDTH PARAM_VALUE.C_M_AXI_ADDR_WIDTH} {
    # Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
    set_property value [get_property value ${PARAM_VALUE.C_M_AXI_ADDR_WIDTH}] ${MODELPARAM_VALUE.C_M_AXI_ADDR_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M_AXI_DATA_WIDTH {MODELPARAM_VALUE.C_M_AXI_DATA_WIDTH PARAM_VALUE.C_M_AXI_DATA_WIDTH} {
    # Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
    set_property value [get_property value ${PARAM_VALUE.C_M_AXI_DATA_WIDTH}] ${MODELPARAM_VALUE.C_M_AXI_DATA_WIDTH}
}

proc update_MODELPARAM_VALUE.C_M_AXI_PROTOCOL {MODELPARAM_VALUE.C_M_AXI_PROTOCOL PARAM_VALUE.C_M_AXI_PROTOCOL} {
    # Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
    set_property value [get_property value ${PARAM_VALUE.C_M_AXI_PROTOCOL}] ${MODELPARAM_VALUE.C_M_AXI_PROTOCOL}
}

proc update_MODELPARAM_VALUE.C_M_AXI_ID_WIDTH {MODELPARAM_VALUE.C_M_AXI_ID_WIDTH PARAM_VALUE.C_M_AXI_ID_WIDTH} {
    # Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
    set_property value [get_property value ${PARAM_VALUE.C_M_AXI_ID_WIDTH}] ${MODELPARAM_VALUE.C_M_AXI_ID_WIDTH}
}

