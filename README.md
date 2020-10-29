`./sshp.sh ssh root@...` or `./sshp.sh scp ...`

推荐在.bashrc或.zshrc中加上

```
alias ssh='sshp /usr/bin/ssh'
alias scp='sshp /usr/bin/scp'
```

