#!/bin/bash

# 自定义密码存放文件，可以直接在文件中加入账户和密码，格式为账户+空格+密码，例: `root@192.0.1.3 abcd`
# 如果没有，连接时会请求输入密码，如果连接出错，会删除对应的账户以及密码
PASSPATH=~/.ssh/passwd_record
# 可以选择使用什么方式登陆，0:使用sshpass命令行工具 (需要安装sshpass) 1:使用我自己写的expect方法 (需要安装expect)
USECMD=1

# 下面不要改
[ x$(which sshpass) == x  ] && echo "需要安装sshpass" && exit 1
[ x$(which expect) == x  ] && echo "需要安装expect" && exit 1

[ $# -lt 2 ] && echo "参数过少" && exit 1
PASSWD=
COMM=$@
CMD=$1
LINK=`echo "$COMM" | grep -oE "\w{1,}@\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"`

if [ x$LINK == x ]; then
    if [ x${CMD##*/} == x"ssh" ]; then
        LINK=$2
    elif [ x${CMD##*/} == x"scp" ]; then
        LINK=`echo "$COMM" | sed 's/^.* \([^ ]*\):.*$/\1/g'`
    else
        exit 1
    fi
fi

if [ ! -f "$PASSPATH" ]; then
    touch $PASSPATH
    [ $? != 0 ] && echo "无法创建: "$PASSPATH && exit 1
fi

TAG=`awk '{if($1=="'$LINK'"){print "1"$2;exit}}' $PASSPATH`
PASSWD=${TAG: 1}
if [ x$TAG == x ]; then
    echo -n "Password:"
    read -s PASSWD
    echo
    echo "$LINK $PASSWD" >> $PASSPATH
fi

if [ $(uname) == "Darwin" ]; then
    DELRECORD="sed -i '' -e \"/^$LINK .*/d\" $PASSPATH"
elif [ $(uname) == "Linux" ]; then
    DELRECORD="sed -i '/^$LINK .*/d' $PASSPATH"
fi

function exsshpass() {
    expect -c "
    log_user 0
    set timeout 5
    spawn $COMM
    expect {
        \"Are you sure you want to continue connecting*\" {send \"yes\\r\"; exp_continue}
        \"s password:*\" {send \"$PASSWD\\r\"}
        \"Enter passphrase*\" {send \"$PASSWD\\r\"}
        \"*Connection refused*\" {set x [exec $DELRECORD]; log_user 1; send_user \"\$expect_out(buffer)\"; exit 1}
        timeout {set x [exec $DELRECORD]; log_user 1; send_user \"请求超时\"; exit 1}
    }
    set timeout 0
    expect {
        \"*please try again*\" {set x [exec $DELRECORD]; log_user 1; send_user \"\$expect_out(buffer)\"; exit 1}
    }
    log_user 1
    interact
    exit 0
    "
}

if [ x$TAG == x1 ]; then
    $COMM
else
    if [ x$USECMD == x0 ]; then
        # sshpass 版本
        sshpass -p "$PASSWD" $COMM
    elif [ x$USECMD == x1 ]; then
        # expect  版本
        exsshpass
    fi
fi
