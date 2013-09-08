#!/bin/sh
#
# Copyright (c) 2013 Regents of the SIGNET lab, University of Padova.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of the University of Padova (SIGNET lab) nor the
#    names of its contributors may be used to endorse or promote products
#    derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# @name_file:   APP_proc.tcl
# @author:      Ivano Calabrese, Giovanni Toso
# @last_update: 2013.07.10
# --
# @brief_description: Procedure file for the application module
#
# the next line restarts using tclsh \
exec expect -f "$0" -- "$@"

proc Accept_ns {sock addr port} {
    global opt

    log_user 0
    spawn -open ${sock}
    set opt(connection_up_ns) ${spawn_id}
    fconfigure ${opt(connection_up_ns)} -translation binary
    if {${opt(verbose)}} {
        log_nsc "UP ns connection ${addr}:${port}\n"
    }
    log_user 1
    main_loop
}

proc Accept_app {sock addr port} {
    global opt

    log_user 0
    spawn -open ${sock}
    set opt(connection_up_app) ${spawn_id}
    fconfigure ${opt(connection_up_app)} -translation binary
    if {${opt(verbose)}} {
        log_nsc "UP app connection ${addr}:${port}\n"
    }
    log_user 1
    main_loop
}

proc hexdump {msg} {
    set return_string ""
    for {set i 0} {${i} < [string length ${msg}]} {incr i} {
        set return_string "${return_string}\\[format %4.4X [scan [string index ${msg} ${i}] %c]]"
    }
    return ${return_string}
}

proc send_up_ns {msg} {
    global opt

    log_string [clock seconds] ${opt(module_name)} "SENDUP" "[hexdump ${msg}]\r\n"
    send -i ${opt(connection_up_ns)} -- "${msg}\r\n"
}

proc send_up_app {msg} {
    global opt

    log_string [clock seconds] ${opt(module_name)} "SENDUP" "${msg}"
    send -i ${opt(connection_up_app)} -- ${msg}
}
proc send_down {msg} {
    global opt

    log_string [clock seconds] ${opt(module_name)} "SENDDN" "${msg}"
    send -i ${opt(connection_down)} -- ${msg}
}

proc drop {msg} {
    global opt

    log_string [clock seconds] ${opt(module_name)} "DROP--" "[hexdump ${msg}]\n"
}

proc log_nsc {msg} {
    global opt

    if {${opt(verbose)}} {
        puts -nonewline stdout "* ${msg}"
    }
}

proc logMultiPath {input_timestamp input_string} {
    global opt
    set disk_files [list "multipath_ns.log"]
    foreach file_name $disk_files {
        if { [file exists ${file_name}] != 1 } {
            exec touch ${file_name}
        }
        # Test if the log file are writable
        if {[catch {open ${file_name} "a+"} error_msg]} {
            puts stderr "${error_msg}"
            return
        }
        set fp [open ${file_name} "a+"]
        set line [split $input_string \n]
        for {set i 0} {$i < [llength $line]} {incr i 1} {
            puts ${fp} [format "%s\t%s"\
                           ${input_timestamp}\
                           [lindex $line $i]\
                       ]
        }
        close ${fp}
    }
}

proc drop_packet {src} {
    global opt
    global map_per

    if {[info exists map_per(${src})]} {
        if {[expr rand() > $map_per($src)]} {
            return 0
        } else {
            return 1
        }
    } else {
        return ${opt(default_per)}
    }
}

proc manage_per_list {per_list_raw} {
    global opt
    global map_per

    set per_list [split ${per_list_raw} " "]
    if {[expr [llength ${per_list}] % 2] == 0} {
        if { [file exists ${opt(permap_file_name)}] != 1 } {
            exec touch ${opt(permap_file_name)}
        }
        if {[catch {open ${opt(permap_file_name)} "a+"} res]} {
            puts stderr ${res}
            return "ERR_OPENING_FILE"
        } else {
            set fp ${res}
            for {set i 0} {[expr ${i} + 1] < [llength ${per_list}]} {incr i 2} {
                set map_per([lindex ${per_list} ${i}]) [lindex ${per_list} [expr ${i} + 1]]
                puts -nonewline ${fp} "set map_per([lindex ${per_list} ${i}]) [lindex ${per_list} [expr ${i} + 1]]\n"
            }
            close ${fp}
            return "DONE"
        }
    } else {
        return "ERR_WRONG_FORMAT"
    }
}

proc command_manager {input_command recvim_payload} {
    global opt
    global map_per

    switch -regexp -- ${input_command} {
        {^PERSET\ ((\d+ ([0-9]*\.?[0-9]+)\ ?)+)(\ ?)$} {
            regexp {^PERSET\ ((\d+ ([0-9]*\.?[0-9]+)\ ?)+)(\ ?)$} ${input_command} -> per_list_raw
            if {![info exists per_list_raw] && [string length ${per_list_raw}] == 0} {
                return "SETPER ERR_WRONG_FORMAT"
            }
            set out_proc [manage_per_list ${per_list_raw}]
            return "NSC>PERSET ${out_proc}"
        }
        {^PERGET$} {
            set return_string "NSC>"
            foreach {src per} [array get map_per] {
                set return_string "${return_string}${src}|${per} "
            }
            return ${return_string}
        }
        {^RESETMAPPER$} {
            unset -nocomplain map_per
            log_nsc "Variable map_per removed\n"
            #send_up_app "${opt(module_name)}: Variable map_per removed\n"
            if {[file exists "${opt(permap_file_name)}"]} {
                catch {exec rm -fr ${opt(permap_file_name)}} res
                if {[string length ${res}] == 0 || [string compare ${res} "0"] == 0} {
                    log_nsc "File ${opt(permap_file_name)} removed\n"
                    #send_up_app "${opt(module_name)}: File ${opt(permap_file_name)} removed\n"
                    set return_string "${input_command} DONE"
                } else {
                    log_nsc "File ${opt(permap_file_name)} not removed\n"
                    #send_up_app "${opt(module_name)}: File ${opt(permap_file_name)} not removed\n"
                    set return_string "${input_command} FILE_NOT_REMOVED"
                }
            } else {
                log_nsc "File ${opt(permap_file_name)} not found\n"
                #send_up_app "${opt(module_name)}: File ${opt(permap_file_name)} not found\n"
                set return_string "${input_command} DONE"
            }
            return ${return_string}
        }
        default {
            log_nsc "unmanaged ${input_command}\n"
            #send_up_app "${opt(module_name)}: unmanaged ${input_command}\n"
            send_down "${input_command}\n"
        }
    }
}
