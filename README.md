适用情况: 需要输入密码连接服务器，不能够在服务器上存储公钥

---

sshp.sh 文件前几行可以自行修改

需要安装 sshpass 或 expect，默认使用expect，可在sshp.sh第7行修改

使用sshpass缺点 : 如果密码输入错误的话需要手动去保存密码的文件中删除

---

使用方式

`./sshp.sh ssh ...` or `./sshp.sh scp ...`

推荐在.bashrc或.zshrc中加上，例如

```
alias ssh='~/sshp.sh /usr/bin/ssh'
alias scp='~/sshp.sh /usr/bin/scp'
```

或将该文件放到环境变量中然后

```
alias ssh='sshp.sh /usr/bin/ssh'
alias scp='sshp.sh /usr/bin/scp'
```

首次登陆服务器时，若无密码则在提示输入密码时回车即可
