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

# @name_file:   APP.tcl
# @author:      Ivano Calabrese, Giovanni Toso
# @last_update: 2013.07.10
# --
# @brief_description: Application module
#
# the next line restarts using tclsh \
exec expect -f "$0" -- "$@"

# Source
source APP_config.tcl
source APP_proc.tcl
source COMMON_proc.tcl

# Global variables
set opt(verbose)                   1
set opt(module_name)               "APP"
set modem(id)                      ""
set modem(powerlevel)              ""
set opt(connection_down)           ""
set opt(connection_up)             ""
set opt(up_connected)              ""
set opt(sendim_counter)            1
set opt(file_sendim_counter)       "APP_sendim_counter.tcl"
set opt(ack_mode)                  "noack"
set opt(net_forward_mode)          ""
set opt(mac_delay)                 ""
set opt(default_ttl)               5
set opt(pending_id_request)        -2
set opt(pending_power_request)     -2
set opt(sleep_before_answer)       1
set opt(max_sendim_size)           64
set opt(max_system_cmd_log_length) 240
set opt(map_ns_file_name)          "APP_map_ns.tcl"
set opt(ns_start_file_name)        "ns_start.sh"
set opt(getper_last_src)           ""
set opt(getper_last_ttl)           ""
set map_ns_pid()                   ""
set map_ns_id()                    ""

if {[file exists ${opt(map_ns_file_name)}]} {
    source ${opt(map_ns_file_name)}
}
if {[file exists ${opt(file_sendim_counter)}]} {
    source ${opt(file_sendim_counter)}
}

# Expect variables
exp_internal 0
set timeout -1
remove_nulls -d 0

# Input and Output configuration
if {${opt(verbose)}} {
    debug_app "${opt(module_name)}: starting\n"
}

# Spawn a connection with the modules below
log_user 0
# NET
spawn -open [socket ${down(ip)} ${down(port)}]
set opt(connection_down) ${spawn_id}
fconfigure ${opt(connection_down)} -translation binary
if {${opt(verbose)}} {
    debug_app "Down connection (NET) ${down(ip)}:${down(port)}\n"
}
# NSC
spawn -open [socket ${down(nscip)} ${down(nscport)}]
set opt(connection_down_nsc) ${spawn_id}
fconfigure ${opt(connection_down_nsc)} -translation binary
if {${opt(verbose)}} {
    debug_app "Down connection (NSC) ${down(nscip)}:${down(nscport)}\n"
}
log_user 1

# Spawn a connection with the module above
socket -server Accept ${up(port)}

proc main_loop {} {
    global opt modem

    set opt(forever) 1

    reset_pendings
    expect {
        -i ${opt(connection_down)} -re {(.*?)\r\n} {
            # Log the commands
            log_string [clock seconds] ${opt(module_name)} "READDN" "$expect_out(1,string)\n"
            switch -regexp -- $expect_out(1,string) {
                {^RECVIM.*,ACK>.*$} {
                    reset_pendings
                    send_up "$expect_out(1,string)\n"
                }
                {^RECVIM.*$} {
                    regexp {RECVIM,\d+,\d+,\d+,(ack|noack),(.*)} $expect_out(1,string) -> \
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
                    } elseif {[string compare ${recvim_ack} noack] == 0} {
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
                    } else {
                        reset_pendings
                        debug_app "Unmanaged RECVIM with ack flag set to ${recvim_ack}: $expect_out(1,string)\n"
                        send_up "$expect_out(1,string)\n"
                        exp_continue
                    }
                    switch -regexp -- ${recvim_payload} {
                        {^(F|S),.*$} {
                            regexp {(F|S),(\d+),(\d+),((\d+\ ?)+)?,(\d+)?,((\d+\ ?)+)?,(.*)} ${recvim_payload} -> \
                            net_protocol     \
                            net_src          \
                            net_sn           \
                            net_dst_list     \
                            ->               \
                            net_orig_length  \
                            net_extra_field  \
                            ->               \
                            net_payload
                            send_up "$expect_out(1,string)\n"
                            set return_msg [command_manager ${net_payload} ${recvim_payload}]

                            if {[string compare ${net_src} ${modem(id)}] != 0} { ;# Do not send an ack to myself.
                                if {[string compare ${return_msg} "NOACK"] == 0} {
                                    exp_continue
                                } else {
                                    if {[string compare ${net_protocol} "F"] == 0} { ;# Check the protocol used.
                                        set ack_ttl [expr ${net_orig_length} - ${net_extra_field}]
                                    } else {
                                        set ack_ttl [expr ${net_orig_length} - [llength [split ${net_extra_field} " "]]]
                                    }
                                    if {[string compare ${return_msg} "ACK"] == 0} {
                                        set msg "SEND,F,${net_src},${ack_ttl},ACK>${net_payload}"
                                    } else {
                                        set msg "SEND,F,${net_src},${ack_ttl},R>${return_msg}"
                                    }
                                    set sendim_to_send "[forge_sendim ${msg}]"
                                    if {[string compare ${sendim_to_send} "ERR"] != 0} {
                                        debug_app "${sendim_to_send}\n"
                                        send_up "${opt(module_name)}: created ${sendim_to_send}\n"
                                        sleep ${opt(sleep_before_answer)}
                                        send_down "${sendim_to_send}\n"

                                    } else {
                                        debug_app "Error during the creation of an instant message: msg too long of fields not initialized\n"
                                        send_up "${opt(module_name)}: Error during the creation of an instant message: msg too long of fields not initialized\n"
                                        exp_continue
                                    }
                                }
                            } else {
                                debug_app "The net source is equal to the modem id: msg not acked\n"
                                send_up "${opt(module_name)}: The net source is equal to the modem id: msg not acked\n"
                            }
                        }
                        default {
                            reset_pendings
                            debug_app "Unmanaged RECVIM with routing protocol flag: $expect_out(1,string)\n"
                            send_up "$expect_out(1,string)\n"
                            exp_continue
                        }
                    }
                }
                {^\d+$} {
                    if {${opt(pending_id_request)} == -1 && ${opt(pending_power_request)} != -1} {
                        regexp {^(\d+)$} $expect_out(1,string) -> modem(id)
                        if {[info exists modem(id)]} {
                            debug_app "Modem id: ${modem(id)}\n"
                        } else {
                            debug_app "Error in reading the id of the modem\n"
                        }
                    } elseif {${opt(pending_id_request)} != -1 && ${opt(pending_power_request)} == -1} {
                        regexp {^(\d+)$} $expect_out(1,string) -> modem(powerlevel)
                        if {[info exists modem(powerlevel)]} {
                            debug_app "Modem power level: ${modem(powerlevel)}\n"
                        } else {
                            debug_app "Error in reading the power level of the modem\n"
                        }
                    } else {
                        debug_app "Unexpected or unmanaged: $expect_out(1,string). Reset pending requests\n"
                    }
                    reset_pendings
                    send_up "$expect_out(1,string)\n"
                }
                {^\[\*\][0123]$} {
                    if {${opt(pending_id_request)} != -1 && ${opt(pending_power_request)} == -1} {
                        regexp {^(\[\*\][0123])$} $expect_out(1,string) -> modem(powerlevel)
                        if {[info exists modem(powerlevel)]} {
                            debug_app "Modem power level: ${modem(powerlevel)}\n"
                        } else {
                            debug_app "Error in reading the power level of the modem\n"
                        }
                    } else {
                        debug_app "Unexpected or unmanaged: $expect_out(1,string). Reset pending requests\n"
                    }
                    reset_pendings
                    send_up "$expect_out(1,string)\n"
                }
                {^OK$} {
                    if {${opt(pending_id_request)} > -1 && ${opt(pending_power_request)} == -2} {
                        set modem(id) ${opt(pending_id_request)}
                        debug_app "Modem id set to ${modem(id)}\n"
                    } elseif {${opt(pending_id_request)} == -2 && ${opt(pending_power_request)} > -2} {
                        set modem(powerlevel) ${opt(pending_power_request)}
                        debug_app "Modem power level set to ${modem(powerlevel)}\n"
                    }
                    reset_pendings
                    send_up "$expect_out(1,string)\n"
                }
                default {
                    reset_pendings
                    send_up "$expect_out(1,string)\n"
                }
            }
            exp_continue
        }
        -i ${opt(connection_down_nsc)} -re {(.*?)\n} {
            log_string [clock seconds] ${opt(module_name)} "READDN" "$expect_out(1,string)\n"
            send_up "$expect_out(1,string)\n"
            command_manager $expect_out(1,string) ""
            exp_continue
        }
        -i ${opt(connection_up)} -re {(.*?)\n} {
            log_string [clock seconds] ${opt(module_name)} "READUP" "$expect_out(1,string)\n"
            command_manager $expect_out(1,string) ""
            exp_continue
        }
        -i any_spawn_id eof {
            debug_app "${opt(module_name)} stopped, reason: $expect_out(spawn_id) eof\n"
            exit 1
        }
    }
}

vwait opt(forever)
