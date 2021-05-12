#!/bin/zsh

# 自定义密码存放文件，可以直接在文件中加入账户和密码，格式为账户+空格+密码，例: `root@192.0.1.3 abcd`
# 如果没有，连接时会请求输入密码，如果连接出错，会删除对应的账户以及密码
PASSPATH=~/.ssh/passwd_record
# 可以选择使用什么方式登陆，0:使用sshpass命令行工具 (需要安装sshpass) 1:使用我自己写的expect方法 (需要安装expect)
USECMD=0
# 当选择expect时，可选择是否显示输入密码的过程，为1时显示，为0时不显示（但同时也会隐藏一些额外的登陆信息）
SHOW_MSG=0

TIMEOUT=30

# 下面不要改
[[ $USECMD == 0 && x$(which sshpass) == x ]] && echo "需要安装sshpass" && exit 1
[[ $USECMD == 1 && x$(which expect) == x ]] && echo "需要安装expect" && exit 1

[ $# -lt 2 ] && echo "参数过少" && exit 1
PASSWD=
COMM=($@)
CMD=$1
LINK=`echo "$COMM" | grep -oE "\w{1,}@\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"`

declare -A sshpassErr
sshpassErr[1]="INVALID_ARGUMENTS"
sshpassErr[2]="CONFLICTING_ARGUMENTS"
sshpassErr[3]="RUNTIME_ERROR"
sshpassErr[4]="PARSE_ERRROR"
sshpassErr[5]="INCORRECT_PASSWORD"
sshpassErr[6]="HOST_KEY_UNKNOWN"

if [[ x$LINK == x ]]; then
    if [[ x${1##*/} == x"ssh" ]]; then
        LINK=$2
    elif [[ x${1##*/} == x"scp" ]]; then
        LINK=`echo "$COMM" | sed 's/^.* \([^ ]*\):.*$/\1/g'`
    else
        exit 1
    fi
fi

if [[ $# -gt 2 ]]; then
    TIMEOUT=-1
fi

if [[ x${1##*/} == x"ssh" ]] && [[ $# -eq 2 ]]; then
    COMM=(${COMM[1]} -o StrictHostKeyChecking=no -o ServerAliveInterval=30 ${COMM[@]:1})
fi

if [ ! -f $PASSPATH ]; then
    touch $PASSPATH
    [ $? != 0 ] && echo "无法创建: "$PASSPATH && exit 1
fi

TAG=`awk '{if($1=="'$LINK'"){print "1"$2;exit}}' $PASSPATH`
PASSWD=${TAG: 1}
if [[ x$TAG == x ]]; then
    echo -n "Password:"
    read -s PASSWD
    echo
    echo "$LINK $PASSWD" >> $PASSPATH
fi

if [[ x$TAG == x1 ]]; then
    SHOW_MSG=1
fi

function tran2expect() {
    declare -A trans=(['\']='\\' ['}']='\}' ['[']='\[' ['$']='\$' ['`']='\`' ['"']='\"')
    for k in '\' '}' '[' '$' '`' '"'
    do
        PASSWD=${PASSWD/${k}/${trans[$k]}}
    done
}

function eraseDarwin() {
    echo 2 && sed -i \"\" -e \"/^$LINK .*/d\" $PASSPATH
}

if [[ $(uname) == "Darwin" ]]; then
    DELRECORD="sed -i \"\" -e \"/^$LINK .*/d\" $PASSPATH"
elif [[ $(uname) == "Linux" ]]; then
    DELRECORD="sed -i \"/^$LINK .*/d\" $PASSPATH"
fi

function delPW() {
    echo -n 'remove password? (y/n) '
    read x
    if [ ! -z $x ] && [ $x = "Y" -o $x = "y" -o $x = "yes" ];then
        zsh -c $DELRECORD
        echo "ok"
    fi
}

function exsshpass() {
    CV_COMM=`echo $COMM | sed -E 's/;/\\\\;/g' | sed -E 's/\\$/\\\\$/g'`
    expect -c "
    log_user 0
    proc delPW {} {
        send_user -- \"remove password? (y/n) \"
        expect_user -re \"(.*)\\n\"
        set tag \$expect_out(1,string)
        if { "'$tag'" eq \"y\" } {
            exec $DELRECORD
            send_user \"ok\\n\"
        }
    }
    set timeout $TIMEOUT
    spawn $CV_COMM
    log_user $SHOW_MSG
    set x 0
    expect {
        \"Are you sure you want to continue connecting*\" {send \"yes\\r\"; exp_continue}
        \"s password:*\" {
            if { "'$x'" eq 0 } {
                set x 1
                send \"$PASSWD\\r\"
                log_user 1
                if { $TIMEOUT != -1 } {
                    exp_continue
                }
            } else {
                exec $DELRECORD
                exit 1
            }
        }
        \"Enter passphrase*\" {send \"$PASSWD\\r\"; log_user 1; exp_continue}
        \"*please try again*\" {exec $DELRECORD; exit 1}
        \"Last login*\" {}
        \"*\\[#\\\\\\$]\" {}
        \"*Connection*\" {log_user 1; send_user \"\$expect_out(buffer)\"; delPW; exit 1}
        timeout {log_user 1; send_user \"请求超时\\n\"; delPW; exit 1}
    }
    interact
    " 2> /dev/null
}

while true
do
    sleep 3.5
    if ! ps x | grep -v grep | grep -q 'nc -l 2000'; then
        while true;
        do
            msg=`nc -l 2000 2>/dev/null`
            if [ "${msg}" != "" ];then
                echo -nE "${msg}"|pbcopy
            fi
        done &
        cpid=$!
        while ps x|grep -v grep|awk '{print $5}'|egrep -q '^('"${PATH//:/|}"')?/?ssh$'
        do
            sleep 3
        done
        kill -9 $cpid
        echo -n | nc localhost 2000
    fi
    break
done >/dev/null 2>&1 &
disown

if [[ x$USECMD == x0 ]]; then
    # sshpass 版本
    sshpass -p "$PASSWD" ${COMM[@]}
    ret=$?
    if [ $ret -gt 0 -a $ret -lt 7 ]; then
        echo ${sshpassErr[$ret]}
        delPW
    fi
elif [[ x$USECMD == x1 ]]; then
    # expect  版本
    tran2expect
    exsshpass
fi
