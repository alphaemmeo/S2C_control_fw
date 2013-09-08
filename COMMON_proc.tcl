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

# @name_file:   COMMON_proc.tcl
# @author:      Ivano Calabrese, Giovanni Toso
# @last_update: 2013.07.10
# --
# @brief_description: Contains procedures common to all the modules
#
# the next line restarts using tclsh \
exec expect -f "$0" -- "$@"

set log(write_period)      "3000" ;# in ms
set log(write_scheduled)   "0"
set log(file_name)         "S2C.log"
set log(list_to_log)       {}

proc log_string {input_timestamp input_module input_direction input_string} {
    global log

    set tmp_string [format "%s\t%s\t%s\t%s"\
        ${input_timestamp}\
        ${input_module}\
        ${input_direction}\
        $input_string\
        ]
    lappend log(list_to_log) ${tmp_string}
    if {[string compare ${log(write_scheduled)} "0"] == 0} {
        set log(write_scheduled) [expr [clock seconds] + ${log(write_period)} / 1000]
    }
    if {[expr [clock seconds] - ${log(write_scheduled)}] < 0} {
        return
    } else {
        after ${log(write_period)} write_in_buffer
        set log(write_scheduled) [expr [clock seconds] + ${log(write_period)} / 1000]
    }
}

proc write_in_buffer {} {
    global log

    if {[file exists ${log(file_name)}] == 0} {
        if {[catch {exec touch ${log(file_name)}} res] != 0} {
            puts stderr "Error creating ${log(file_name)}. Details: ${res}"
            return
        }
    }
    # Test if the log file are writable
    if {[catch {open ${log(file_name)} "a+"} res] != 0} {
        puts stderr "Error opening ${log(file_name)}. Details: ${res}"
        return
    }
    set fp ${res}
    foreach line ${log(list_to_log)} {
        puts -nonewline ${fp} ${line}
    }
    close ${fp}
    set log(list_to_log) {}
}
