使用情况: 需要输入密码连接服务器，不能够在服务器上存储公钥

`./sshp.sh ssh root@...` or `./sshp.sh scp ...`

推荐在.bashrc或.zshrc中加上

```
alias ssh='sshp /usr/bin/ssh'
alias scp='sshp /usr/bin/scp'
```

运行时，无需密码则在提示输入密码出回车即可
