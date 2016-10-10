#!/bin/bash

Verbose=0

WriteLog () {
    if [ -z "$1" ] ; then
        echo "WriteLog: Log parameter #1 is zero length. Please debug..."
        exit 1
    else
        if [ -z "$2" ] ; then
            echo "WriteLog: Severity parameter #2 is zero length. Please debug..."
            exit 1
        else
            if [ -z "$3" ] ; then
                echo "WriteLog: Message parameter #3 is zero length. Please debug..."
                exit 1
            fi
        fi
    fi
    Now=$(date '+%Y-%m-%d %H:%M:%S,%3N')
    FullScriptName="${BASH_SOURCE[0]}"
    ScriptName=$(basename "$FullScriptName")
    if [ "${1,,}" = "verbose" -a $Verbose = 1 ] ; then
        echo "$Now: $ScriptName: $2: $3"
    elif [ "${1,,}" = "verbose" -a $Verbose = 0 ] ; then
        :
    elif [ "${1,,}" = "output" ] ; then
        echo "${Now}: $ScriptName: $2: $3"
    elif [ -f $1 ] ; then
        echo "${Now}: $ScriptName: $2: $3" >> $1
    fi
}

CountUpdates () {
    if [[ -x "/usr/bin/yum" ]] ; then
        UpdateCount=$(/usr/bin/yum -d 0 check-update 2>/dev/null | echo $(($(wc -l)-1)))
        if [ $UpdateCount == -1 ]; then
            UpdateCount=0
        fi
    elif [[ -x "/usr/bin/zypper" ]] ; then
        UpdateCount=$(zypper list-updates | wc -l)
        UpdateCount=$(expr $UpdateCount - 4)
	if (( $UpdateCount <= 0 )) ; then
	    UpdateCount=0
	fi
    elif [[ -x "/usr/bin/apt-get" ]] ; then
        UpdateCount=$(apt-get update > /dev/null; apt-get upgrade -u -s | grep -P "^Inst" | wc -l)
    fi
    echo "$UpdateCount"
    exit 0
}

GatherInfo () {
    ScriptName="$(readlink -e $0)"
    ScriptVersion=" $(cat $ScriptName | grep "# Version:" | awk {'print $3'} | tr -cd '[[:digit:].-]' | sed 's/.\{2\}$//') "
    OsVersion="$(cat /etc/*release | head -n 1)"
    if [[ "$OsVersion" == "SUSE"* ]] ; then
        OsVersion="$(echo $OsVersion | sed 's/ (.*//')"
        PatchLevel="$(cat /etc/*release | sed -n 3p | sed 's/.*= //')"
        OsVersion="${OsVersion}.$PatchLevel"
    elif [[ "$OsVersion" == "openSUSE"* ]] ; then
	OsVersion="$(cat /etc/os-release | sed -n 4p | sed 's/PRETTY_NAME="//' | sed 's/ (.*//')"
    elif [[ "$OsVersion" == *"Raspbian"* ]] ; then
        OsVersion="$(cat /etc/*release | head -n 1 | sed 's/.*"\(.*\)"[^"]*$/\1/')"
    fi
    IpPath="$(which ip 2>/dev/null)"
    IpAddress="$(${IpPath} route get 8.8.8.8 | head -1 | cut -d' ' -f8)"
    Kernel="$(uname -rs)"
#    Uptime="$(awk '{print int($1/86400)" day(s) "int($1%86400/3600)":"int(($1%3600)/60)":"int($1%60)}' /proc/uptime)"
    UptimeDays=$(awk '{print int($1/86400)}' /proc/uptime)
    UptimeHours=$(awk '{print int($1%86400/3600)}' /proc/uptime)
    UptimeMinutes=$(awk '{print int(($1%3600)/60)}' /proc/uptime)
    UptimeSeconds=$(awk '{print int($1%60)}' /proc/uptime)
    Dmi="$(dmesg | grep "DMI:")"
    if [[ "$Dmi" = *"QEMU"* ]] ; then
        Platform="$(dmesg | grep "DMI:" | sed 's/^.*QEMU/QEMU/' | sed 's/, B.*//')"
    elif [[ "$Dmi" = *"VMware"* ]] ; then
        Platform="$(dmesg | grep "DMI:" | sed 's/^.*VMware/VMware/' | sed 's/, B.*//')"
    elif [[ "$Dmi" = *"FUJITSU PRIMERGY"* ]] ; then
        Platform="$(dmesg | grep "DMI:" | sed 's/^.*FUJITSU PRIMERGY/Fujitsu Primergy/' | sed 's/, B.*//')"
    elif [[ "$Dmi" = *"VirtualBox"* ]] ; then
        Platform="$(dmesg | grep "DMI:" | sed 's/^.*VirtualBox/VirtualBox/' | sed 's/ .*//')"
    else
        Dmi="$(dmesg | grep "Rasp")"
        if [[ "$Dmi" = *"Rasp"* ]] ; then
            Platform="$(dmesg | grep "Rasp" | sed 's/.*: //')"
        else
            Platform="Unknown"
        fi
    fi
    CpuUtil="$(LANG=en_GB.UTF-8 mpstat 1 1 | awk '$2 ~ /CPU/ { for(i=1;i<=NF;i++) { if ($i ~ /%idle/) field=i } } $2 ~ /all/ { print 100 - $field}' | tail -1)"
    CpuProc="$(cat /proc/cpuinfo | grep processor | wc -l)"
    CpuLoad="$(uptime | grep -ohe '[s:][: ].*' | awk '{ print "1m: "$2 " 5m: "$3 " 15m: " $4}')"
    MemFreeB="$(cat /proc/meminfo | grep MemFree | awk {'print $2'})"
    MemTotalB="$(cat /proc/meminfo | grep MemTotal | awk {'print $2'})"
    MemUsedB="$(expr $MemTotalB - $MemFreeB)"
    MemFree="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$MemFreeB/1024/1024))"
    WriteLog Verbose Info "MemFree: $MemFree"
    MemUsed="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$MemUsedB/1024/1024))"
    WriteLog Verbose Info "MemUsed: $MemUsed"
    MemTotal="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$MemTotalB/1024/1024))"
    WriteLog Verbose Info "MemTotal: $MemTotal"
    MemFreePerc=$(echo "scale=2; $MemFree*100/$MemTotal" | bc)
    MemFreePerc=$(echo $(LC_NUMERIC=C printf "%.0f" $MemFreePerc))
    WriteLog Verbose Info "MemFreePerc: $MemFreePerc"
    #MemUsedPerc=$(echo "scale=2; $MemUsed*100/$MemTotal" | bc)
    #MemUsedPerc=$(echo $(LC_NUMERIC=C printf "%.0f" $MemUsedPerc))
    MemUsedPerc=$(echo "100-$MemFreePerc" | bc)
    WriteLog Verbose Info "MemUsedPerc: $MemUsedPerc"
    SwapFreeB="$(cat /proc/meminfo | grep SwapFree | awk {'print $2'})"
    SwapTotalB="$(cat /proc/meminfo | grep SwapTotal | awk {'print $2'})"
    SwapUsedB="$(expr $SwapTotalB - $SwapFreeB)"
    SwapFree="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$SwapFreeB/1024/1024))"
    SwapFreePerc=$(echo "scale=2; $SwapFreeB*100/$SwapTotalB" | bc)
    SwapFreePerc=$(echo $(LC_NUMERIC=C printf "%.0f" $SwapFreePerc))
    SwapUsed="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$SwapUsedB/1024/1024))"
    SwapUsedPerc=$(echo "100-$SwapFreePerc" | bc)
    SwapTotal="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$SwapTotalB/1024/1024))"
    RootFreeB="$(df -kP / | tail -1 | awk '{print $4}')"
    RootUsedB="$(df -kP / | tail -1 | awk '{print $3}')"
    RootTotalB="$(df -kP / | tail -1 | awk '{print $2}')"
    RootFree="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$RootFreeB/1024/1024))"
    RootUsed="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$RootUsedB/1024/1024))"
    RootTotal="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$RootTotalB/1024/1024))"
    RootUsedPerc="$(df -kP / | tail -1 | awk '{print $5}'| sed s'/%$//')"
    RootFreePerc="$(expr 100 - $RootUsedPerc)"

    DataFreeB="$(df -kP /mnt/data | tail -1 | awk '{print $4}')"
    DataUsedB="$(df -kP /mnt/data | tail -1 | awk '{print $3}')"
    DataTotalB="$(df -kP /mnt/data | tail -1 | awk '{print $2}')"
    DataFree="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$DataFreeB/1024/1024))"
    DataUsed="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$DataUsedB/1024/1024))"
    DataTotal="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$DataTotalB/1024/1024))"
    DataUsedPerc="$(df -kP /mnt/data | tail -1 | awk '{print $5}'| sed s'/%$//')"
    DataFreePerc="$(expr 100 - $DataUsedPerc)"

    VarFreeB="$(df -kP /var | tail -1 | awk '{print $4}')"
    VarUsedB="$(df -kP /var | tail -1 | awk '{print $3}')"
    VarTotalB="$(df -kP /var | tail -1 | awk '{print $2}')"
    VarFree="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$VarFreeB/1024/1024))"
    VarUsed="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$VarUsedB/1024/1024))"
    VarTotal="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$VarTotalB/1024/1024))"
    VarUsedPerc="$(df -kP /var | tail -1 | awk '{print $5}'| sed s'/%$//')"
    VarFreePerc="$(expr 100 - $VarUsedPerc)"

    TmpFreeB="$(df -kP /tmp | tail -1 | awk '{print $4}')"
    TmpUsedB="$(df -kP /tmp | tail -1 | awk '{print $3}')"
    TmpTotalB="$(df -kP /tmp | tail -1 | awk '{print $2}')"
    TmpFree="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$TmpFreeB/1024/1024))"
    TmpUsed="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$TmpUsedB/1024/1024))"
    TmpTotal="$(printf "%0.2f\n" $(bc -q <<< scale=2\;$TmpTotalB/1024/1024))"
    TmpUsedPerc="$(df -kP /tmp | tail -1 | awk '{print $5}'| sed s'/%$//')"
    TmpFreePerc="$(expr 100 - $TmpUsedPerc)"

    UpdateCount="$(cat /var/tmp/updatecount.txt)"
    SessionCount="$(who | grep $USER | wc -l)"
    ProcessCount="$(ps -Afl | wc -l)"
    ProcessMax="$(ulimit -u)"
    PhpVersion="$(/usr/bin/php -v 2>/dev/null | grep -oE '^PHP\s[0-9]+\.[0-9]+\.[0-9]+' | awk '{ print $2}')"
    DockerVersion="$(/usr/bin/docker --version 2>/dev/null | grep -oE '^Docker\sversion\s[0-9]+\.[0-9]+\.[0-9]+' | awk '{ print $3 }')"
    GitVersion="$(/usr/bin/git --version 2>/dev/null | grep -oE '^git\sversion\s[0-9]+\.[0-9]+\.[0-9]+' | awk '{ print $3 }')"
    MaxLeftOverChars=35
    Hostname="$(hostname)"
    HostChars=$((${#Hostname} + 8))
    LeftoverChars=$((MaxLeftOverChars - HostCHars -10))
    if [[ -x "/usr/bin/yum" ]] ; then
        UpdateType="yum"
    elif [[ -x "/usr/bin/zypper" ]] ; then
        UpdateType="zypper"
    elif [[ -x "/usr/bin/apt-get" ]] ; then
        UpdateType="apt-get"
    fi
    WriteLog Verbose Info "UpdateType: $UpdateType"
    HttpdPath="$(which httpd 2>/dev/null)"
    WriteLog Verbose Info "HttpdPath: $HttpdPath"
    if [[ ! -z $HttpdPath ]] ; then
        HttpdVersion="$(${HttpdPath} -v | grep "Server version" | sed -e 's/.*[^0-9]\([0-9].[0-9]\+.[0-9]\+\)[^0-9]*$/\1/')"
        WriteLog Verbose Info "HttpdVersion: $HttpdVersion"
    fi
    case $UpdateType in
        "yum" )
            MariadbVersion="$(rpm -qa | grep mariadb-server | sed 's/.*-\(\([0-9]\+\.[0-9]\+\.[0-9]\+-[0-9]\+\)\).*/\1/')"
            WriteLog Verbose Info "MariadbVersion: $MariadbVersion" ;;
        *) WriteLog Verbose Info "$UpdateType not yet supported." ;;
    esac
}

GenerateOriginal256Color () {
    Space=""
    if [[ "$Theme" == "Modern" ]] ; then
        Space="                              "
        Fto="  "
    else
        Fto="##"
    fi
    echo -e "$BlueScheme$LongBlueScheme$BlueScheme$ShortBlueScheme
\e[0;38;5;17m$Fto          \e[38;5;39mIp \e[38;5;93m= \e[38;5;33m$IpAddress
\e[0;38;5;17m$Fto     \e[38;5;39mRelease \e[38;5;93m= \e[38;5;27m$OsVersion
\e[0;38;5;17m$Fto      \e[38;5;39mKernel \e[38;5;93m= \e[38;5;27m$Kernel
\e[0;38;5;17m$Fto    \e[38;5;39mPlatform \e[38;5;93m= \e[38;5;27m$Platform
\e[0;38;5;17m$Fto      \e[38;5;39mUptime \e[38;5;93m= \e[38;5;33m${UptimeDays} \e[38;5;27mday(s). \e[38;5;33m${UptimeHours}\e[38;5;27m:\e[38;5;33m${UptimeMinutes}\e[38;5;27m:\e[38;5;33m${UptimeSeconds}
\e[0;38;5;17m$Fto   \e[38;5;39mCPU Usage \e[38;5;93m= \e[38;5;33m${CpuUtil}\e[38;5;27m% average CPU usage over \e[38;5;33m$CpuProc \e[38;5;27mcore(s)
\e[0;38;5;17m$Fto    \e[38;5;39mCPU Load \e[38;5;93m= \e[38;5;27m$CpuLoad
\e[0;38;5;17m$Fto      \e[38;5;39mMemory \e[38;5;93m= \e[38;5;27mFree: \e[38;5;33m${MemFree}\e[38;5;27mGB (\e[38;5;33m$MemFreePerc\e[38;5;27m%), Used: \e[38;5;33m${MemUsed}\e[38;5;27mGB (\e[38;5;33m$MemUsedPerc\e[38;5;27m%), Total: \e[38;5;33m${MemTotal}\e[38;5;27mGB
\e[0;38;5;17m$Fto        \e[38;5;39mSwap \e[38;5;93m= \e[38;5;27mFree: \e[38;5;33m${SwapFree}\e[38;5;27mGB (\e[38;5;33m$SwapFreePerc\e[38;5;27m%), Used: \e[38;5;33m${SwapUsed}\e[38;5;27mGB (\e[38;5;33m$SwapUsedPerc\e[38;5;27m%), Total: \e[38;5;33m${SwapTotal}\e[38;5;27mGB
\e[0;38;5;17m$Fto        \e[38;5;39mRoot \e[38;5;93m= \e[38;5;27mFree: \e[38;5;33m${RootFree}\e[38;5;27mGB (\e[38;5;33m$RootFreePerc\e[38;5;27m%), Used: \e[38;5;33m${RootUsed}\e[38;5;27mGB (\e[38;5;33m$RootUsedPerc\e[38;5;27m%), Total: \e[38;5;33m${RootTotal}\e[38;5;27mGB
\e[0;38;5;17m$Fto   \e[38;5;39m/Mnt/Data \e[38;5;93m= \e[38;5;27mFree: \e[38;5;33m${DataFree}\e[38;5;27mGB (\e[38;5;33m$DataFreePerc\e[38;5;27m%), Used: \e[38;5;33m${DataUsed}\e[38;5;27mGB (\e[38;5;33m$DataUsedPerc\e[38;5;27m%), Total: \e[38;5;33m${DataTotal}\e[38;5;27mGB
\e[0;38;5;17m$Fto        \e[38;5;39mVar  \e[38;5;93m= \e[38;5;27mFree: \e[38;5;33m${VarFree}\e[38;5;27mGB (\e[38;5;33m$VarFreePerc\e[38;5;27m%), Used: \e[38;5;33m${VarUsed}\e[38;5;27mGB (\e[38;5;33m$VarUsedPerc\e[38;5;27m%), Total: \e[38;5;33m${VarTotal}\e[38;5;27mGB
\e[0;38;5;17m$Fto        \e[38;5;39mTmp  \e[38;5;93m= \e[38;5;27mFree: \e[38;5;33m${TmpFree}\e[38;5;27mGB (\e[38;5;33m$TmpFreePerc\e[38;5;27m%), Used: \e[38;5;33m${TmpUsed}\e[38;5;27mGB (\e[38;5;33m$TmpUsedPerc\e[38;5;27m%), Total: \e[38;5;33m${TmpTotal}\e[38;5;27mGB
\e[0;38;5;17m$Fto     \e[38;5;39mUpdates \e[38;5;93m= \e[38;5;33m$UpdateCount\e[38;5;27m ${UpdateType} updates available
\e[0;38;5;17m$Fto    \e[38;5;39mSessions \e[38;5;93m= \e[38;5;33m$SessionCount\e[38;5;27m sessions
\e[0;38;5;17m$Fto   \e[38;5;39mProcesses \e[38;5;93m= \e[38;5;33m$ProcessCount\e[38;5;27m running processes of \e[38;5;33m$ProcessMax\e[38;5;27m maximum processes"
    if [[ $PhpVersion =~ ^[0-9.]+$ ]] ; then
        echo -e "\e[0;38;5;17m$Fto         \e[38;5;39mPHP \e[38;5;93m= \e[38;5;27mVersion: \e[38;5;33m$PhpVersion"
    fi
    if [[ $DockerVersion =~ ^[0-9.]+$ ]] ; then
        echo -e "\e[0;38;5;17m$Fto      \e[38;5;39mDocker \e[38;5;93m= \e[38;5;27mVersion: \e[38;5;33m$DockerVersion"
    fi
    if [[ $GitVersion =~ ^[0-9.]+$ ]] ; then
        echo -e "\e[0;38;5;17m$Fto         \e[38;5;39mGit \e[38;5;93m= \e[38;5;27mVersion: \e[38;5;33m$GitVersion"
    fi
    if [[ $HttpdVersion =~ ^[0-9.]+$ ]] ; then
        echo -e "\e[0;38;5;17m$Fto      \e[38;5;39mApache \e[38;5;93m= \e[38;5;27mVersion: \e[38;5;33m$HttpdVersion"
    fi
    if [[ $MariadbVersion =~ ^[0-9.-]+$ ]] ; then
        echo -e "\e[0;38;5;17m$Fto     \e[38;5;39mMariaDB \e[38;5;93m= \e[38;5;27mVersion: \e[38;5;33m$MariadbVersion"
    fi
    echo -e "$BlueScheme$LongBlueScheme$BlueScheme$ShortBlueScheme\e[0;37m"
}

GatherInfo ;
GenerateOriginal256Color ;

exit 0