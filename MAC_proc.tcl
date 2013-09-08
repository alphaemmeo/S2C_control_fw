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

# @name_file:   MAC_proc.tcl
# @author:      Ivano Calabrese, Giovanni Toso
# @last_update: 2013.07.10
# --
# @brief_description: Procedure file for the MAC module
#
# the next line restarts using tclsh \
exec expect -f "$0" -- "$@"

proc Accept {sock addr port} {
    global opt up

    log_user 0
    spawn -open $sock
    set opt(connection_up) ${spawn_id}
    fconfigure ${opt(connection_up)} -translation binary

    #- MAC_LOG --------------------------------------------------------------------
        set log(timestamp) [clock seconds]
        set log(direction) "|    |"
        set log(msg) "Connection up established. SPAWN_ID: $opt(connection_up)"
        logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
        set log(msg) "Up connection with IP: ${up(ip)} and Port: ${up(port)}"
        logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
    #------------------------------------------------------------------------------

    if {${opt(debug)}} {
        puts stdout "* Up connection:   established"
    }
    log_user 1
    main_loop
}

proc logMac {input_timestamp input_module input_direction input_string} {
    global opt
    set disk_files [list "${input_module}.log"]
    #set disk_files [list "extra_MAC.log"]
    foreach file_name $disk_files {
        if { [file exists ${file_name}] != 1 } {
            exec touch ${file_name}
        }
        # Test if the log file are writable
        if {[catch {open ${file_name} "a+"} error_msg]} {
            puts stderr "${error_msg}"
            return
        }
        if {[catch {open ${file_name} "a+"} res]} {
            puts stderr "${res}"
            return
        } else {
            set fp ${res}
        }
        puts ${fp} [format "%s\t%s\t%s\t%s"\
            ${input_timestamp}\
            ${input_module}\
            ${input_direction}\
            $input_string\
            ]
        close ${fp}
    }
}

proc logMultiPath {input_timestamp input_string} {
    global opt
    set disk_files [list "multipath.log"]
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
