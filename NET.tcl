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

# @name_file:   ctrl_NET.tcl
# @author:      Ivano Calabrese, Giovanni Toso
# @last_update: 2013.09.03
# --
# @brief_description: NET module
#

# the next line restarts using tclsh \
exec expect -f "$0" -- "$@"

source ./NET_config.tcl
source ./NET_proc.tcl
source ./COMMON_proc.tcl

# Expect variables
set timeout -1

if {${opt(debug)}} {
    puts stdout "* NET:             starting"
}

#Spawn a connection: UP interface
socket -server Accept ${up(port)}

#Spawn a connection: DOWN interface
log_user 0
spawn -open [socket ${down(ip)} ${down(port)}]
set opt(connection_down) ${spawn_id}
fconfigure ${opt(connection_down)} -translation binary
if {${opt(debug)}} {
    puts stdout "* Down connection: established"
}
#- NET_LOG --------------------------------------------------------------------
    set log(timestamp) [clock seconds]
    set log(direction) "|    |"
    set log(msg) "Connection down established. SPAWN_ID: $opt(connection_down)\n"
    #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
    log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
    set log(msg) "Down connection with IP: ${down(ip)} and Port: ${down(port)}\n"
    #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
    log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
#------------------------------------------------------------------------------
log_user 1

#- MAIN LOOP ------------------------------------------------------------------
proc main_loop { } {
    global opt modem net flooding_p

    set opt(forever) 1

    # -2 means never requested
    # -1 means pending request
    # >= 0 value sent with AT!AL
    set pending_id_request -2

    expect {
        -i ${opt(connection_up)} -re {(.+)\n} {
            #- COMMON_LOG -----------------------------------------------------------------
                set log(timestamp) [clock seconds]
                set log(direction) "READUP"
                set log(msg) "$expect_out(1,string)\n"
                log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
            #------------------------------------------------------------------------------
            switch -regexp -- $expect_out(1,string) {
                {^AT\?AL$} { ;# Request for modem ID
                    set pending_id_request -1
                    #- NET_LOG --------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "inside AT?AL\n"
                        #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                    send -i ${opt(connection_down)} -- "$expect_out(1,string)\n"
                    #- COMMON_LOG -----------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "SENDDN"
                        set log(msg) "$expect_out(1,string)\n"
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                }
                {^AT\!AL[0-9]+$} { ;# Set modem ID
                    regexp {^AT\!AL([0-9]+)$} $expect_out(1,string) -> pending_id_request

                    if {![info exists pending_id_request]} {
                        #- NET_LOG --------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "|-----"
                            set log(msg) "ERROR: pending_id_request doesn't exist\n"
                            #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                        exp_continue
                    }

                    #- NET_LOG --------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "the pending_id_request variable is setted to: $pending_id_request\n"
                        #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                    send -i ${opt(connection_down)} -- "$expect_out(1,string)\n"
                    #- COMMON_LOG -----------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "SENDDN"
                        set log(msg) "$expect_out(1,string)\n"
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                }
                {^AT\*SENDIM.*$} {
                    set pending_id_request -2
                    #- NET_LOG --------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "inside AT*SENDIM\n"
                        #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                    set tmpMsg [forge_sendim $expect_out(1,string)]
                    if {${tmpMsg} != -1} {
                        send -i ${opt(connection_down)} -- "$tmpMsg\n"
                        #- COMMON_LOG -----------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "SENDDN"
                            set log(msg) "$tmpMsg\n"
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                    }
                }
                {^AT.*$} {
                    #- NET_LOG --------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "inside AT.*\n"
                        #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                    send -i ${opt(connection_down)} -- "$expect_out(1,string)\n"
                    #- COMMON_LOG -----------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "SENDDN"
                        set log(msg) "$expect_out(1,string)\n"
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                }
                {^NETDED$} {
                    #- NET_LOG --------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "inside NETFWD\n"
                        #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        set log(msg) "the net(forwardWithDst) FLAG is: $net(forwardWithDst)\n"
                        #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                    send -i ${opt(connection_up)} -- "$net(forwardWithDst)\r\n"
                    #- COMMON_LOG -----------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "SENDUP"
                        set log(msg) "OK\n"
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                }
                {^NETDED\ (ON|OFF)$} {
                    regexp {NETDED\ (ON|OFF)} $expect_out(1,string) -> net(forwardWithDst)

                    if {![info exists net(forwardWithDst)]} {
                        #- NET_LOG --------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "|-----"
                            set log(msg) "ERROR: net(forwardWithDst) doesn't exist\n"
                            #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                        exp_continue
                    }

                    #- NET_LOG --------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "inside FORWARDWD\n"
                        #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        set log(msg) "the net(forwardWithDst) FLAG is setted to: $net(forwardWithDst)\n"
                        #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                    send -i ${opt(connection_up)} -- "OK\r\n"
                    #- COMMON_LOG -----------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "SENDUP"
                        set log(msg) "OK\n"
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                }
                default {
                    regexp {(.*?)$} $expect_out(1,string) -> msg
                    #- COMMON_LOG -----------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "SENDDN"
                        set log(msg) "$expect_out(1,string)\n"
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                    send -i ${opt(connection_down)} -- "$expect_out(1,string)\n"
                    sleep 0.1 ;# Magic number :)
                    #- NET_LOG --------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "MSG_UNMANAGED: $expect_out(1,string)\n"
                        #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                }
            }
            exp_continue
        }
        -i ${opt(connection_down)} -re {(.*?)\r\n} {
            #- COMMON_LOG -----------------------------------------------------------------
                set log(timestamp) [clock seconds]
                set log(direction) "READDN"
                set log(msg) "$expect_out(1,string)\n"
                log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
            #------------------------------------------------------------------------------
            switch -regexp -- $expect_out(1,string) {
                {^RECVIM.*$} {
                    set pending_id_request -2
                    #- NET_LOG --------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "inside RECVIM\n"
                        #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                    regexp {RECVIM,\d+,\d+,[-+]?[0-9]*\.?[0-9]+,(ack|noack),(.+)} $expect_out(1,string) -> \
                        net(recvim_ack)

                    if {![info exists net(recvim_ack)]} {
                        #- NET_LOG --------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "|-----"
                            set log(msg) "ERROR: net(recvim_ack) doesn't exist\n"
                            #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                        exp_continue
                    }

                    if {[string compare ${net(recvim_ack)} ack] == 0} {
                        regexp {(RECVIM,\d+,\d+,\d+,(ack),\d+,[-+]?[0-9]*\.?[0-9]+,\d+,[-+]?[0-9]*\.?[0-9]+),(.+)$} $expect_out(1,string) -> \
                            net(recvim_msg_h)     \
                            net(recvim_ack)       \
                            net(recvim_payload)
                    } else {
                        regexp {(RECVIM,\d+,\d+,\d+,(noack),\d+,[-+]?[0-9]*\.?[0-9]+,\d+,[-+]?[0-9]*\.?[0-9]+),(.+)$} $expect_out(1,string) -> \
                            net(recvim_msg_h)     \
                            net(recvim_ack)       \
                            net(recvim_payload)
                    }

                    if {![info exists net(recvim_payload)]} {
                        #- NET_LOG --------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "|-----"
                            set log(msg) "ERROR: net(recvim_payload) doesn't exist\n"
                            #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                        exp_continue
                    }

                    switch -regexp -- $net(recvim_payload) {
                        {^F,.*$} {
                            #- NET_LOG --------------------------------------------------------------------
                                set log(timestamp) [clock seconds]
                                set log(direction) "-|----"
                                set log(msg) "the msg is handled with the FLOODING protocol\n"
                                #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            #------------------------------------------------------------------------------
                            set forwardim [forward_flooding_sendim $net(recvim_payload)]
                            if {$forwardim != -1 && $forwardim != -2} {
                                send -i ${opt(connection_down)} -- "$forwardim\n"
                                #- COMMON_LOG -----------------------------------------------------------------
                                    set log(timestamp) [clock seconds]
                                    set log(direction) "SENDDN"
                                    set log(msg) "$forwardim\n"
                                    log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                #------------------------------------------------------------------------------
                            } else {
                                #- NET_LOG --------------------------------------------------------------------
                                    set log(timestamp) [clock seconds]
                                    set log(direction) "-|----"
                                    set log(msg) "MSG not FORWARDED, because the forward_flooding_sendim FUNCTION had returned: ${forwardim}\n"
                                    #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                    log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                #------------------------------------------------------------------------------
                                #- COMMON_LOG -----------------------------------------------------------------
                                    set log(timestamp) [clock seconds]
                                    set log(direction) "DROP--"
                                    set log(msg) "$expect_out(1,string)\n"
                                    log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                #------------------------------------------------------------------------------
                            }
                        }
                        {^S,.*$} {
                            #- NET_LOG --------------------------------------------------------------------
                                set log(timestamp) [clock seconds]
                                set log(direction) "-|----"
                                set log(msg) "the msg is handled with the STATIC protocol\n"
                                #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            #------------------------------------------------------------------------------
                            set forwardim [forward_static_sendim $net(recvim_payload)]
                            if {$forwardim != -1 && $forwardim != -2} {
                                send -i ${opt(connection_down)} -- "$forwardim\n"
                                #- COMMON_LOG -----------------------------------------------------------------
                                    set log(timestamp) [clock seconds]
                                    set log(direction) "SENDDN"
                                    set log(msg) "$forwardim\n"
                                    log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                #------------------------------------------------------------------------------
                            } else {
                                #- NET_LOG --------------------------------------------------------------------
                                    set log(timestamp) [clock seconds]
                                    set log(direction) "-|----"
                                    set log(msg) "MSG not FORWARDED, because the forward_flooding_sendim FUNCTION had returned: ${forwardim}\n"
                                    #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                    log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                #------------------------------------------------------------------------------
                                #- COMMON_LOG -----------------------------------------------------------------
                                    set log(timestamp) [clock seconds]
                                    set log(direction) "DROP--"
                                    set log(msg) "$expect_out(1,string)\n"
                                    log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                #------------------------------------------------------------------------------
                            }
                        }
                        default {
                            #- NET_LOG --------------------------------------------------------------------
                                set log(timestamp) [clock seconds]
                                set log(direction) "-|----"
                                set log(msg) "WARNING: received an IM with an UNMANAGED PAYLOAD\n"
                                #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            #------------------------------------------------------------------------------
                            #- COMMON_LOG -----------------------------------------------------------------
                                set log(timestamp) [clock seconds]
                                set log(direction) "SENDUP"
                                set log(msg) "$expect_out(1,string)\n"
                                log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            #------------------------------------------------------------------------------
                            send -i ${opt(connection_up)} -- "$expect_out(1,string)\r\n"
                        }
                    }
                }
                {^\d+$} {
                    if {${pending_id_request} == -1} {
                        regexp {^(\d+)$} $expect_out(1,string) -> modem(id)

                        if {![info exists modem(id)]} {
                            #- NET_LOG --------------------------------------------------------------------
                                set log(timestamp) [clock seconds]
                                set log(direction) "|-----"
                                set log(msg) "ERROR: modem(id) doesn't exist\n"
                                #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            #------------------------------------------------------------------------------
                            exp_continue
                        }

                        #- NET_LOG --------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "|-----"
                            set log(msg) "the modem(id) variable is setted to: ${modem(id)}\n"
                            #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                    }
                    set pending_id_request -2
                    send -i ${opt(connection_up)} -- "$expect_out(1,string)\r\n"
                    #- COMMON_LOG -----------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "SENDUP"
                        set log(msg) "$expect_out(1,string)\n"
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                }
                {^OK$} {
                    if {${pending_id_request} > -1} {
                        set modem(id) ${pending_id_request}
                        #- NET_LOG --------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "|-----"
                            set log(msg) "the modem(id) variable is setted to: ${modem(id)}\n"
                            #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            set log(msg) "pending_id_request variable:         from \[${modem(id)}] to \[${pending_id_request}]\n"
                            #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                    }
                    set pending_id_request -2
                    send -i ${opt(connection_up)} -- "$expect_out(1,string)\r\n"
                    #- COMMON_LOG -----------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "SENDUP"
                        set log(msg) "$expect_out(1,string)\n"
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                }
                default {
                    set pending_id_request -2
                    regexp {(.*?)$} $expect_out(1,string) -> msg
                    send -i ${opt(connection_up)} -- "$expect_out(1,string)\r\n"
                    #- COMMON_LOG -----------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "SENDUP"
                        set log(msg) "$expect_out(1,string)\n"
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                    #- NET_LOG --------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "MSG_UNMANAGED: $expect_out(1,string)\n"
                        #logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                }
            }
            exp_continue
        }
        -i any_spawn_id eof {
            puts "NET stopped, reason: $expect_out(spawn_id) closes"
            exit 1
        }
    }
}
vwait opt(forever)

