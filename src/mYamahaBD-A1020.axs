MODULE_NAME='mYamahaBD-A1020'   (
                                    dev vdvObject,
                                    dev dvPort
                                )

(***********************************************************)
#include 'NAVFoundation.ModuleBase.axi'
#include 'NAVFoundation.SocketUtils.axi'

/*
 _   _                       _          ___     __
| \ | | ___  _ __ __ _  __ _| |_ ___   / \ \   / /
|  \| |/ _ \| '__/ _` |/ _` | __/ _ \ / _ \ \ / /
| |\  | (_) | | | (_| | (_| | ||  __// ___ \ V /
|_| \_|\___/|_|  \__, |\__,_|\__\___/_/   \_\_/
                 |___/

MIT License

Copyright (c) 2023 Norgate AV Services Limited

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT

constant long TL_SOCKET_CHECK = 1

constant long TL_SOCKET_CHECK_INTERVAL[] = { 3000 }

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE

volatile integer requiredTransport

volatile char semaphore
volatile char rxBuffer[NAV_MAX_BUFFER]

volatile char communicating
volatile char address[15]
volatile integer port
volatile char connected = false

(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)

define_function SendStringRaw(char payload[]) {
    if (dvPort.NUMBER == 0) {
        NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                    NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_TO,
                                                dvPort,
                                                payload))
    }

    send_string dvPort, payload
}


define_function SendString(char payload[]) {
    SendStringRaw("NAV_STX, '07C', payload, NAV_ETX")
}


define_function MaintainSocketConnection() {
    if (!connected) {
        NAVClientSocketOpen(dvPort.PORT, address, port, IP_TCP)
    }
}


(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    create_buffer dvPort, rxBuffer
}

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT

data_event[dvPort] {
    online: {
        if (data.device.number != 0) {
            send_command data.device,"'SET BAUD 9600,N,8,1 485 DISABLE'"
            send_command data.device,"'B9MOFF'"
            send_command data.device,"'CHARD-0'"
            send_command data.device,"'CHARDM-0'"
            send_command data.device,"'HSOFF'"
        }

        if (data.device.number == 0) {
            connected = true
        }

        SendStringRaw("NAV_STX, '10000', NAV_ETX")     //Start RS232

        [vdvObject,DATA_INITIALIZED] = true
        [vdvObject,DEVICE_COMMUNICATING] = true
    }
    string: {
        communicating = true
        [vdvObject,DATA_INITIALIZED] = true

        if (data.device.number == 0) {
            NAVErrorLog(NAV_LOG_LEVEL_DEBUG,
                        NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM,
                                                    data.device,
                                                    data.text))
        }
    }
    offline: {
        if (data.device.number == 0) {
            NAVClientSocketClose(dvPort.port)
            connected = false
        }
    }
    onerror: {
        if (data.device.number == 0) {
        }
    }
}

data_event[vdvObject] {
    command: {
        stack_var _NAVSnapiMessage message

        NAVParseSnapiMessage(data.text, message)

        switch (message.Header) {
            case 'PROPERTY': {
                switch (message.Parameter[1]) {
                    case 'IP_ADDRESS': {
                        address = message.Parameter[2]
                    }
                    case 'TCP_PORT': {
                        port = atoi(message.Parameter[2])
                        NAVTimelineStart(TL_SOCKET_CHECK, TL_SOCKET_CHECK_INTERVAL, timeline_absolute, timeline_repeat)
                    }
                }
            }
            case 'PASSTHRU': { SendString(message.Parameter[1]) }
        }
    }
}

channel_event[vdvObject, 0] {
    on: {
        switch (channel.channel) {
            case PLAY: SendString("'820'")
            case STOP: SendString("'850'")
            case PAUSE: SendString("'830'")
            case FFWD: SendString("'870'")
            case REW: SendString("'860'")
            case SFWD: SendString("'BA0'")
            case SREV: SendString("'B90'")
            case POWER: SendString("'800'")
            case PWR_ON: SendString("'F60'")
            case PWR_OFF: SendString("'F70'")
            case MENU_UP: SendString("'B40'")
            case MENU_DN: SendString("'B30'")
            case MENU_LT: SendString("'B50'")
            case MENU_RT: SendString("'B60'")
            case MENU_SELECT: SendString("'B80'")
            case MENU_BACK: SendString("'B70'")
            case 44: { SendString("'B10'") }    //Top Menu
            case 57: { SendString("'AB0'") }    //Sub-title
            case 101: { SendString("'EF0'") }    //Home
            case 102: { SendString("'CF0'") }    //popup menu
            case DISC_TRAY: { SendString("'810'") }
        }
    }
}

timeline_event[TL_SOCKET_CHECK] { MaintainSocketConnection() }

(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)
