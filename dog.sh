#!/bin/bash

note_r() { dzen2 -fn "xos4 Terminus-10" -fg "#FF0000" -p 5 & beep -f 450; }
note_g() { dzen2 -fn "xos4 Terminus-10" -fg "#83BF15" -p 5 & beep -f 500; }
note_o() { dzen2 -fn "xos4 Terminus-10" -fg "#FFA500" -p 5 & beep -f 550; }
note_p() { dzen2 -fn "xos4 Terminus-10" -fg "#EE82EE" -p 5 & beep -f 600; }

case "$1" in
+s)
    status () {
    printf " "
    nm-online -t 0 && printf "W  "
    printf "B$(cat /sys/class/power_supply/BAT0/capacity)"
    [ `cat /sys/class/power_supply/BAT0/status` = 'Charging' ] && printf "*"
    printf "  "
#    printf "$((`cat /sys/class/thermal/thermal_zone0/temp`/1000))°C "
#    printf "%02d%%  " $(top -bn1 | sed -n '/Cpu/p' | cut -c 10-11)
#    printf "$(free -m | awk '/^Mem/ {print $3}')M  "
#    printf "$(awk '{print int($1/3600)":"int(($1%3600)/60)}' /proc/uptime)UP  "
    [ -f .wttr ] && printf "`<.wttr`  "
    printf "$(date +"%A, %d %B %Y  %I:%M %p")"
    }

    echo "Status update started."
    while true
    do
        xsetroot -name "$(status)"
    sleep 30
    done &
    ;;

+b)
    echo "Battery notification started."
    b_cri=20
    b_low=40
    b_max=95
    while true
    do
        b=$(cat /sys/class/power_supply/BAT0/capacity)
        bs=$(cat /sys/class/power_supply/BAT0/status)

        [ $b -lt $b_cri ] &&
        {
            echo "Battery critical" | note_r
            sleep 1m
            slock &
            systemctl hibernate
        }

        [ $b -lt $b_low ] && [ $bs = 'Discharging' ] &&
        echo "Battery low: $b %" | note_r

        [ $b -gt $b_max ] && [ $bs = 'Charging' ] &&
        echo "Battery full" | note_g
        sleep 2m
    done &
    ;;

+t)
    echo "Temperature notification started."
    t_hi=70
    t_cri=90
    while true
    do
        t=$((`cat /sys/class/thermal/thermal_zone0/temp`/1000))
        [ $t -gt $t_hi ] &&
        echo "Temperature high: $t°C" | note_r

        [ $t -gt $t_cri ] &&
        {
            sudo rtcwake -m mem -s 240
            t=$((`cat /sys/class/thermal/thermal_zone0/temp`/1000))
            [ $t -gt $t_cri ] &&
            systemctl hibernate
        }
        sleep 2m
    done &
    ;;

+p)
    echo "Periodic vacations started."
    gap=25m
    while true
    do
        sleep $gap
        j=$(journalctl -qn 1 -t systemd-sleep -S "$(date +%R -d "-24 min")" | awk '{print $3}')
        [ -n "$j" ] &&
        {
            n=$(date +%s)
            r=$(date +%s -d "$j")
            gap=$((1500 - n + r))
            continue
        }
        gap=25m

        echo "Clock: $(date +"%I:%M %p")" | note_o
        che=$(date +%R)
        sleep 1m
        [ "$che" != "$(date +%R -d "-1 min")" ] &&
        continue

        b=$(xbacklight -get)
        ! pgrep mpv >/dev/null && [ "${b%.*}" -gt 0 ] &&
        sudo rtcwake -m mem -s 240 >/dev/null
    done &
    ;;

+w)
    echo "Weather update started."
    delay=20
    while true
    do
        sleep $delay
        if nm-online -t 0
        then
            curl 'wttr.in/?format=%C+%p+%t' >.wttr 2>/dev/null
            cat .wttr | grep -qw rain &&
            echo "`cat .wttr`" | note_p
            delay=15m
        else
            [ -f .wttr ] &&
            test "`find .wttr -mmin +60`" &&
            rm .wttr
            delay=2m
        fi
    done &
    ;;
+)
    dog.sh +s
    dog.sh +b
    dog.sh +t
    dog.sh +p
    dog.sh +w
    ;;

-l|ls)
    pgrep -fa "dog.sh \+"
    ;;

-*)
    pkill -f "dog.sh \+${1:1:1}"
    ;;
esac
