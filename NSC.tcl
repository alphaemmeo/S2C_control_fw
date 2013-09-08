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

# @name_file:   NSC.tcl
# @author:      Ivano Calabrese, Giovanni Toso
# @last_update: 2013.07.10
# --
# @brief_description: Application module
#
# the next line restarts using tclsh \
exec expect -f "$0" -- "$@"

# Source
source NSC_config.tcl
source NSC_proc.tcl
source COMMON_proc.tcl

# Global variables
set opt(verbose)                   1
set opt(module_name)               "NSC"
set opt(connection_down)           ""
set opt(connection_up_ns)          ""
set opt(connection_up_app)         ""
set opt(up_connected)              ""
set opt(permap_file_name)          "NSC_mapper.tcl"
set opt(default_per)               "0"

if {[file exists ${opt(permap_file_name)}]} {
    source ${opt(permap_file_name)}
}

# Expect variables
exp_internal 0
remove_nulls -d 0
set timeout -1

# Input and Output configuration
if {${opt(verbose)}} {
    log_nsc "${opt(module_name)}: starting\n"
}

# Spawn a connection with the module below
log_user 0
spawn -open [socket ${down(ip)} ${down(port)}]
set opt(connection_down) ${spawn_id}
fconfigure ${opt(connection_down)} -translation binary
if {${opt(verbose)}} {
    log_nsc "Down connection ${down(ip)}:${down(port)}\n"
}
send_down "ATZ4\n"
log_user 1

# Spawn a connection with the module above
socket -server Accept_ns ${up(nsport)}
socket -server Accept_app ${up(appport)}

proc main_loop {} {
    global opt

    set opt(forever) 1

    expect {
        -i ${opt(connection_down)} -re {(.*)\r\n} {
            # Log the commands
            log_string [clock seconds] ${opt(module_name)} "READDN" "[hexdump $expect_out(1,string)]\n"
            switch -regexp -- $expect_out(1,string) {
                {^RECVIM.+$} {
                    regexp {RECVIM,\d+,\d+,[-+]?[0-9]*\.?[0-9]+,(ack|noack),(.+)} $expect_out(1,string) -> \
                    recvim_ack
                    if {[string compare ${recvim_ack} ack] == 0} {
                        regexp {(RECVIM,(\d+),(\d+),(\d+),ack,(\d+),([-+]?[0-9]*\.?[0-9]+),(\d+),([-+]?[0-9]*\.?[0-9]+),(.*))$} $expect_out(1,string) -> \
                        recvim_msg       \
                        recvim_length    \
                        recvim_src       \
                        recvim_dst       \
                        recvim_bitrate   \
                        recvim_rssi      \
                        recvim_integrity \
                        recvim_vel       \
                        recvim_payload
                    } else {
                        regexp {(RECVIM,(\d+),(\d+),(\d+),noack,(\d+),([-+]?[0-9]*\.?[0-9]+),(\d+),([-+]?[0-9]*\.?[0-9]+),(.*))$} $expect_out(1,string) -> \
                        recvim_msg       \
                        recvim_length    \
                        recvim_src       \
                        recvim_dst       \
                        recvim_bitrate   \
                        recvim_rssi      \
                        recvim_integrity \
                        recvim_vel       \
                        recvim_payload
                    }

                    #- MULTIPATH_LOG ------------------------------
                        set log(timestamp) [clock seconds]
                        set log(msg) $expect_out(1,string)
                        logMultiPath ${log(timestamp)} ${log(msg)}
                        send -i ${opt(connection_down)} -- "AT?P\n"
                    #----------------------------------------------

                    set drop_flag [drop_packet ${recvim_src}]
                    if {[string compare ${drop_flag} "1"] == 0} {
                        drop "$expect_out(1,string)\n"
                    } else {
                        send_up_ns "$expect_out(1,string)"
                    }
                }
                {^RECV,.+$} {
                    regexp {(RECV,(\d+),(\d+),(\d+),(\d+),([-+]?[0-9]*\.?[0-9]+),(\d+),(\d+),([-+]?[0-9]*\.?[0-9]+),(.*))$} $expect_out(1,string) -> \
                    recv_msg       \
                    recv_length    \
                    recv_src       \
                    recv_dst       \
                    recv_bitrate   \
                    recv_rssi      \
                    recv_integrity \
                    recv_proptime  \
                    recv_vel       \
                    recv_payload

                    #- MULTIPATH_LOG ------------------------------
                        set log(timestamp) [clock seconds]
                        set log(msg) $expect_out(1,string)
                        logMultiPath ${log(timestamp)} ${log(msg)}
                        send -i ${opt(connection_down)} -- "AT?P\n"
                    #----------------------------------------------

                    send_up_ns "$expect_out(1,string)"
                    #exp_continue
                }
                {^\d+\ *\d+\ *} {
                    #- MULTIPATH_LOG ------------------------------
                        set log(timestamp) [clock seconds]
                        set log(msg) $expect_out(1,string)
                        logMultiPath ${log(timestamp)} ${log(msg)}
                    #----------------------------------------------
                }
                default {
                    regexp {(.*?)} $expect_out(1,string) -> msg
                    send_up_ns "$expect_out(1,string)"
                }
            }
            exp_continue
        }
        -i ${opt(connection_up_ns)} -re {.+} {
            log_string [clock seconds] ${opt(module_name)} "READUP" "[hexdump $expect_out(buffer)]\n"
            log_string [clock seconds] ${opt(module_name)} "SENDDN" "[hexdump $expect_out(buffer)]\n"
            send -i ${opt(connection_down)} -- $expect_out(buffer)
            exp_continue
        }
        -i ${opt(connection_up_app)} -re {(.*?)\n} {
            log_string [clock seconds] ${opt(module_name)} "READUP" "$expect_out(1,string)\n"
            set out_proc [command_manager $expect_out(1,string) ""]
            send_up_app "${out_proc}\n"
            exp_continue
        }
        -i any_spawn_id eof {
            log_nsc "${opt(module_name)} stopped, reason: $expect_out(spawn_id) eof\n"
            exit 1
        }
    }
}

vwait opt(forever)
