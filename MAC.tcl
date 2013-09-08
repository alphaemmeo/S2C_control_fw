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

# @name_file:   ctrl_MAC.tcl
# @author:      Ivano Calabrese, Giovanni Toso
# @last_update: 2013.07.10
# --
# @brief_description: MAC module
#
# the next line restarts using tclsh \
exec expect -f "$0" -- "$@"

source ./MAC_config.tcl
source ./MAC_proc.tcl
source ./COMMON_proc.tcl

# Expect variables
set timeout -1

if {${opt(debug)}} {
    puts stdout "* MAC:             starting"
}

#Spawn a connection: UP interface
if {${opt(user_interaction)} == 1} {
    set opt(connection_up) $user_spawn_id
    fconfigure ${opt(connection_up)} -translation binary
    if {${opt(debug)}} {
        puts stdout "Connection up established."
    }
} else {
    socket -server Accept ${up(port)}
}

#Spawn a connection: DOWN interface
log_user 0
spawn -open [socket ${down(ip)} ${down(port)}]
set opt(connection_down) ${spawn_id}
fconfigure ${opt(connection_down)} -translation binary
#- MAC_LOG ---------------------------------------------------------------------
    set log(timestamp) [clock seconds]
    set log(direction) "|    |"
    set log(msg) "Connection down established\n"
    #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
    log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
    set log(msg) "Down connection with IP: ${down(ip)} and Port: ${down(port)}\n"
    #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
    log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
#------------------------------------------------------------------------------
if {${opt(debug)}} {
    puts stdout "* Down connection: established"
}

#send -i ${opt(connection_down)} -- "ATZ4\n"
##- MAC_LOG ---------------------------------------------------------------------
    #set log(timestamp) [clock seconds]
    #set log(direction) "|-----"
    #set log(msg) "send to modem ATZ4 command"
    #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
##------------------------------------------------------------------------------

log_user 1

#- MAIN LOOP ------------------------------------------------------------------
proc main_loop { } {
    #global log_commands_name
    global opt modem mac

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
                    #---this scope is for the Evologics MODEM.---
                    set pending_id_request -1

                    #- MAC_LOG ---------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "inside AT?AL\n"
                        #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
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
                    #---this scope is for the Evologics MODEM.---
                    regexp {^AT\!AL([0-9]+)$} $expect_out(1,string) -> pending_id_request

                    if {![info exists pending_id_request]} {
                        #- MAC_LOG --------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "-----|"
                            set log(msg) "ERROR: pending_id_request doesn't exist\n"
                            #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                        exp_continue
                    }

                    #- MAC_LOG ---------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "the pending_id_request variable is setted to: $pending_id_request\n"
                        #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
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
                {^AT\*SENDIM.*$} { ;# Request for modem ID
                    #---this scope is for the UnderWater NETWORK.---
                    set pending_id_request -1

                    regexp {(AT\*SENDIM,(\d+),(\d+),(ack|noack),(F|S),(\d+),(\d+),(.*))$} $expect_out(1,string) -> \
                        mac(sendim_msg)     \
                        mac(sendim_length)  \
                        mac(sendim_dst)     \
                        mac(sendim_ack)     \
                        mac(input_protocol) \
                        mac(src)            \
                        mac(sn)             \
                        mac(input_command)

                    if {![info exists mac(src)] && ![info exists mac(sn)]} {
                        #- MAC_LOG --------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "-----|"
                            set log(msg) "ERROR: mac(src) && mac(sn) don't exist\n"
                            #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                        exp_continue
                    }

                    if {"$mac(src).$mac(sn)" == $mac(lastSN)} {
                        set mac(OK_flag) "no"
                    }
                    #- MAC_LOG ---------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "the mac(OK_flag) variable is setted to: $mac(OK_flag)\n"
                        #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------

                    if {$mac(randomRange) > 0} {
                        set sleepValue [expr {$mac(randomRange) * rand()}]
                        sleep $sleepValue
                        #- MAC_LOG ---------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "|-----"
                            set log(msg) "The DELAY option is ON. Its value is: $sleepValue. RANGE:\[0 - $mac(randomRange)\]\n"
                            #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                    }

                    send -i ${opt(connection_down)} -- "$expect_out(1,string)\n"
                    #- COMMON_LOG -----------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "SENDDN"
                        set log(msg) "$expect_out(1,string)\n"
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                }
                {^AT.*$} { ;# Set modem ID
                    #---this scope is for the Evologics MODEM.---
                    #- MAC_LOG ---------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "inside AT.*\n"
                        #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
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
                {^MACDELAY\ [0-9]*\.?[0-9]+$} {
                    regexp {MACDELAY\ (([0-9]*)\.?([0-9]+))} $expect_out(1,string) -> mac(randomRange)

                    if {![info exists mac(randomRange)]} {
                        #- MAC_LOG --------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "-----|"
                            set log(msg) "ERROR: mac(randomRange) doesn't exist\n"
                            #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                        exp_continue
                    }

                    #- MAC_LOG ---------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "inside RANDSEND\n"
                        #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        set log(msg) "the mac(randomRange) variable is setted to: $mac(randomRange)\n"
                        #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
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
                {^MACDELAY$} {
                    #- MAC_LOG ---------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "MACDELAY\n"
                        #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                    send -i ${opt(connection_up)} -- "$mac(randomRange)\r\n"
                    #- COMMON_LOG -----------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "SENDUP"
                        set log(msg) "$mac(randomRange)\n"
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                }
                default {
                    send -i ${opt(connection_down)} -- "$expect_out(1,string)\n"
                    #- COMMON_LOG -----------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "SENDDN"
                        set log(msg) "$expect_out(1,string)\n"
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                    #- MAC_LOG ---------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "MSG_UNMANAGED: $expect_out(1,string)\n"
                        #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
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
                    #- MAC_LOG --------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "inside RECVIM\n"
                        #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                    regexp {RECVIM,\d+,\d+,[-+]?[0-9]*\.?[0-9]+,(ack|noack),(.+)} $expect_out(1,string) -> \
                        mac(recvim_ack)

                    if {![info exists mac(recvim_ack)]} {
                        #- MAC_LOG --------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "-----|"
                            set log(msg) "ERROR: mac(recvim_ack) doesn't exist\n"
                            #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                        exp_continue
                    }

                    set pending_id_request -2
                    if {[string compare ${mac(recvim_ack)} ack] == 0} {
                        regexp {(RECVIM,(\d+),(\d+),(\d+),ack,(\d+),([-+]?[0-9]*\.?[0-9]+),(\d+),([-+]?[0-9]*\.?[0-9]+),(.+))$} $expect_out(1,string) -> \
                            mac(recvim_msg)       \
                            mac(recvim_length)    \
                            mac(recvim_src)       \
                            mac(recvim_dst)       \
                            mac(recvim_bitrate)   \
                            mac(recvim_rssi)      \
                            mac(recvim_integrity) \
                            mac(recvim_vel)       \
                            mac(recvim_payload)
                    } else {
                        regexp {(RECVIM,(\d+),(\d+),(\d+),noack,(\d+),([-+]?[0-9]*\.?[0-9]+),(\d+),([-+]?[0-9]*\.?[0-9]+),(.+))$} $expect_out(1,string) -> \
                            mac(recvim_msg)       \
                            mac(recvim_length)    \
                            mac(recvim_src)       \
                            mac(recvim_dst)       \
                            mac(recvim_bitrate)   \
                            mac(recvim_rssi)      \
                            mac(recvim_integrity) \
                            mac(recvim_vel)       \
                            mac(recvim_payload)
                    }

                    #- MULTIPATH_LOG ------------------------------
                        set log(timestamp) [clock seconds]
                        set log(msg) $expect_out(1,string)
                        logMultiPath ${log(timestamp)} ${log(msg)}
                        send -i ${opt(connection_down)} -- "AT?P\n"
                        #- MAC_LOG --------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "|-----"
                            set log(msg) "send to modem a AT?P command\n"
                            #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                    #----------------------------------------------

                    if {![info exists mac(recvim_dst)] && ![info exists mac(recvim_payload)]} {
                        #- MAC_LOG --------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "|-----"
                            set log(msg) "ERROR: mac(recvim_dst) && mac(recvim_payload) don't exist\n"
                            #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                        exp_continue
                    }

                    if {$mac(recvim_dst) != $modem(id) && $mac(recvim_dst) != 255} {
                        #- MAC_LOG --------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "|-----"
                            set log(msg) "msg for $mac(recvim_dst), my ID is: $modem(id). MSG_DROPPED\n"
                            #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                        exp_continue
                    }

                    switch -regexp -- ${mac(recvim_payload)} {
                        {^F,.*$} {
                            regexp {F,(\d+),(\d+),(.*)$} $mac(recvim_payload) -> flooding_p(src) flooding_p(sn) ->

                            if {![info exists flooding_p(src)] && ![info exists flooding_p(sn)]} {
                                #- MAC_LOG --------------------------------------------------------------------
                                    set log(timestamp) [clock seconds]
                                    set log(direction) "|-----"
                                    set log(msg) "ERROR: flooding_p(src) && flooding_p(sn) don't exist\n"
                                    #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                    log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                #------------------------------------------------------------------------------
                                exp_continue
                            }

                            set mac(lastSN) "${flooding_p(src)}.${flooding_p(sn)}"
                            send -i ${opt(connection_up)} -- "$expect_out(1,string)\r\n"
                            #- COMMON_LOG -----------------------------------------------------------------
                                set log(timestamp) [clock seconds]
                                set log(direction) "SENDUP"
                                set log(msg) "$expect_out(1,string)\n"
                                log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            #------------------------------------------------------------------------------
                            #- MAC_LOG --------------------------------------------------------------------
                                set log(timestamp) [clock seconds]
                                set log(direction) "|-----"
                                set log(msg) "the mac(lastSN) variable is setted to: $mac(lastSN)\n"
                                #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            #------------------------------------------------------------------------------
                        }
                        {^S,.*$} {
                            regexp {S,(\d+),(\d+),(.*)$} $mac(recvim_payload) -> static_p(src) static_p(sn) ->

                            if {![info exists static_p(src)] && ![info exists static_p(sn)]} {
                                #- MAC_LOG --------------------------------------------------------------------
                                    set log(timestamp) [clock seconds]
                                    set log(direction) "|-----"
                                    set log(msg) "ERROR: static_p(src) && static_p(sn) don't exist\n"
                                    #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                    log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                #------------------------------------------------------------------------------
                                exp_continue
                            }

                            set mac(lastSN) "${static_p(src)}.${static_p(sn)}"
                            send -i ${opt(connection_up)} -- "$expect_out(1,string)\r\n"
                            #- COMMON_LOG -----------------------------------------------------------------
                                set log(timestamp) [clock seconds]
                                set log(direction) "SENDUP"
                                set log(msg) "$expect_out(1,string)\n"
                                log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            #------------------------------------------------------------------------------
                            #- MAC_LOG --------------------------------------------------------------------
                                set log(timestamp) [clock seconds]
                                set log(direction) "-----|"
                                set log(msg) "the mac(lastSN) variable is setted to: $mac(lastSN)\n"
                                #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            #------------------------------------------------------------------------------
                        }
                        default {
                            #- COMMON_LOG -----------------------------------------------------------------
                                set log(timestamp) [clock seconds]
                                set log(direction) "SENDUP"
                                set log(msg) "$expect_out(1,string)\n"
                                log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            #------------------------------------------------------------------------------
                            #- MAC_LOG --------------------------------------------------------------------
                                set log(timestamp) [clock seconds]
                                set log(direction) "-----|"
                                set log(msg) "WARNING: received an IM with an UNMANAGED PAYLOAD\n"
                                #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            #------------------------------------------------------------------------------
                            send -i ${opt(connection_up)} -- "$expect_out(1,string)\r\n"
                        }
                    }
                }
                {^\d+\ *\d+\ *} {
                    #- MULTIPATH_LOG ------------------------------
                        #- MAC_LOG --------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "|-----"
                            set log(msg) "an AT?P answer is matched\n"
                            #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(msg) $expect_out(1,string)
                        #regexp {^(\d+)$} $expect_out(1,string) -> modem(id)
                        logMultiPath ${log(timestamp)} ${log(msg)}
                    #----------------------------------------------
                }
                {^\d+$} {
                    if {${pending_id_request} == -1} {
                        regexp {^(\d+)$} $expect_out(1,string) -> modem(id)
                    }

                    if {![info exists modem(id)]} {
                        #- MAC_LOG --------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "|-----"
                            set log(msg) "ERROR: modem(id) doesn't exist\n"
                            #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                        exp_continue
                    }

                    #- MAC_LOG --------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "the modem(id) variable is setted to: ${modem(id)}\n"
                        #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
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
                        set pending_id_request -2
                        #- MAC_LOG --------------------------------------------------------------------
                            set log(timestamp) [clock seconds]
                            set log(direction) "|-----"
                            set log(msg) "the modem(id) variable is setted to: ${pending_id_request}\n"
                            #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            set log(msg) "pending_id_request variable:         from \[${modem(id)}] to \[${pending_id_request}]\n"
                            #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        #------------------------------------------------------------------------------
                    }
                    set pending_id_request -2
                    switch -exact -- $mac(OK_flag) {
                        yes {
                            send -i ${opt(connection_up)} -- "$expect_out(1,string)\r\n"
                            #- COMMON_LOG -----------------------------------------------------------------
                                set log(timestamp) [clock seconds]
                                set log(direction) "SENDUP"
                                set log(msg) "$expect_out(1,string)\n"
                                log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            #------------------------------------------------------------------------------
                        }
                        no  {
                            #- MAC_LOG --------------------------------------------------------------------
                                set log(timestamp) [clock seconds]
                                set log(direction) "|-----"
                                set log(msg) "didn't send to up interface this msg: $expect_out(1,string)\n"
                                #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                                log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                            #------------------------------------------------------------------------------
                        }
                    }
                }
                default {
                    set pending_id_request -2
                    send -i ${opt(connection_up)} -- "$expect_out(1,string)\r\n"
                    #- COMMON_LOG -----------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "SENDUP"
                        #set log(msg) "MSG_UNMANAGED: $expect_out(1,string)\n"
                        set log(msg) "$expect_out(1,string)\n"
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                    #- MAC_LOG --------------------------------------------------------------------
                        set log(timestamp) [clock seconds]
                        set log(direction) "|-----"
                        set log(msg) "MSG_UNMANAGED: $expect_out(1,string)\n"
                        #logMac ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                        log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    #------------------------------------------------------------------------------
                }
            }
            exp_continue
        }
        -i any_spawn_id eof {
            puts "MAC stopped, reason: $expect_out(spawn_id) closes"
            exit 1
        }
    }
}
vwait opt(forever)

