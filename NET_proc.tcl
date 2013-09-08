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

# @name_file:   NET_proc.tcl
# @author:      Ivano Calabrese, Giovanni Toso
# @last_update: 2013.07.10
# --
# @brief_description: Procedure file for the application module
#
# the next line restarts using tclsh \
exec expect -f "$0" -- "$@"

proc Accept {sock addr port} {
    global opt up

    log_user 0
    spawn -open $sock
    set opt(connection_up) ${spawn_id}
    fconfigure ${opt(connection_up)} -translation binary

    #- NET_LOG --------------------------------------------------------------------
        set log(timestamp) [clock seconds]
        set log(direction) "|    |"
        set log(msg) "Connection up established. SPAWN_ID: $opt(connection_up)"
        logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
        set log(msg) "Up connection with IP: ${up(ip)} and Port: ${up(port)}"
        logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
    #------------------------------------------------------------------------------

    if {${opt(debug)}} {
        puts stdout "* Up connection:   established"
    }
    log_user 1
    main_loop
}

proc logNet {input_timestamp input_module input_direction input_string} {
    global opt
    set disk_files [list "${input_module}.log"]
    #set disk_files [list "extra_NET.log"]
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
            puts stderr ${res}
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

proc forge_sendim {raw_msg} {
    global net opt modem
    set net(my_sn) [expr ${net(my_sn)} + 1]
    set net(sn_ID${modem(id)}) ${net(my_sn)}

    regexp {(AT\*SENDIM,(\d+),(\d+),(ack|noack),(.*))$} $raw_msg -> \
        sendim_msg          \
        sendim_length       \
        sendim_dst          \
        sendim_ack          \
        sendim_payload

    if {![info exists sendim_payload]} {
        #- NET_LOG --------------------------------------------------------------------
            set log(timestamp) [clock seconds]
            set log(direction) "|-----"
            set log(msg) "ERROR: sendim_payload doesn't exist"
            logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
        #------------------------------------------------------------------------------
        return 1
    }

    switch -regexp -- ${sendim_payload} {
        {^F,.*$} {
            regexp {F,(\d+),(\d+),((\d\ ?)+)?,(\d+),(\d+),(.*)$} ${sendim_payload} -> \
                flooding_p(sendim_src)      \
                flooding_p(sendim_sn)       \
                flooding_p(sendim_dst_list) \
                ->                          \
                flooding_p(sendim_ttlATsrc) \
                flooding_p(sendim_ttl)      \
                flooding_p(send_command)


            if {![info exists flooding_p(sendim_src)] && ![info exists flooding_p(sendim_ttl)] && ![info exists flooding_p(sendim_dst_list)]} {
                #- NET_LOG --------------------------------------------------------------------
                    set log(timestamp) [clock seconds]
                    set log(direction) "|-----"
                    set log(msg) "ERROR: flooding_p(sendim_src) && flooding_p(sendim_ttl) && flooding_p(sendim_dst_list) don't exist"
                    logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                #------------------------------------------------------------------------------
                return 1
            }

            if {${flooding_p(sendim_src)} != ${modem(id)}} {
                #- NET_LOG --------------------------------------------------------------------
                    set log(timestamp) [clock seconds]
                    set log(direction) "|-----"
                    set log(msg) "ERROR: the sendim_src and modem(id) variables are NOT equal Maybe the modem(id) variable isn't setted"
                    logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                #------------------------------------------------------------------------------
                #send -i ${opt(connection_up)} -- "ERROR_MODEM_ID\r\n"
                #- COMMON_LOG -----------------------------------------------------------------
                    set log(timestamp) [clock seconds]
                    set log(direction) "SENDUP"
                    set log(msg) "ERROR_MODEM_ID\r\n"
                    log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                #------------------------------------------------------------------------------
                return -1
            }
            if {$flooding_p(sendim_ttl) < 1} {
                #- NET_LOG --------------------------------------------------------------------
                    set log(timestamp) [clock seconds]
                    set log(direction) "|-----"
                    set log(msg) "ERROR: the msg TTL is 0. MSG_NOTSENT"
                    logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                #------------------------------------------------------------------------------
                #send -i ${opt(connection_up)} -- "WARNING! the TTL msg is 0. MSG_NOTSENT!!!\r\n"
                #- COMMON_LOG -----------------------------------------------------------------
                    set log(timestamp) [clock seconds]
                    set log(direction) "DROP--"
                    set log(msg) "TTL_MSG is 0, MSG_DROPPED\r\n"
                    log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                #------------------------------------------------------------------------------
                return -1
            }
            if {[string compare ${net(forwardWithDst)} "ON"] == 0 &&  [llength ${flooding_p(sendim_dst_list)}] < 1} {
                #- NET_LOG --------------------------------------------------------------------
                    set log(timestamp) [clock seconds]
                    set log(direction) "|-----"
                    set log(msg) "the length of  the destinations list is: [llength ${flooding_p(sendim_dst_list)}]. MSG_NOTFORWARDED"
                    logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    set log(msg) "the net(forwardWithDst) variable is set to ${net(forwardWithDst)}. MSG_NOTFORWARDED"
                    logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                #------------------------------------------------------------------------------
                return -1
            }
            set flooding_p(sendim_ack)     $sendim_ack
            set flooding_p(sendim_dst)     $sendim_dst
            set flooding_p(sendim_data)    "F,${flooding_p(sendim_src)},${flooding_p(sendim_sn)},${flooding_p(sendim_dst_list)},${flooding_p(sendim_ttlATsrc)},${flooding_p(sendim_ttl)},${flooding_p(send_command)}"
            set flooding_p(sendim_length)  [string length ${flooding_p(sendim_data)}]
            set flooding_p(sendim_msg)     "AT*SENDIM,${flooding_p(sendim_length)},${flooding_p(sendim_dst)},${flooding_p(sendim_ack)},${flooding_p(sendim_data)}"
            return ${flooding_p(sendim_msg)}
        }
        {^S,.*$} {
            regexp {S,(\d+),(\d+),((\d\ ?)+)?,(\d+),((\d\ ?)+),(.*)$} ${sendim_payload} -> \
                static_p(sendim_src)         \
                static_p(sendim_sn)          \
                static_p(sendim_dst_list)    \
                ->                           \
                static_p(sendim_routePath_l) \
                static_p(sendim_routePath)   \
                ->                           \
                static_p(send_command)


            if {![info exists static_p(sendim_src)] && ![info exists static_p(sendim_routePath)] && ![info exists static_p(sendim_dst_list)]} {
                #- NET_LOG --------------------------------------------------------------------
                    set log(timestamp) [clock seconds]
                    set log(direction) "|-----"
                    set log(msg) "ERROR: static_p(sendim_src) && static_p(sendim_routePath) && static_p(sendim_dst_list) don't exist"
                    logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                #------------------------------------------------------------------------------
                return 1
            }

            set static_p(sendim_ack)     $sendim_ack
            if {[llength $static_p(sendim_routePath)] < 1} {
                #- NET_LOG --------------------------------------------------------------------
                    set log(timestamp) [clock seconds]
                    set log(direction) "|-----"
                    set log(msg) "ERROR: the ROUTE PATH length is 0. MSG_NOTSENT"
                    logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                #------------------------------------------------------------------------------
                #send -i ${opt(connection_up)} -- "WARNING! the ROUTE PATH isn't setted!!!\r\n"
                #- COMMON_LOG -----------------------------------------------------------------
                    set log(timestamp) [clock seconds]
                    set log(direction) "DROP--"
                    set log(msg) "ROUTE_PATH_MSG is NULL, MSG_DROPPED\r\n"
                    log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                #------------------------------------------------------------------------------
                return -1
            }
            if {[string compare ${net(forwardWithDst)} "ON"] == 0 &&  [llength ${static_p(sendim_dst_list)}] < 1} {
                #- NET_LOG --------------------------------------------------------------------
                    set log(timestamp) [clock seconds]
                    set log(direction) "|-----"
                    set log(msg) "the length of the destinations list is: [llength ${static_p(sendim_dst_list)}]. MSG_NOTFORWARDED"
                    logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                    set log(msg) "the net(forwardWithDst) variable is set to: ${net(forwardWithDst)}. MSG_NOTFORWARDED"
                    logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                #------------------------------------------------------------------------------
                return -1
            }
            set static_p(sendim_dst)       [lindex $static_p(sendim_routePath) 0]
            set static_p(sendim_data)      "S,${static_p(sendim_src)},${static_p(sendim_sn)},${static_p(sendim_dst_list)},${static_p(sendim_routePath_l)},${static_p(sendim_routePath)},${static_p(send_command)}"
            set static_p(sendim_length)    [string length ${static_p(sendim_data)}]
            set static_p(sendim_msg)       "AT*SENDIM,${static_p(sendim_length)},${static_p(sendim_dst)},${static_p(sendim_ack)},${static_p(sendim_data)}"
            return ${static_p(sendim_msg)}
        }
    }
}

proc forward_flooding_sendim {in_msg} {
    global net
    global flooding_p opt modem
    regexp {F,(\d+),(\d+),((\d\ ?)+)?,(\d+),(\d+),(.*)$} $in_msg -> \
        flooding_p(src)             \
        flooding_p(sn)              \
        flooding_p(h_dst)           \
        ->                          \
        flooding_p(sendim_ttlATsrc) \
        flooding_p(ttl_msg)         \
        flooding_p(payload)


    if {![info exists flooding_p(src)] && ![info exists flooding_p(sn)] && ![info exists flooding_p(ttl_msg)] && ![info exists flooding_p(h_dst)]} {
        #- NET_LOG --------------------------------------------------------------------
            set log(timestamp) [clock seconds]
            set log(direction) "|-----"
            set log(msg) "ERROR: flooding_p(src) && flooding_p(sn) && flooding_p(ttl_msg) && flooding_p(h_dst) don't exist"
            logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
        #------------------------------------------------------------------------------
        return 1
    }

    if {[info exists net(sn_ID${flooding_p(src)})]} {
        if {${flooding_p(sn)} <= $net(sn_ID${flooding_p(src)})} {
            #- NET_LOG --------------------------------------------------------------------
                set log(timestamp) [clock seconds]
                set log(direction) "|-----"
                set log(msg) "ERROR: the ${flooding_p(src)}.${flooding_p(sn)} exist. MSG_DROPPED"
                logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
            #------------------------------------------------------------------------------
            return -1
        }
    }
    set flooding_p(ttl_msg) [expr $flooding_p(ttl_msg) - 1]
    #- NET_LOG --------------------------------------------------------------------
        set log(timestamp) [clock seconds]
        set log(direction) "|-----"
        set log(msg) "TTL is decreased. flooding_p(ttl_msg) = $flooding_p(ttl_msg)"
        logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
    #------------------------------------------------------------------------------
    if {$flooding_p(h_dst) == 255} {
        #- NET_LOG --------------------------------------------------------------------
            set log(timestamp) [clock seconds]
            set log(direction) "|-----"
            set log(msg) "my ID is: $modem(id) so I'm ONE of the RECEIVERS"
            logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
            set log(msg) "other dst address: $flooding_p(h_dst)"
            logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
        #------------------------------------------------------------------------------
        set net(sendUPmsg) 1
    }
    if {[lsearch $flooding_p(h_dst) $modem(id)] > -1} {
        set flooding_p(h_dst) "[lreplace $flooding_p(h_dst) [lsearch $flooding_p(h_dst) $modem(id)] [lsearch $flooding_p(h_dst) $modem(id)]]"
        if {[llength $flooding_p(h_dst)] == 0} {
            #- NET_LOG --------------------------------------------------------------------
                set log(timestamp) [clock seconds]
                set log(direction) "|-----"
                set log(msg) "my ID is: $modem(id) so I'm the last RECEIVER"
                logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
            #------------------------------------------------------------------------------
            set net(sn_ID${flooding_p(src)}) ${flooding_p(sn)}
        } else {
            #- NET_LOG --------------------------------------------------------------------
                set log(timestamp) [clock seconds]
                set log(direction) "|-----"
                set log(msg) "my ID is: $modem(id) so I'm ONE of the RECEIVERS"
                logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                set log(msg) "other dst address: $flooding_p(h_dst)"
                logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
            #------------------------------------------------------------------------------
        }
        set net(sendUPmsg) 1
    }
    set net(sn_ID${flooding_p(src)}) ${flooding_p(sn)}
    #set tmp_my_src_sn "${flooding_p(src)}.${flooding_p(sn)}"
    #set input_dst     [string trim ${flooding_p(h_dst)} { }]
    set sendim_data   "F,${flooding_p(src)},${flooding_p(sn)},${flooding_p(h_dst)},${flooding_p(sendim_ttlATsrc)},${flooding_p(ttl_msg)},${flooding_p(payload)}"
    #TODO: ack setting isn't must be hard-coded
    set sendim_ack    $net(recvim_ack)
    set sendim_dst    "255"
    set sendim_length [string length ${sendim_data}]
    set sendim_msg    "AT*SENDIM,${sendim_length},${sendim_dst},${sendim_ack},${sendim_data}"
    #- NET_LOG --------------------------------------------------------------------
        set log(timestamp) [clock seconds]
        set log(direction) "|-----"
        set log(msg) "rc.sn salved: [array names net -regexp {^sn_ID}]"
        logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
    #------------------------------------------------------------------------------
    if {$net(sendUPmsg) == 1} {
        send -i ${opt(connection_up)} -- "${net(recvim_msg_h)},${sendim_data}\r\n"
        #- COMMON_LOG -----------------------------------------------------------------
            set log(timestamp) [clock seconds]
            set log(direction) "SENDUP"
            set log(msg) "${net(recvim_msg_h)},${sendim_data}\r\n"
            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
        #------------------------------------------------------------------------------
        #send -i ${opt(connection_up)} -- "${net(recvim_msg_h)},${in_msg}\r\n"
        set net(sendUPmsg) 0
    }
    if {${flooding_p(ttl_msg)} < 1} {
        #- NET_LOG --------------------------------------------------------------------
            set log(timestamp) [clock seconds]
            set log(direction) "|-----"
            set log(msg) "msg TTL: ${flooding_p(ttl_msg)}. MSG_NOTFORWARDED"
            logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
        #------------------------------------------------------------------------------
        return -2
    }
    if {[string compare ${net(forwardWithDst)} "ON"] == 0 &&  [llength ${flooding_p(h_dst)}] < 1} {
        #- NET_LOG --------------------------------------------------------------------
            set log(timestamp) [clock seconds]
            set log(direction) "|-----"
            set log(msg) "the length of the destinations list is: [llength ${flooding_p(h_dst)}]. MSG_NOTFORWARDED"
            logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
            set log(msg) "the net(forwardWithDst) variable is set to: ${net(forwardWithDst)}. MSG_NOTFORWARDED"
            logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
        #------------------------------------------------------------------------------
        return -2
    }
    return ${sendim_msg}
}


proc forward_static_sendim {in_msg} {
    global net
    global flooding_p opt modem
    regexp {S,(\d+),(\d+),((\d\ ?)+)?,(\d+),((\d\ ?)+),(.*)$} $in_msg -> \
        static_p(recvim_src)         \
        static_p(recvim_sn)          \
        static_p(recvim_dst_list)    \
        ->                           \
        static_p(sendim_routePath_l) \
        static_p(recvim_routePath)   \
        ->                           \
        static_p(payload)


    if {![info exists static_p(recvim_src)] && ![info exists static_p(recvim_sn)] && ![info exists static_p(recvim_routePath)]} {
        #- NET_LOG --------------------------------------------------------------------
            set log(timestamp) [clock seconds]
            set log(direction) "|-----"
            set log(msg) "ERROR: static_p(recvim_src) && static_p(recvim_sn) && static_p(recvim_routePath) don't exist"
            logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
        #------------------------------------------------------------------------------
        return 1
    }

    #set static_p(sendim_ack)     "noack"


    #if {[info exists net(sn_ID${static_p(recvim_src)})]} {
    #    if {${static_p(recvim_sn)} <= $net(sn_ID${static_p(recvim_src)})} {
    #        if {${opt(debug)}} {
    #            puts stdout " * \[NET]\[static]: the ${static_p(recvim_src)}.${static_p(recvim_sn)} exist. MSG_DROPPED"
    #        }
    #        return -1
    #    }
    #}

    set static_p(recvim_routePath) [lreplace $static_p(recvim_routePath) 0 0]
    if {[lindex $static_p(recvim_dst_list) 0] == $modem(id)} {
        if {[llength $static_p(recvim_dst_list)] == 1} {
            #- NET_LOG --------------------------------------------------------------------
                set log(timestamp) [clock seconds]
                set log(direction) "|-----"
                set log(msg) "my ID is: $modem(id) and I'm the last RECEIVER"
                logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
                set log(msg) "the corrent route Path list is: $static_p(recvim_routePath)"
                logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
            #------------------------------------------------------------------------------
            set static_p(recvim_dst_list) [lreplace $static_p(recvim_dst_list) 0 0]
            set net(sn_ID${static_p(recvim_src)}) ${static_p(recvim_sn)}
            set net(sendUPmsg) 1
            #return -2
        } else {
            set static_p(recvim_dst_list) [lreplace $static_p(recvim_dst_list) 0 0]
            #- NET_LOG --------------------------------------------------------------------
                set log(timestamp) [clock seconds]
                set log(direction) "|-----"
                set log(msg) "my ID is: $modem(id) so I'm ONE of the RECEIVERS"
                logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
            #------------------------------------------------------------------------------
            #send -i ${opt(connection_up)} -- "${net(recvim_msg)}\r\n"
            set net(sendUPmsg) 1
        }
    }
    #TODO: ack setting isn't must be hard-coded
    set static_p(recvim_ack)       $net(recvim_ack)
    set static_p(recvim_dst)       [lindex $static_p(recvim_routePath) 0]
    set static_p(recvim_data)      "S,${static_p(recvim_src)},${static_p(recvim_sn)},${static_p(recvim_dst_list)},${static_p(sendim_routePath_l)},${static_p(recvim_routePath)},${static_p(payload)}"
    set static_p(recvim_length)    [string length ${static_p(recvim_data)}]
    set static_p(recvim_msg)       "AT*SENDIM,${static_p(recvim_length)},${static_p(recvim_dst)},${static_p(recvim_ack)},${static_p(recvim_data)}"
    #- NET_LOG --------------------------------------------------------------------
        set log(timestamp) [clock seconds]
        set log(direction) "|-----"
        set log(msg) "rc.sn salved                 : [array names net -regexp {^sn_ID}]"
        logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
        set log(msg) "static_p(sendim_routePath_l) : ${static_p(sendim_routePath_l)}"
        logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
        set log(msg) "static_p(recvim_routePath)   : ${static_p(recvim_routePath)}"
        logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
    #------------------------------------------------------------------------------
    if {$net(sendUPmsg) == 1} {
        send -i ${opt(connection_up)} -- "${net(recvim_msg_h)},${static_p(recvim_data)}\r\n"
        #- COMMON_LOG -----------------------------------------------------------------
            set log(timestamp) [clock seconds]
            set log(direction) "SENDUP"
            set log(msg) "${net(recvim_msg_h)},${static_p(recvim_data)}\r\n"
            log_string ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
        #------------------------------------------------------------------------------
        #send -i ${opt(connection_up)} -- "${net(recvim_msg_h)},${in_msg}\r\n"
        set net(sendUPmsg) 0
    }
    if {[llength $static_p(recvim_routePath)] < 1} {
        #- NET_LOG --------------------------------------------------------------------
            set log(timestamp) [clock seconds]
            set log(direction) "|-----"
            set log(msg) "the route Path length is: [llength $static_p(recvim_routePath)]. MSG_NOTFORWARDED"
            logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
        #------------------------------------------------------------------------------
        return -2
    }
    if {[string compare ${net(forwardWithDst)} "ON"] == 0 &&  [llength ${static_p(recvim_dst_list)}] < 1} {
        #- NET_LOG --------------------------------------------------------------------
            set log(timestamp) [clock seconds]
            set log(direction) "|-----"
            set log(msg) "the length of the destinations list is: ${static_p(recvim_dst_list)}. MSG_NOTFORWARDED"
            logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
            set log(msg) "the net(forwardWithDst) variable is set to: ${net(forwardWithDst)}. MSG_NOTFORWARDED"
            logNet ${log(timestamp)} ${opt(module_name)} ${log(direction)} ${log(msg)}
        #------------------------------------------------------------------------------
        return -2
    }
    return ${static_p(recvim_msg)}
}

