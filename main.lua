-- 这个项目的目的是通过Air601模组的两个UART连接UBLOX8030和MTK6260，实现两个功能
-- 1、上电的时候给UBLOX 8030发送配置指令，把输出的NMEA0183消息从$GN改为$GP
-- 2、转发UBLOX 8030输出的NMEA0183消息到MTK6260
-- UBLOX8030接在UART1，速率是9600bps，MTK6260接在UART2，速率是115200bps
PROJECT = "AIR601-8030"
VERSION = "0.0.1"

sys = require("sys")

--AIR601的UART1连接到UBLOX 8030
uart8030 = 1
uart8030baud = 9600

--AIR601的UART2连接到MTK6260
uart6260 = 2
uart6260baud = 115200

--UBLOX8030被配置过的标志
gpsinited = false
--要发送给UBLOX的配置指令，把GN字头改为GP
ubloxcmd = "\xB5\x62\x06\x17\x14\x00\x00\x40\x00\x02\x00\x00\x00\x00\x00\x01\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x75\x4F"


--从UBLOX接收到的定位数据
zbuff8030 = zbuff.create(2048)
zbuff6260 = zbuff.create(2048)

function Read8030()
    --[[ uart.rx 在Air601上虽然能读到数据，但是返回的i是-1，并且读取之后zbuff8030:used()的值也不正确，所以改用uart.read
    local i
    zbuff8030:seek(zbuff.SEEK_SET,0)
    zbuff8030:del(0)
    i = uart.rx(uart8030, zbuff8030)
    log.info('Read from UBlox8030',zbuff8030:used(),zbuff8030:toStr())
    --收到的定位数据转发给MTK6260
    if i > 0 then
        uart.tx(uart6260, zbuff8030,0,i)
    end
    ]]

    local tempStr,fullStr = "", ""

    while true do 
        tempStr = uart.read(uart8030, 1024)
        if tempStr == "" then
            log.info('Read from UBlox8030',#fullStr,fullStr)
            uart.write(uart6260,fullStr)
            break
        else
            fullStr = fullStr .. tempStr
        end
    end
end

function Read6260()
    local i
    zbuff6260:seek(zbuff.SEEK_SET,0)
    i = uart.rx(uart6260, zbuff6260)
    log.info('Read from MTK6260',i,zbuff6260:toStr(0,i))
end


function Task()
    if wdt then
        --添加硬狗防止程序卡死，在支持的设备上启用这个功能
        wdt.init(9000)--初始化watchdog设置为9s
        sys.timerLoopStart(wdt.feed, 3000)--3s喂一次狗
    end

    -- 现在使用的Air601固件还不支持BLE，所以这里先注释掉
    -- nimble.init('ICEGPS660-8030')

    uart.setup(uart8030, uart8030baud, 8, uart.STOP_1)
    uart.setup(uart6260, uart6260baud, 8, uart.STOP_1)
    uart.on(uart8030, "receive", Read8030)
    uart.on(uart6260, "receive", Read6260)
    
    --等待8030模组启动
    sys.wait(1000)
    uart.write(uart8030,ubloxcmd)
    sys.wait(100)

    while true do 
        log.info('testuart','Task')
        sys.wait(10000)
    end
end

sys.taskInit(Task)

sys.run()
