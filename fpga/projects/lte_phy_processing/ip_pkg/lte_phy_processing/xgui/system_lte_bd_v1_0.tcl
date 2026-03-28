# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "DATA_W" -parent ${Page_0}
  ipgui::add_param $IPINST -name "LTE_CORR_FS" -parent ${Page_0}
  ipgui::add_param $IPINST -name "LTE_CORR_LANES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "LTE_PSS_TD_LEN" -parent ${Page_0}


}

proc update_PARAM_VALUE.DATA_W { PARAM_VALUE.DATA_W } {
	# Procedure called to update DATA_W when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.DATA_W { PARAM_VALUE.DATA_W } {
	# Procedure called to validate DATA_W
	return true
}

proc update_PARAM_VALUE.LTE_CORR_FS { PARAM_VALUE.LTE_CORR_FS } {
	# Procedure called to update LTE_CORR_FS when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LTE_CORR_FS { PARAM_VALUE.LTE_CORR_FS } {
	# Procedure called to validate LTE_CORR_FS
	return true
}

proc update_PARAM_VALUE.LTE_CORR_LANES { PARAM_VALUE.LTE_CORR_LANES } {
	# Procedure called to update LTE_CORR_LANES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LTE_CORR_LANES { PARAM_VALUE.LTE_CORR_LANES } {
	# Procedure called to validate LTE_CORR_LANES
	return true
}

proc update_PARAM_VALUE.LTE_PSS_TD_LEN { PARAM_VALUE.LTE_PSS_TD_LEN } {
	# Procedure called to update LTE_PSS_TD_LEN when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.LTE_PSS_TD_LEN { PARAM_VALUE.LTE_PSS_TD_LEN } {
	# Procedure called to validate LTE_PSS_TD_LEN
	return true
}


proc update_MODELPARAM_VALUE.DATA_W { MODELPARAM_VALUE.DATA_W PARAM_VALUE.DATA_W } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.DATA_W}] ${MODELPARAM_VALUE.DATA_W}
}

proc update_MODELPARAM_VALUE.LTE_CORR_FS { MODELPARAM_VALUE.LTE_CORR_FS PARAM_VALUE.LTE_CORR_FS } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LTE_CORR_FS}] ${MODELPARAM_VALUE.LTE_CORR_FS}
}

proc update_MODELPARAM_VALUE.LTE_CORR_LANES { MODELPARAM_VALUE.LTE_CORR_LANES PARAM_VALUE.LTE_CORR_LANES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LTE_CORR_LANES}] ${MODELPARAM_VALUE.LTE_CORR_LANES}
}

proc update_MODELPARAM_VALUE.LTE_PSS_TD_LEN { MODELPARAM_VALUE.LTE_PSS_TD_LEN PARAM_VALUE.LTE_PSS_TD_LEN } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.LTE_PSS_TD_LEN}] ${MODELPARAM_VALUE.LTE_PSS_TD_LEN}
}

