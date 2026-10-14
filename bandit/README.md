# Over the Wire

bandit.labs.overthewire.org
2220
bandit0
próximo níivel: ssh [bandit6@bandit.labs.overthewire.org](mailto:bandit6@bandit.labs.overthewire.org) -p 2220

1. ls; cat readme
    
    6y2kwnwK6grgvwvpvLaa2T1cpFEKOhNR
    
2. ls; ./-
    
    PK8fYLZg2hnHSz83plBL1iEPKdD3QToB
    
3.  ****ls; cat './--spaces in this filename--’
    
    7ZZ2LFrykP2zEyvBl4m3clcL7tGYJPME
    
4. ls; cd inhere; ls -a; cat ...Hiding-From-You
    
    xzTXq1rDJQVVAzdv5cHq1TQytTWufAMq
    
5. ls; cd inhere; ls -la; file ./*; cat ./-file07
    
    6C7h9GD8M6ai5nr7wo1RonrzFjj9yIrG
    
6. ls; cd inhere; ls -la; find -readable -size 1033c; cat./maybehere07/.file2; 
    
    pXa26xhMWaC2SvDotA4r9EgZkulOeSBW
    
7. find / -user bandit7 -group bandit6 -size 33c 2>/dev/null; cat /var/lib/dpkg/info/bandit7.password
    
    Bmnnvf82KzQlfxgAI2d1zYbr1u9pr3E3
    
8. grep millionth data.txt
    
    VR1ljMayciFxbnUokuQmJFw6QC9VKtub
    
9. sort data.txt | uniq -u
    
    EjmOSvuAu7sGAHqHVcBDPirRe9T03kxl
    
10. strings data.txt | grep === ou cat data.txt | grep -a ==========
    
    B0s2khmbT9u0geKuOoVGW3JZKhndE3BG
    
11. base64 -d data.txt ou cat data.txt | base64 -d
    
    pYfOY6HwUsDj5rL9UvyhU7MCmv8vN5Ro
    
12. cat data.txt e colocar no site rot13 ou cat data.txt | tr 'A-Za-z' 'N-ZA-Mn-za-m’
    
    GROozWPO8QyN0mGrjUkID0WCYkZiQxrN
    
13. 
    
    ```jsx
    # Preparação
    mktemp -d                      # cria uma pasta temporária
    cd /tmp/tmp.XXXXX              # entra nela (use o caminho que apareceu)
    cp ~/data.txt .                # copia o arquivo para a pasta
    xxd -r data.txt dados          # desfaz o hexdump
    
    # 1ª volta - gzip
    file dados
    mv dados dados.gz
    gzip -d dados.gz
    
    # 2ª volta - bzip2
    file dados
    mv dados dados.bz2
    bzip2 -d dados.bz2
    
    # 3ª volta - gzip
    file dados
    mv dados dados.gz
    gzip -d dados.gz
    
    # 4ª volta - tar
    file dados
    mv dados dados.tar
    tar -xf dados.tar
    ls
    mv data5.bin dados
    
    # 5ª volta - tar
    file dados
    mv dados dados.tar
    tar -xf dados.tar
    ls
    mv data6.bin dados
    
    # 6ª volta - bzip2
    file dados
    mv dados dados.bz2
    bzip2 -d dados.bz2
    
    # 7ª volta - tar
    file dados
    mv dados dados.tar
    tar -xf dados.tar
    ls
    mv data8.bin dados
    
    # 8ª volta - gzip
    file dados
    mv dados dados.gz
    gzip -d dados.gz
    
    # Final
    file dados                     # ASCII text
    cat dados                      # mostra a senha
    ```
    
    ![image.png](image.png)
    
    qQYQiHOBPR8zR61qxYqX45quvihF2uzk
    
14. ls; exit
    1. terminal do computador: 
    
    ```jsx
    # 2. No seu computador (PowerShell)
    scp -P 2220 bandit13@bandit.labs.overthewire.org:sshkey.private .
                                   # baixa a chave (pede a senha do bandit13)
    
    # 3. Só se der erro de "UNPROTECTED PRIVATE KEY FILE"
    icacls sshkey.private /inheritance:r
    icacls sshkey.private /grant:r "${env:USERNAME}:R"
                                   # deixa só você com acesso à chave
    
    # 4. Entrar como bandit14 usando a chave
    ssh -i sshkey.private bandit14@bandit.labs.overthewire.org -p 2220
    
    #5 sair
    exit
    
    #6 ler a senha
    cat /etc/bandit_pass/bandit14
    ```
    
    aaWecNkG4FhxJQxz07uiwzVP6bJiYS65
    
15. nc [localhost](http://localhost) 30000 e colar a senha anterior (enquanto carrega)
    
    pbLYuZtTg4MgaqfJx8jbA9gKKGqM68A7
    
16. ncat localhost --ssl 30001
    
    kS0Hf0u5HiXFwKMKFqXvPdOTNGGa0X8V
    
17. Moba: nmap -p 31000-32000 localhost; openssl s_client -connect localhost:PORTA -quiet; colar senha anterior; mktemp -d; cd /tmp/tmp.XXXXX; vi bandit17.key; cat bandit17.key
    
    Powershell: scp -P 2220 [bandit16@bandit.labs.overthewire.org](mailto:bandit16@bandit.labs.overthewire.org):/tmp/tmp.XXXXX/bandit17.key .
    se pedir senha é a anterior
    icacls bandit17.key /inheritance:r
    icacls bandit17.key /grant:r "${env:USERNAME}:R"
    ssh -i bandit17.key [bandit17@bandit.labs.overthewire.org](mailto:bandit17@bandit.labs.overthewire.org) -p 2220
    
    pWXMAZoxGC8JmDMfmT5MGEsobMM3vnj2
    
18. ls; diff passwords.new passwords.old
    
    OQxXZjELndr90zuhOTDYBEomI0SZITXI
    
19. CMD: ssh [bandit18@bandit.labs.overthewire.org](mailto:bandit18@bandit.labs.overthewire.org) -p 2220 cat readme; senha do 18
    
    KpsOfPkcP7i1FlIExk2QEjyt6dw8dxZI
    
20. ls -l; ./ bandit20-do; ./bandit20-do cat /etc/bandit_pass/bandit20
    
    4pIjcunZ0fK2vmp3IwfG8Vf7VhxD6pOA
    
21. Terminal 1: nc -l -p 45678
Terminal 2: ./suconnect 45678
Terminal 1: senha anterior
bW9kBv5WC3P4yoDyf12LSdGuNz5ka6hY
22. ls /etc/cron.d/; cat /etc/cron.d/cronjob_bandit22; cat /usr/bin/cronjob_bandit22.sh
    
    RYVux2rHEm9tiXHmLFzuR7Vhx6AZQMEz
    
23. cat /etc/cron.d/cronjob_bandit23; cat /usr/bin/cronjob_bandit23.sh; echo I am user bandit23 | md5sum; cat /tmp/CODIGO_QUE_APARECEU
    
    gKXDTAXnIz3OBxiPjRZ2uqutUlPZrBsw
    
24. cat /etc/cron.d/cronjob_bandit24; cat /usr/bin/cronjob_bandit24.sh; mktemp -d; cd /tmp/tmp.XXXXX; chmod 777 .; vi [script.sh](http://script.sh) (#!/bin/bash cat /etc/bandit_pass/bandit24 > /tmp/tmp.XXXXX/senha.txt); chmod 777 script.sh; cp [script.sh](http://script.sh/) /var/spool/bandit24/foo/; ls; cat senha.txt
    
    hVQMk3lJNsmQ7VF3ubyrNNBom7BOgVXv
    
25. cat /etc/bandit_pass/bandit24; mktemp -d; cd /tmp/tmp.XXXXX; for i in {0000..9999}; do echo "COLE_A_SENHA_AQUI $i"; done > tentativas.txt; head tentativas.txt; wc -l tentativas.txt; cat tentativas.txt | nc -q 2 localhost 30002 > resultado.txt; grep -v "Wrong" resultado.txt
    
    SoHfqMOEqIX2IYKVciZxvgpR9a2Djx4P
    
26. CMD: cd %USERPROFILE%; scp -P 2220 [bandit25@bandit.labs.overthewire.org](mailto:bandit25@bandit.labs.overthewire.org):bandit26.sshkey .; dimuinuir a tela (5 linhas); ssh -i bandit26.sshkey [bandit26@bandit.labs.overthewire.org](mailto:bandit26@bandit.labs.overthewire.org) -p 2220; com More na tela apertar “v”; :set shell=/bin/bash; :shell; whoami; ls; ./bandit27-do cat /etc/bandit_pass/bandit27
STJLJBRRphMxKB392CT4iOr5CbzPU9ER
27. CMD: git --version; cd %USERPROFILE%; git clone ssh://bandit27-git@bandit.labs.overthewire.org:2220/home/bandit27-git/repo; senha anterior; cd repo; dir; type README
    
    y8Yd2ssKcpHpud7UvOSOxwamRMzIGIeQ
    
28. CMD: cd %USERPROFILE%; git clone ssh://bandit28-git@bandit.labs.overthewire.org:2220/home/bandit28-git/repo repo28; senha anterior; cd repo28; type README.ms; git log; git show; git log -p
    
    Em7eGtqaMySwNFjCpwzzHhLhospOcdt0
    
29. CMD: cd %USERPROFILE%; git clone ssh://bandit29-git@bandit.labs.overthewire.org:2220/home/bandit29-git/repo repo29; senha anterior; cd repo29, type README.md; git branch -a; git checkout dev; type [README.md](http://readme.md/)
    
    jq9Dfg2rXsfYsWMgFuKlXhphjdH7USgX
    
30. CMD: cd %USERPROFILE%; git clone ssh://bandit30-git@bandit.labs.overthewire.org:2220/home/bandit30-git/repo repo30; senha anterior; cd repo30; type [README.md](http://readme.md/); git log; git branch -a; git tag; git show secret
    
    82NkymblpGBYmIXG6ZQ8YldBYstHpfUf
    
31. CMD: cd %USERPROFILE%; git clone ssh://bandit31-git@bandit.labs.overthewire.org:2220/home/bandit31-git/repo repo31; senha anterior; cd repo31; type [README.md](http://readme.md/); echo May I come in?> key.txt; type key.txt; git add -f key.txt; git status; git commit -m "add key"; git push; senha anterior
    
    pWuj5jBQ6IgV0NXwiH6g1pXRF8S1YvbT
    
32. $0; whoami; cat /etc/bandit_pass/bandit33
    
    u4P2CyPOwPGLe94RdD9Uo2FxFwvnFswM