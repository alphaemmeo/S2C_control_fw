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
# The next line restarts using tclsh \
exec expect -f "$0" -- "$@"

proc Accept {sock addr port} {
    global opt

    log_user 0
    spawn -open ${sock}
    set opt(connection_up) ${spawn_id}
    fconfigure ${opt(connection_up)} -translation binary
    if {${opt(verbose)}} {
        debug_app "UP connection ${addr}:${port}\n"
    }
    log_user 1
    main_loop
}

proc send_up {msg} {
    global opt

    log_string [clock seconds] ${opt(module_name)} "SENDUP" "${msg}"
    send -i ${opt(connection_up)} -- ${msg}
}

proc send_down {msg} {
    global opt

    log_string [clock seconds] ${opt(module_name)} "SENDDN" "${msg}"
    send -i ${opt(connection_down)} -- ${msg}
}

proc send_down_nsc {msg} {
    global opt

    log_string [clock seconds] ${opt(module_name)} "SENDDN" "${msg}"
    send -i ${opt(connection_down_nsc)} -- ${msg}
}

proc debug_app {msg} {
    global opt

    if {${opt(verbose)}} {
        puts -nonewline stdout "* ${msg}"
    }
    log_string [clock seconds] ${opt(module_name)} "|-----" "${msg}"
}

proc reset_pendings {} {
    global opt

    set opt(pending_id_request)    -2
    set opt(pending_power_request) -2
}

proc update_sendim_counter_file {sendim_counter} {
    global opt

    if {[file exists ${opt(file_sendim_counter)}] != 1} {
        exec touch ${opt(file_sendim_counter)}
    }
    if {[catch {open ${opt(file_sendim_counter)} "w+"} res]} {
        puts stderr ${res}
        sleep 1
        exec rm -f ${opt(file_sendim_counter)}
        sleep 1
        update_sendim_counter_file ${sendim_counter}
    } else {
        set fp ${res}
        puts -nonewline ${fp} "set opt(sendim_counter) ${sendim_counter}\n"
        close ${fp}
    }
}

proc manage_system_command {input_command recvim_payload} {
    global opt
    global modem

    regexp {^SYSTEM\ (\d+)\ (.+)$} ${input_command} -> sleep_time system_command
    regexp {(F|S),(\d+),(\d+),((\d+\ ?)+)?,(\d+)?,((\d+\ ?)+)?,(.+)} ${recvim_payload} -> \
    net_protocol     \
    net_src          \
    ->               \
    ->               \
    ->               \
    net_orig_length  \
    net_extra_field  \
    ->               \
    ->
    set file_name "tmpstdout"

    # exec the command
    set pid_cmd "0"
    if {[catch {set pid_cmd [eval "exec ${system_command} > ${file_name} &"]}] == 0} {
        debug_app "Executing: ${system_command} with pid ${pid_cmd} and wait time of ${sleep_time}\n"
        send_up "${opt(module_name)}: executing: ${system_command} with pid ${pid_cmd} and wait time of ${sleep_time}\n"
        sleep ${sleep_time}
    } else {
        debug_app "Impossible to exec ${system_command}\n"
        send_up "${opt(module_name)}: Impossible to exec ${system_command}\n"
        return "ERR_EXEC"
    }

    # kill if alive
    if {[catch {exec ls /proc/ | grep -w ${pid_cmd}} res] == 0} {
        if {[string compare ${pid_cmd} ${res}] == 0} {
            debug_app "Killing: ${system_command} with pid ${pid_cmd}\n"
            if {[catch {exec kill -9 ${pid_cmd}} res] == 0} {
                debug_app "Killed: ${system_command} with pid ${pid_cmd}\n"
                send_up "${opt(module_name)}: killed: ${system_command} with pid ${pid_cmd}\n"
            } else {
                debug_app "Error killing: ${system_command} with pid ${pid_cmd}. Details: ${res}\n"
                send_up "${opt(module_name)}: error killing: ${system_command} with pid ${pid_cmd}. Details: ${res}\n"
                return "ERR_KILL"
            }
        } else {
            debug_app "Impossible to grep for pid ${pid_cmd}. Details: ${res}\n"
            send_up "${opt(module_name)}: impossible to grep for pid ${pid_cmd}. Details: ${res}\n"
            return "NO_OUTPUT"
        }
    } else {
        debug_app "Executed: ${system_command} with pid ${pid_cmd}\n"
        send_up "${opt(module_name)}: executed: ${system_command} with pid ${pid_cmd}\n"
    }

    # Retrieve the output to print
    if {[catch {open ${file_name} "r"} res] == 0} {
        set fp ${res}
        set file_data [read $fp]
        foreach line [split ${file_data} "\n"] {
            if {[string length ${line}] != 0} {
                debug_app "${line}\n"
                send_up "${line}\n"
            }
        }
        close ${fp}
    } else {
        debug_app "Impossible to open ${file_name} or file empty. Details: ${res}\n"
        send_up "${opt(module_name)}: impossible to open ${file_name} or file empty. Details: ${res}\n"
        return "NO_OUTPUT"
    }

    # Retrieve and format the output to send back
    if {[info exists net_src] && [string compare ${net_src} ${modem(id)}] != 0 && [string compare ${net_src} ""] != 0} {
        set fsize [file size ${file_name}]
        if {${fsize} > ${opt(max_system_cmd_log_length)}} {
            set fsize ${opt(max_system_cmd_log_length)}
        }
        # continue only if the file exists and the file is not empty
        if {[catch {open ${file_name} "r"} res] == 0 && [file size ${file_name}] > 0} {
            set fp ${res}
        } else {
            debug_app "Impossible to open ${file_name} or file empty\n"
            send_up "${opt(module_name)}: impossible to open ${file_name} or file empty\n"
            return "NO_OUTPUT"
        }
        if {[string compare ${net_protocol} "F"] == 0} {
            set ack_ttl [expr ${net_orig_length} - ${net_extra_field}]
        } else {
            set ack_ttl [expr ${net_orig_length} - [llength [split ${net_extra_field} " "]]]
        }
        set data [read ${fp} ${fsize}]
        debug_app "Sending back ${fsize} chars of log\n"
        regsub -all {\n} ${data} {|} data
        # Computation to set a priori the size of the payload
        # TODO: fix the value 5 that corresponds to R>${msg_counter}> + 1 (reason: I do not know)
        set payload_im [expr ${opt(max_sendim_size)} - [string length "SEND,F,${net_src},${ack_ttl},"] - 5]
        for {set left_index 0; set right_index [expr ${left_index} + ${payload_im} + 1]; set msg_counter 0} {${left_index} < [string length ${data}]} {incr left_index ${payload_im}; incr right_index ${payload_im}; incr msg_counter} {
            if {${right_index} >= [string length ${data}]} {
                set right_index [expr [string length ${data}] - 1]
            }
            set log "R>${msg_counter}>[string range ${data} ${left_index} ${right_index}]"
            set msg "SEND,F,${net_src},${ack_ttl},${log}"
            set sendim_to_send "[forge_sendim ${msg}]"
            if {[string compare ${sendim_to_send} "ERR"] != 0} {
                debug_app "${sendim_to_send}\n"
                send_up "${opt(module_name)}: created ${sendim_to_send}\n"
                sleep ${opt(sleep_before_answer)}
                send_down "${sendim_to_send}\n"
            } else {
                debug_app "Created an instant message too long. Droppped!\n"
                send_up "${opt(module_name)}: created an instant message too long. Dropped!\n"
            }
        }
        close ${fp}

        catch {exec rm -fr ${file_name}}
        return "NOACK"
    } else {
        catch {exec rm -fr ${file_name}}
        return "NOACK"
    }
}

proc forge_sendim {raw_msg} {
    global opt modem

    regexp {^SEND,(F|S),((\d\ ?)+)?,((\d\ ?)+),([^\n]*)(\r?)(\n?)$} ${raw_msg} -> \
    input_protocol     \
    input_dst          \
    ->                 \
    input_extra_field  \
    ->                 \
    input_command      \
    ->
    if {![info exists input_protocol] || ![info exists input_dst] || ![info exists input_extra_field] || ![info exists input_command]} {
        return "ERR"
    }
    set input_dst           [string trim ${input_dst} { }]
    set input_extra_field   [string trim ${input_extra_field} { }]
    if {[string compare ${input_protocol} "F"] == 0} {
        set origin_length   ${input_extra_field}
    } else {
        set origin_length   [llength [split ${input_extra_field} " "]]
    }
    set sendim_data         "${input_protocol},${modem(id)},${opt(sendim_counter)},${input_dst},${origin_length},${input_extra_field},${input_command}"
    if {[string length ${sendim_data}] > ${opt(max_sendim_size)}} {
        if {[expr [string length ${sendim_data}] - [string length ${input_command}]] < ${opt(max_sendim_size)}} {
            set sendim_data [string range ${sendim_data} 0 [expr ${opt(max_sendim_size)} - 1]]
        } else {
            return "ERR"
        }
    }
    set opt(sendim_counter) [expr ${opt(sendim_counter)} + 1]
    update_sendim_counter_file ${opt(sendim_counter)}
    set sendim_ack          ${opt(ack_mode)}
    set sendim_dst          "255"
    set sendim_length       [string length ${sendim_data}]
    if {[string compare ${input_protocol} "F"] == 0} {
        set sendim_msg      "AT*SENDIM,${sendim_length},${sendim_dst},noack,${sendim_data}"
    } else {
        set sendim_msg      "AT*SENDIM,${sendim_length},${sendim_dst},${sendim_ack},${sendim_data}"
    }
    log_string [clock seconds] ${opt(module_name)} "CREATE" "${sendim_msg}\n"
    return ${sendim_msg}
}

proc NS_kill {id_sim} {
    global opt
    global map_ns_pid
    global map_ns_id

    if {[info exists map_ns_id(${id_sim})]} {
        catch {exec ls /proc/ | grep -w $map_ns_id(${id_sim})} res
        if {[string compare $map_ns_id($id_sim) ${res}] == 0} {
            exec kill -9 $map_ns_id(${id_sim})
            return "KILLED"
        }
        return "NOT_RUNNING"
    }
    return "NEVER_STARTED"
}

proc NS_killall {} {
    global opt
    global map_ns_pid
    global map_ns_id

    set list_ns_killed ""
    foreach id_sim [array names map_ns_id] {
        set ret_val [NS_kill ${id_sim}]
        if {[string compare ${ret_val} "KILLED"] == 0} {
            lappend list_ns_killed ${id_sim}
        }
    }
    if {[llength ${list_ns_killed}] > 0} {
        return ${list_ns_killed}
    } else {
        return "-"
    }
}

proc NS_running {} {
    global opt
    global map_ns_pid
    global map_ns_id

    set list_ns_running ""
    foreach id_sim [array names map_ns_id] {
        if {[string length ${id_sim}] != 0} {
            set tmp_status [NS_status ${id_sim}]
            if {[string compare ${tmp_status} "RUNNING"] == 0} {
                lappend list_ns_running ${id_sim}
            }
        }
    }
    if {[llength ${list_ns_running}] > 0} {
        return ${list_ns_running}
    } else {
        return "-"
    }
}

proc NS_status {id_sim} {
    global opt
    global map_ns_pid
    global map_ns_id

    if {[array exists map_ns_id] && [info exists map_ns_id(${id_sim})]} {
        set res ""
        catch {set res [exec ls /proc/ | grep -w $map_ns_id(${id_sim})]} err_code
        if {[string length $res] != 0 && [string compare $map_ns_id($id_sim) ${res}] == 0} {
            return "RUNNING"
        } else {
            return "NOT_RUNNING"
        }
    } else {
        return "NEVER_STARTED"
    }
}

proc NS_start {input_string} {
    global opt modem
    global map_ns_pid
    global map_ns_id

    set input_params [split [string trim ${input_string} " "] " "]

    if {[llength ${input_params}] < 2} {
        debug_app "too few argument when starting ns\n"
        send_up "${opt(module_name)}: too few argument when starting ns\n"
        return "WRONG_SIM_ID"
    }

    # Trick to insert the modem id in the list of params
    if {[string compare ${modem(id)} ""] == 0} {
        debug_app "invalid id of the modem when starting to run ns\n"
        send_up "${opt(module_name)}: invalid id of the modem when starting to run ns\n"
        return "WRONG_MODEM_ID"
    }
    set input_params [linsert ${input_params} 2 ${modem(id)}]

    set id_sim [lindex ${input_params} 0]
    set tmp_status [NS_status ${id_sim}]

    if {[string compare ${tmp_status} "RUNNING"] == 0} {
        debug_app "ns with id ${id_sim} is already running\n"
        send_up "${opt(module_name)}: ns with id ${id_sim} is already running\n"
        return "STILL_RUNNING ${id_sim}"
    } elseif {[string compare ${tmp_status} "NOT_RUNNING"] == 0} {
        debug_app "ns with id ${id_sim} not running but already started\n"
        send_up "${opt(module_name)}: ns with id ${id_sim} not running but already started\n"
        return "DUPLICATED_ID ${id_sim}"
    }

    set pid_ns [eval exec ./${opt(ns_start_file_name)} ${input_params} > /dev/null 2> /dev/null &]
    if {[file exists ${opt(map_ns_file_name)}] != 1} {
        exec touch ${opt(map_ns_file_name)}
    }
    if {[catch {open ${opt(map_ns_file_name)} "a+"} res]} {
        puts stderr ${res}
        NS_kill ${id_sim}
        return "ERROR_MAP_ID"
    } else {
        set fp ${res}
        puts -nonewline ${fp} "set map_ns_id(${id_sim}) ${pid_ns}\n"
        puts -nonewline ${fp} "set map_ns_pid(${pid_ns}) ${id_sim}\n"
        close ${fp}
    }

    set map_ns_id(${id_sim}) ${pid_ns}
    set map_ns_pid(${pid_ns}) ${id_sim}
    debug_app "ns with id ${id_sim} and pid ${pid_ns} started\n"
    send_up "${opt(module_name)}: ns with id ${id_sim} and pid ${pid_ns} started\n"
    return "STARTED ${id_sim}"
}

proc command_manager {input_command recvim_payload} {
    global opt modem
    global map_ns_id map_ns_pid

    switch -regexp -- ${input_command} {
        {^AT\?AL$} {
            reset_pendings
            set opt(pending_id_request) -1
            send_down "${input_command}\n"
            return "${input_command} ${modem(id)}"
        }
        {^AT\!AL\d+$} {
            regexp {^AT\!AL(\d+)$} ${input_command} -> opt(pending_id_request)
            if {[info exists opt(pending_id_request)]} {
                send_down "${input_command}\n"
                return "ACK"
            } else {
                return "${input_command} ERR_WRONG_FORMAT"
            }
        }
        {^AT\?L$} {
            puts "AT?L"
            reset_pendings
            set opt(pending_power_request) -1
            send_down "${input_command}\n"
            return "${input_command} ${modem(powerlevel)}"
        }
        {^AT\!L[0123]$} {
            puts "AT!L"
            regexp {^AT\!L([0123])$} ${input_command} -> opt(pending_power_request)
            puts "pending_power_request = ${opt(pending_power_request)}"
            if {[info exists opt(pending_power_request)]} {
                send_down "${input_command}\n"
                return "ACK"
            } else {
                return "${input_command} ERR_WRONG_FORMAT"
            }
        }
        {^AT(\!|\?)((?!AL).)*$} {
            send_down "${input_command}\n"
            return "ACK"
        }
        {^AT\*SEND,.*$} {
            send_down "${input_command}\n"
            return "ACK"
        }
        {^RECV,.*$} {
            send_down "${input_command}\n"
            return "ACK"
        }
        {^AT\*SENDIM,.*$} {
            send_down "${input_command}\n"
            return "ACK"
        }
        {^RECVIM,.*$} {
            send_down "${input_command}\n"
            return "ACK"
        }
        {^SEND,(F|S),((\d\ ?)+)?,(\d\ ?)+,.*$} {
            set sendim_to_send "[forge_sendim ${input_command}]\n"
            if {[string compare ${sendim_to_send} "ERR\n"] != 0} {
                debug_app "${sendim_to_send}"
                send_up "${opt(module_name)}: created ${sendim_to_send}"
                sleep ${opt(sleep_before_answer)}
                send_down "${sendim_to_send}"
                return "NOACK"
            } else {
                debug_app "Created an instant message too long. Droppped!"
                send_up "${opt(module_name)}: created an instant message too long. Dropped!\n"
                return "NOACK"
            }
        }
        {^SYSTEM\ \d+\ .+$} {
            set out_proc [manage_system_command ${input_command} ${recvim_payload}]
            return ${out_proc}
        }
        {^R>.*$} {
            return "NOACK"
        }
        {^NSC>.*$} {
            if {[string compare ${opt(getper_last_src)} ""] != 0 && [string compare ${opt(getper_last_src)} ${modem(id)}] != 0} {
                #set input_command [string trimleft ${input_command} "NSC>"]
                set msg "SEND,F,${opt(getper_last_src)},${opt(getper_last_ttl)},${input_command}"
                set sendim_to_send "[forge_sendim ${msg}]"
                if {[string compare ${sendim_to_send} "ERR"] != 0} {
                    debug_app "${sendim_to_send}\n"
                    send_up "${opt(module_name)}: created ${sendim_to_send}\n"
                    sleep ${opt(sleep_before_answer)}
                    set opt(getper_last_src) ""
                    send_down "${sendim_to_send}\n"
                    return "NOACK"
                } else {
                    set opt(getper_last_src) ""
                    debug_app "Created an instant message too long. Droppped!"
                    send_up "${opt(module_name)}: created an instant message too long. Dropped!\n"
                    return "NOACK"
                }
            }
            return "NOACK"
        }
        {^PERSET\ .*$} {
            send_down_nsc "${input_command}\n"
            return "ACK"
        }
        {^RESETMAPPER$} {
            send_down_nsc "${input_command}\n"
            return "ACK"
        }
        {^PERGET$} {
            if {[string length ${recvim_payload}] > 0} {
                regexp {(F|S),(\d+),(\d+),((\d+\ ?)+)?,(\d+)?,((\d+\ ?)+)?,(.*)} ${recvim_payload} -> \
                net_protocol         \
                opt(getper_last_src) \
                ->                   \
                ->                   \
                ->                   \
                net_orig_length      \
                net_extra_field      \
                ->                   \
                ->
                if {[info exists net_protocol] && [info exists net_orig_length] && [info exists net_extra_field] && [string length opt(getper_last_src)] != 0} {
                    if {[string compare ${net_protocol} "F"] == 0} { ;# Check the protocol used.
                        set opt(getper_last_ttl) [expr ${net_orig_length} - ${net_extra_field}]
                    } else {
                        set opt(getper_last_ttl) [expr ${net_orig_length} - [llength [split ${net_extra_field} " "]]]
                    }
                } else {
                    return "${input_command} ERR_WRONG_FORMAT"
                }
            }
            send_down_nsc "${input_command}\n"
            return "NOACK"
        }
        {^ACK$} {
            set out_proc ${opt(ack_mode)}
            debug_app "Ack mode set to ${opt(ack_mode)}\n"
            send_up "${opt(module_name)}: ack mode set to ${opt(ack_mode)}\n"
            set return_string "${input_command} ${out_proc}"
            return ${return_string}
        }
        {^ACK\ ON$} {
            set opt(ack_mode) "ack"
            debug_app "Ack mode set to ${opt(ack_mode)}\n"
            send_up "${opt(module_name)}: ack mode set to ${opt(ack_mode)}\n"
            return "ACK"
        }
        {^ACK\ OFF$} {
            set opt(ack_mode) "noack"
            debug_app "Ack mode set to ${opt(ack_mode)}\n"
            send_up "${opt(module_name)}: ack mode set to ${opt(ack_mode)}\n"
            return "ACK"
        }
        {^MACDELAY$} {
            set out_proc ${opt(mac_delay)}
            debug_app "Mac delay set to ${out_proc}\n"
            send_up "${opt(module_name)}: mac delay set to ${out_proc}\n"
            set return_string "${input_command} ${out_proc}"
            return ${return_string}
        }
        {^MACDELAY\ [0-9]*\.?[0-9]+$} {
            regexp {^MACDELAY\ ([0-9]*\.?[0-9]+)$} ${input_command} -> opt(mac_delay)
            if {[string length ${opt(mac_delay)}] == 0} {
                return "${input_command} ERR_WRONG_FORMAT"
            }
            set out_proc ${opt(mac_delay)}
            debug_app "Mac delay set to ${out_proc}\n"
            send_up "${opt(module_name)}: mac delay set to ${out_proc}\n"
            send_down "${input_command}\n"
            return "ACK"
        }
        {^NETDED$} {
            set out_proc ${opt(net_forward_mode)}
            debug_app "Net forward mode set to ${out_proc}\n"
            send_up "${opt(module_name)}: net forward mode set to ${out_proc}\n"
            set return_string "${input_command} ${out_proc}"
            return ${return_string}
        }
        {^NETDED\ ON$} {
            set opt(net_forward_mode) "on"
            set out_proc ${opt(net_forward_mode)}
            debug_app "Net forward mode set to ${out_proc}\n"
            send_up "${opt(module_name)}: net forward mode set to ${out_proc}\n"
            send_down "${input_command}\n"
            return "ACK"
        }
        {^NETDED\ OFF$} {
            set opt(net_forward_mode) "off"
            set out_proc ${opt(net_forward_mode)}
            debug_app "Net forward mode set to ${out_proc}\n"
            send_up "${opt(module_name)}: net forward mode set to ${out_proc}\n"
            send_down "${input_command}\n"
            return "ACK"
        }
        {^NSRUNNING$} {
            set out_proc [NS_running]
            debug_app "${out_proc}\n"
            send_up "${opt(module_name)}: ${out_proc}\n"
            set return_string "${input_command} ${out_proc}"
            return ${return_string}
        }
        {^NSSTATUS\ [[:alnum:]]+$} {
            regexp {^NSSTATUS\ ([[:alnum:]]+)$} ${input_command} -> id_sim
            if {[info exists id_sim]} {
                set out_proc [NS_status ${id_sim}]
                debug_app "${out_proc}\n"
                send_up "${opt(module_name)}: ${out_proc}\n"
                set return_string "${input_command} ${out_proc}"
                return ${return_string}
            } else {
                return "${input_command} ERR_WRONG_FORMAT"
            }
        }
        {^NSKILL\ [[:alnum:]]+$} {
            regexp {^NSKILL\ ([[:alnum:]]+)$} ${input_command} -> id_sim
            if {[info exists id_sim]} {
                set out_proc [NS_kill ${id_sim}]
                debug_app "${out_proc}\n"
                send_up "${opt(module_name)}: ${out_proc}\n"
                set return_string "${input_command} ${out_proc}"
                return ${return_string}
            } else {
                return "${input_command} ERR_WRONG_FORMAT"
            }
        }
        {^NSKILLALL$} {
            set out_proc [NS_killall]
            debug_app "${out_proc}\n"
            send_up "${opt(module_name)}: ${out_proc}\n"
            set return_string "${input_command} ${out_proc}"
            return ${return_string}
        }
        {^NS\ .*$} {
            regexp {^NS\ (.*)$} ${input_command} -> ns_parameters
            if {[info exists ns_parameters]} {
                set out_proc [NS_start ${ns_parameters}]
                return ${out_proc}
            } else {
                return "NS ERR_WRONG_FORMAT"
            }
        }
        {^RESETMAPNS$} {
            array unset map_ns_pid
            debug_app "Variable map_ns_pid removed\n"
            send_up "${opt(module_name)}: Variable map_ns_pid removed\n"
            array unset map_ns_id
            debug_app "Variable map_ns_id removed\n"
            send_up "${opt(module_name)}: Variable map_ns_id removed\n"
            if {[file exists "${opt(map_ns_file_name)}"]} {
                catch {exec rm -fr ${opt(map_ns_file_name)}} res
                if {[string length ${res}] == 0 || [string compare ${res} "0"] == 0} {
                    debug_app "File ${opt(map_ns_file_name)} removed\n"
                    send_up "${opt(module_name)}: File ${opt(map_ns_file_name)} removed\n"
                    set return_string "${input_command} DONE"
                } else {
                    debug_app "File ${opt(map_ns_file_name)} not removed\n"
                    send_up "${opt(module_name)}: File ${opt(map_ns_file_name)} not removed\n"
                    set return_string "${input_command} FILE_NOT_REMOVED"
                }
            } else {
                debug_app "File ${opt(map_ns_file_name)} not found\n"
                send_up "${opt(module_name)}: File ${opt(map_ns_file_name)} not found\n"
                set return_string "${input_command} DONE"
            }
            return ${return_string}
        }
        {^HELP+$} {
            send_up "\
            +--------------------------------------------------------------------+\n\
            | S2C Control Framework Help                                         |\n\
            | COMMAND                                                            |\n\
            |      description                                                   |\n\
            +--------------------------------------------------------------------+\n\
            | AT*                                                                |\n\
            |      all the AT commands are supported by the framework            |\n\
            | SEND,F,DESTINATIONS,TTL,PAYLOAD                                    |\n\
            |      send a command by using the Flooding routing protocol         |\n\
            | SEND,S,DESTINATIONS,ROUTE,PAYLOAD                                  |\n\
            |      send a command by using the Static routing protocol           |\n\
            | SYSTEM WAITTIME COMMAND                                            |\n\
            |      send a command and wait WAITTIME for its execution            |\n\
            | ACK                                                                |\n\
            |      print the ack mode                                            |\n\
            | ACK ON                                                             |\n\
            |      set the ack flag to on for SENDIM messages                    |\n\
            | ACK OFF                                                            |\n\
            |      set the ack flag to on for SENDIM messages                    |\n\
            | MACDELAY                                                           |\n\
            |      return the max rand delay used in transmission by the MAC     |\n\
            | MACDELAY DELAY                                                     |\n\
            |      set DELAY as delay used in transmission by the MAC            |\n\
            | NETDED                                                             |\n\
            |      return the forward mode of the NET                            |\n\
            | NETDED ON                                                          |\n\
            |      enable the drop of NET packets with an empty list of          |\n\
            |      destinations                                                  |\n\
            | NETDED OFF                                                         |\n\
            |      disable the drop of NET packets with an empty list of         |\n\
            |      destinations                                                  |\n\
            | NSRUNNING                                                          |\n\
            |      return the running istances of ns                             |\n\
            | NSSTATUS ID                                                        |\n\
            |      return the status of the istance of ns with id ID             |\n\
            |      it can be RUNNING, NOT_RUNNING or NEVER_STARTED               |\n\
            | NSKILL ID                                                          |\n\
            |      kill the istance of ns with id ID                             |\n\
            | NSKILLALL                                                          |\n\
            |      kill all the istances of ns RUNNING in the node               |\n\
            | NS ID PARAMS                                                       |\n\
            |      start an ns istance with id ID and parameters PARAMS          |\n\
            | PERSET ID PER ...                                                  |\n\
            |      set a per value in the NSC module.                            |\n\
            |      If the id the node already exists, this command overwrites    |\n\
            |      the old per value                                             |\n\
            | PERGET                                                             |\n\
            |      return the list of the per values                             |\n\
            | RESETMAPNS                                                         |\n\
            |      reset the variables and files that contain the info about     |\n\
            |      the instances of ns                                           |\n\
            | RESETMAPPER                                                        |\n\
            |      reset the variables and files that contain the info about     |\n\
            |      the packet error rates                                        |\n\
            | HELP                                                               |\n\
            |      print this help                                               |\n\
            +--------------------------------------------------------------------+\n"
            return "NOACK"
        }
        default {
            debug_app "unmanaged ${input_command}\n"
            send_up "${opt(module_name)}: unmanaged ${input_command}\n"
            send_down "${input_command}\n"
            return "ACK"
        }
    }
}
