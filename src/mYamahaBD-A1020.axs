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

constant long TL_IP_CHECK = 1

(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE
volatile long ltIPCheck[] = { 3000 }

volatile integer iRequiredTransport

volatile integer iSemaphore
volatile char cRxBuffer[NAV_MAX_BUFFER]

volatile integer iCommunicating
volatile char cIPAddress[15]
volatile integer iTCPPort
volatile integer iIPConnected = false

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
define_function SendStringRaw(char cParam[]) {
    NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_TO, dvPort, cParam))
    //NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_TO, dvPort, cParam))
    send_string dvPort,"cParam"
}

define_function SendString(char cParam[]) {
    SendStringRaw("NAV_STX,'07C',cParam,NAV_ETX")
}

define_function MaintainIPConnection() {
    if (!iIPConnected) {
        NAVClientSocketOpen(dvPort.port,cIPAddress,iTCPPort,IP_TCP)
    }
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START {
    create_buffer dvPort, cRxBuffer
}
(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT
data_event[dvPort] {
    online: {
        if (data.device.number <> 0) {
            send_command data.device,"'SET BAUD 9600,N,8,1 485 DISABLE'"
            send_command data.device,"'B9MOFF'"
            send_command data.device,"'CHARD-0'"
            send_command data.device,"'CHARDM-0'"
            send_command data.device,"'HSOFF'"
        }

        if (data.device.number == 0) {
            iIPConnected = true
        }

        SendStringRaw("NAV_STX,'10000',NAV_ETX")     //Start RS232
        [vdvObject,DATA_INITIALIZED] = true
        [vdvObject,DEVICE_COMMUNICATING] = true
    }
    string: {
        iCommunicating = true
        [vdvObject,DATA_INITIALIZED] = true
        //NAVLog("'String To Bluray: ',data.text")
        NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_STRING_FROM, data.device, data.text))
    }
    offline: {
        if (data.device.number == 0) {
            NAVClientSocketClose(dvPort.port)
            iIPConnected = false
            //iCommunicating = false
        }
    }
    onerror: {
        if (data.device.number == 0) {
            //iIPConnected = false
            //iCommunicating = false
        }
    }
}

data_event[vdvObject] {
    command: {
        stack_var char cCmdHeader[NAV_MAX_CHARS]
        stack_var char cCmdParam[2][NAV_MAX_CHARS]

        NAVLog(NAVFormatStandardLogMessage(NAV_STANDARD_LOG_MESSAGE_TYPE_COMMAND_FROM, data.device, data.text))

        cCmdHeader = DuetParseCmdHeader(data.text)
        cCmdParam[1] = DuetParseCmdParam(data.text)
        cCmdParam[2] = DuetParseCmdParam(data.text)

        switch (cCmdHeader) {
            case 'PROPERTY': {
                switch (cCmdParam[1]) {
                    case 'IP_ADDRESS': {
                        cIPAddress = cCmdParam[2]
                        //timeline_create(TL_IP_CHECK,ltIPCheck,length_array(ltIPCheck),timeline_absolute,timeline_repeat)
                    }
                    case 'TCP_PORT': {
                        iTCPPort = atoi(cCmdParam[2])
                        timeline_create(TL_IP_CHECK,ltIPCheck,length_array(ltIPCheck),timeline_absolute,timeline_repeat)
                    }
                }
            }
            case 'PASSTHRU': { SendString(cCmdParam[1]) }
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

timeline_event[TL_IP_CHECK] { MaintainIPConnection() }

(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)

