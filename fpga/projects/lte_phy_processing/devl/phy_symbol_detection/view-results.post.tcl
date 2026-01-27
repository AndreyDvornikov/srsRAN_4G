proc read_hex_file {fileName} {
    global memData
    array unset memData
    array set memData {}

    set max_addr -1

    if {[catch {set f [open $fileName r]} err]} {
        error "Can't open '$fileName': $err"
    }

    while {[gets $f line] >= 0} {
        # expected: @<hex_addr> <signed_dec>
        if {[regexp {^\s*@([0-9A-Fa-f]+)\s+([-+]?\d+)} $line -> addr_hex val_dec]} {
            set addr [expr 0x$addr_hex]
            set memData($addr) $val_dec
            if {$addr > $max_addr} { set max_addr $addr }
        }
    }
    close $f

    if {$max_addr < 0} {
        return 0
    }
    # number of complex samples = floor(max_addr/2)+1
    return [expr {int($max_addr/2) + 1}]
}

proc write_iq_dat {fileName nComplex part} {
    global memData

    if {[catch {set f [open $fileName w]} err]} {
        error "Can't write '$fileName': $err"
    }

    for {set k 0} {$k < $nComplex} {incr k} {
        if {[string equal $part "I"]} {
            set addr [expr {$k*2}]
        } else {
            set addr [expr {$k*2 + 1}]
        }

        set val 0
        if {[info exists memData($addr)]} {
            set val $memData($addr)
        }

        # 2 columns: sample_index value
        puts $f "$k $val"
    }
    close $f
}

proc write_gnuplot_script {fileName dataI dataQ plotTitle} {
    if {[catch {set f [open $fileName w]} err]} {
        error "Can't write '$fileName': $err"
    }

    puts $f "set grid"
    puts $f "set style data lines"
    puts $f "set title '$plotTitle'"
    puts $f "plot '$dataI' using 1:2 title 'I', '$dataQ' using 1:2 title 'Q'"

    close $f
}

proc hex_plot {inFile {nComplex 0}} {
    set inFileNorm [file normalize $inFile]
    set inDir      [file dirname $inFileNorm]
    set base       [file rootname [file tail $inFileNorm]]

    set nFound [read_hex_file $inFileNorm]
    if {$nFound <= 0} {
        error "No samples found in '$inFileNorm'"
    }

    set n $nFound
    if {$nComplex > 0 && $nComplex < $nFound} {
        set n $nComplex
    }

    set outI [file join $inDir "${base}_I.dat"]
    set outQ [file join $inDir "${base}_Q.dat"]
    set scr  [file join $inDir "plot_${base}.scr"]

    write_iq_dat $outI $n I
    write_iq_dat $outQ $n Q
    write_gnuplot_script $scr $outI $outQ "IQ from [file tail $inFileNorm] (N=$n)"

    puts "Generated:"
    puts "  $outI"
    puts "  $outQ"
    puts "  $scr"

    exec gnuplot -p $scr
}

# --- CLI режим: tclsh sshex_gnuplot.tcl ss.hex 2000 for example
if {[info exists ::argv] && ([llength $::argv] >= 1)} {
    set f [lindex $::argv 0]
    set n 0
    if {[llength $::argv] >= 2} { set n [lindex $::argv 1] }
    hex_plot $f $n
}
