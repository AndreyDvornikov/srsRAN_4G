#!/bin/sh
# the next line restarts using tclsh \
exec tclsh "$0" "$@"

#
# xsim-simulate.tcl
#
#
# This file is part of the "bel_fft" project
#
# Author(s):
#     - Frank Storm (Frank.Storm@gmx.net)
#
#
# Copyright (C) 2012-2013 Authors
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


set BEL_FFT_SRC_DIR ../../hdl/verilog
set BEL_FFT_IP_DIR ../../ip


proc bel_fft_library_setup {} {

    global BEL_FFT_SRC_DIR
    global BEL_FFT_IP_DIR

    if {[file exist [file join $BEL_FFT_IP_DIR lte_phy_fft_twiddle_rom1.mif]]} {
        file copy -force [file join $BEL_FFT_IP_DIR lte_phy_fft_twiddle_rom1.mif] .
    }
    if {[file exist [file join $BEL_FFT_IP_DIR lte_phy_fft_twiddle_rom1.dat]]} {
        file copy -force [file join $BEL_FFT_IP_DIR lte_phy_fft_twiddle_rom1.dat] .
    }
    # file copy -force [file join $BEL_FFT_SRC_DIR bel_fft_def.v] bel_fft_def.v
}


proc bel_fft_compile_files {} {

    global BEL_FFT_SRC_DIR

    if {[file isdirectory xsim.dir]} {
        file delete -force xsim.dir
    }

    foreach verilogFileName [list \
            [file join $BEL_FFT_SRC_DIR bel_butterfly4.v] \
            [file join $BEL_FFT_SRC_DIR bel_butterfly2.v] \
            [file join $BEL_FFT_SRC_DIR bel_cadd.v] \
            [file join $BEL_FFT_SRC_DIR bel_caddsub.v] \
            [file join $BEL_FFT_SRC_DIR bel_cdiv4.v] \
            [file join $BEL_FFT_SRC_DIR bel_cdiv2.v] \
            [file join $BEL_FFT_SRC_DIR bel_cmac.v] \
            [file join $BEL_FFT_SRC_DIR bel_cmul.v] \
            [file join $BEL_FFT_SRC_DIR bel_copy.v] \
            [file join $BEL_FFT_SRC_DIR bel_csub.v] \
            [file join $BEL_FFT_SRC_DIR bel_fft_core.v] \
            [file join $BEL_FFT_SRC_DIR bel_fft_axi.v] \
            [file join $BEL_FFT_SRC_DIR bel_fft_axi_sif.v] \
            [file join $BEL_FFT_SRC_DIR bel_fft_axi_mif.v] \
            [file join $BEL_FFT_SRC_DIR lte_phy_fft_twiddle_rom0.v] \
            [file join $BEL_FFT_SRC_DIR lte_phy_fft_twiddle_rom1.v] \
            [file join $BEL_FFT_SRC_DIR lte_phy_fft_twiddle_roms.v] \
            [file join $BEL_FFT_SRC_DIR lte_phy_fft.v] \
            bel_axi_ram.v \
            testbench_128_inv.v \
            ] {
        if {[catch {exec xvlog \
                --verbose 2 \
                --include $BEL_FFT_SRC_DIR \
                $verilogFileName} result]} {
            puts $result
        }
    }
}


proc isVersionGreaterThan {version} {

    set xelabVersionStr [exec xelab --version]
    set xelabVersion [lindex $xelabVersionStr 2]
    set xelabYear [lindex [split $xelabVersion .] 0]
    set xelabRelease [lindex [split $xelabVersion .] 1]
    set year [lindex [split $version .] 0]
    set release [lindex [split $version .] 1]
    if {$xelabYear > $year} {
        return 1
    } elseif {($xelabYear == $year) && ($xelabRelease > $release)} {
        return 1
    } else {
        return 0
    }
}


proc bel_fft_run_simulation {} {

    if {[isVersionGreaterThan 2013.1]} {
        exec xelab \
                --verbose 2 \
                -L xilinxcorelib_ver \
                -L unisims_ver \
                --debug all \
                --override_timeunit \
                --override_timeprecision \
                --timescale 1ns/1ps \
                testbench_128_inv
    } else {
        exec xelab \
                --verbose 2 \
                -L xilinxcorelib_ver \
                -L unisims_ver \
                --debug all \
                testbench_128_inv
    }

    exec xsim \
            --gui \
            work.testbench_128_inv

}


bel_fft_library_setup

bel_fft_compile_files

bel_fft_run_simulation

