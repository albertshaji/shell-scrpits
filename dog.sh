#!/bin/bash

note_r() { dzen2 -fn "xos4 Terminus-10" -fg "#FF0000" -p 5 & beep -f 1000; }
note_g() { dzen2 -fn "xos4 Terminus-10" -fg "#83BF15" -p 5 & beep -f 1500; }
note_o() { dzen2 -fn "xos4 Terminus-10" -fg "#FFA500" -p 5 & beep -f 2000; }
note_p() { dzen2 -fn "xos4 Terminus-10" -fg "#EE82EE" -p 5 & beep -f 2500; }

case "$1" in
+s)
    status () {
    printf " "
    nm-online -t 0 && printf "W  "
    [ `cat /sys/class/power_supply/BAT0/status` = 'Charging' ] && printf ">>"
    printf "B:$(cat /sys/class/power_supply/BAT0/capacity)%%  "
    printf "C:$((`cat /sys/class/thermal/thermal_zone0/temp`/1000))°C "
    printf "%02d%%  " $(top -bn1 | sed -n '/Cpu/p' | cut -c 10-11)
#    printf "$(free -m | awk '/^Mem/ {print $3}')M  "
#    printf "$(awk '{print int($1/3600)":"int(($1%3600)/60)}' /proc/uptime)UP  "
    [ -s .wttr ] && printf "`<.wttr`  "
    printf "$(date +"%A, %d %B %Y  %I:%M %p")"
    }

    # Remove old weather data
    [ -e .wttr ] &&
    test "`find .wttr -mmin +60`" &&
    rm .wttr

    echo "Status update started."
    while true
    do
        xsetroot -name "$(status)"
    sleep 30
    done &

    # Practice type-writing
    test "`find .touchtyping -mmin +1400`" &&
    {
        sleep 1
        tipp10 &
        xdotool key alt+4
        touch .touchtyping
    }
    ;;

+b)
    echo "Battery notification started."
    b_cri=25
    b_low=50
    b_max=95
    while true
    do
        b=$(cat /sys/class/power_supply/BAT0/capacity)
        bs=$(cat /sys/class/power_supply/BAT0/status)

        [ $b -lt $b_cri ] &&
        {
            echo "Battery critical, Hibernating in 1 minute." | note_r
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

+ps)
    echo "Periodic sleep started."
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

        h=`date +%H`
        if [ $h -lt 12 ]; then
          g="morning"
        elif [ $h -lt 18 ]; then
          g="afternoon"
        else
          g="evening"
        fi
        echo "Good $g, it's $(date +"%I:%M %p")" | note_o

        che=$(date +%R)
        sleep 1m
        [ "$che" != "$(date +%R -d "-1 min")" ] &&
        continue

        [ -e .sk ] &&
        {
            rm .sk
            gap=10m
            continue
        }

        b=$(xbacklight -get)
        ! pgrep mpv >/dev/null && [ "${b%.*}" -gt 0 ] &&
        sudo rtcwake -m mem -s 240 >/dev/null
    done &
    ;;

+p)
    echo "Periodic screen pause started."
        printf "Started " >>.ptlog
        date >>.ptlog
    if [ `date +%M` -le 30 ]
    then
        tar=$(date -d "`date +%H`:30" +%s)
    else
        n=$((`date +%H` + 1))
        tar=`date -d "$n:00" +%s`
    fi
    buff=$(( $tar - `date +%s` ))
    sleep $buff
        date >>.ptlog

    while true
    do
        date >>.ptlog
        sleep 25m
        date >>.ptlog
        echo "Good day, it's $(date +"%I:%M %p")" | note_o &
        sleep 60

        [ -e .skip ] &&
        {
            rm .skip
            sleep 240
            continue
        }

        ! pgrep mpv >/dev/null
        {
        date >>.ptlog
            xset dpms force off
            redshift -P -O 1200 >/dev/null
            sleep 240
            redshift -P -O 5000 >/dev/null
            xset dpms force on
        date >>.ptlog
        }
    done &
    ;;

+w)
    echo "Weather update started."
    sleep 20
    while true
    do
        if nm-online -t 0
        then
            curl 'wttr.in/?format=%C+%p+%t' >.wttr 2>/dev/null
            cat .wttr | grep -q 'Unknown location' && rm .wttr
            sleep 18m
        else
            [ -e .wttr ] &&
            {
                sleep 18m
                nm-online -t 0 ||
                rm .wttr
            }
        fi
        sleep 2m
    done &
    ;;

+)
    dog.sh +s
    dog.sh +b
    dog.sh +t
    dog.sh +w &
   # dog.sh +p &
    ;;

-l|ls)
    pgrep -fa "dog.sh \+"
    ;;

-*)
    pkill -f "dog.sh \+${1:1:1}"
    ;;
esac
