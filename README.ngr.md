*my personal notes for running the openldap container*

**create dummy certs for openldap container**

``` bash
mkdir -p openldap/certs
```

``` bash
cd openldap/certs
```

**Generate a 4096-bit RSA root private key**
``` bash
openssl genrsa -out openldap/certs/lanathome.org-root.key 4096
```




**Create the self-signed Root CA certificate (valid for 10 years)**
``` bash
openssl req -x509 -new -nodes -key openldap/certs/lanathome.org-root.key -sha256 -days 3650 \
  -subj "/C=FR/ST=/L=SAINT-PIERRE en FAUCIGNY/O=Lanathome/OU=IT/CN=Lanathome.org Root CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -out openldap/certs/lanathome.org-root.crt
```


**Generate host private key**
``` bash
openssl genrsa -out openldap/certs/ldap.lanathome.org.key 2048
```


**Create a CSR for ldap.lanathome.org**
``` bash
openssl req -new -key openldap/certs/ldap.lanathome.org.key \
  -subj "/C=FR/ST=/L=SAINT-PIERRE en FAUCIGNY/O=Lanathome/OU=IT/CN=ldap.lanathome.org" \
  -out openldap/certs/ldap.lanathome.org.csr
```

``` bash
vi openldap/certs/ldap.ext

authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ldap.lanathome.org
```

**Sign the CSR with your Root CA:**
``` bash
openssl x509 -req -in openldap/certs/ldap.lanathome.org.csr \
  -CA openldap/certs/lanathome.org-root.crt -CAkey openldap/certs/lanathome.org-root.key -CAcreateserial \
  -out openldap/certs/ldap.lanathome.org.crt -days 825 -sha256 -extfile openldap/certs/ldap.ext
```



**Verify and Deploy**

**Verify the chain against your Root CA:**
``` bash
openssl verify -CAfile openldap/certs/lanathome.org-root.crt openldap/certs/ldap.lanathome.org.crt
```



**get latest openldap container image**

``` bash
podman pull quay.io/agrosshans/ngr-container-openldap:latest
``` 


**create rootfull network for openldap and phpldapadmin containers**
``` bash
sudo podman network create --driver bridge \
  --subnet 10.89.12.0/24 \
  --gateway 10.89.12.1 \
  phpldapadmin-bridge
```

**run openldap container with the following command**

``` bash
sudo podman run --name openldap --hostname ldap.lanathome.org \
  --ip 10.89.12.10 \
  --publish 3890:3890 \
  --publish 6360:6360 \
  --network phpldapadmin-bridge \
  --volume openldap/certs:/container/services/openldap/assets/certs:Z \
  --env-file openldap/.env \
  quay.io/agrosshans/ngr-container-openldap
```

**change ownership of the certs directory to the user and group id used by the openldap container**

[Rootless Podman makes sense](https://www.redhat.com/it/blog/rootless-podman-makes-sense)

[Advanced containers with Podman](https://medium.com/@maros.kukan/advanced-containers-with-podman-f79302de85b0)


then it looks like this:


``` bash
-rw-r--r--. 1 911 911       ./openldap/certs/lanathome.org-root.srl
-rw-r--r--. 1 524288 524288 ./phpldapadmin/certs/phpldapadmin.lanathome.org.crt
```





**Display the UID and GID for current user within the container**
``` bash
 sudo podman exec openldap /usr/bin/id
uid=911(ldap) gid=911(ldap) groups=911(ldap)
```


**Confirm the host user that runs the process**

``` bash
$ ps -o pid,user,cmd -p $(sudo podman inspect openldap -f {{.State.Pid}})
    PID USER     CMD
 169582 911      /usr/sbin/container
```

``` bash
$ podman unshare cat /proc/self/uid_map
         0       1000          1
         1     524288      65536
```

``` bash
$ podman unshare chown -R 911:911 ./openldap/certs/
```




``` bash
$ podman unshare chown -R 911:911 ./phpldapadmin/certs/
```



**run phpldapadmin container with the following command**

``` bash
sudo podman run --name phpldapadmin --hostname phpldapadmin.lanathome.org \
  --network phpldapadmin-bridge \
  --ip 10.89.12.20 \
  --publish 9080:80/tcp \
  --publish 9443:443/tcp \
  --volume phpldapadmin/certs:/container/service/phpldapadmin/assets/apache2/certs:Z \
  --env-file phpldapadmin/.env \
docker.io/phpldapadmin/phpldapadmin:latest
```

**check the network interface and ip address of the rootfull network created for openldap and phpldapadmin containers**

``` bash
$ sudo ip -br a 
[sudo] password for ngr: 
lo               UNKNOWN        127.0.0.1/8 ::1/128 
wlo1             UP             172.27.68.118/22 fe80::8301:8fd8:a988:b898/64 
virbr0           DOWN           192.168.124.1/24 
podman6          UP             10.89.12.1/24 fe80::4c90:deff:fe13:86c7/64 
veth1@if2        UP             fe80::80e4:b1ff:fe7c:f3f7/64 
veth0@if2        UP             fe80::602d:b3ff:fe7b:6768/64 
```

**add the rootfull network interface and ip address to the systemd-resolved configuration**

``` bash
$ sudo resolvectl dns podman6 10.89.12.1
$ sudo resolvectl domain podman6 "~podman" "~lanathome.org"
```

**Verify Resolution**

Test that the host resolves the domain using resolvectl (avoid nslookup or dig, as they often bypass systemd-resolved unless pointed directly at 127.0.0.53):

``` bash
$ resolvectl query ldap.lanathome.org
ldap.lanathome.org: 10.89.12.10                -- link: podman6

-- Information acquired via protocol DNS in 1.1ms.
-- Data is authenticated: no; Data was acquired via local or encrypted transport: no
-- Data from: network
``` 

**change the admin password**

``` bash
sudo podman exec -it openldap bash
```

``` bash
ldap:/$ cat /etc/openldap/slapd.d/cn=config/olcDatabase={0}config.ldif
# AUTO-GENERATED FILE - DO NOT EDIT!! Use ldapmodify.
# CRC32 e4944e36
dn: olcDatabase={0}config
objectClass: olcDatabaseConfig
olcDatabase: {0}config
olcAccess: {0}to * by * none
olcRootDN: cn=admin,cn=config
olcRootPW:: e0FSR09OMn0kYXJnb24yaWQkdj0xOSRtPTcxNjgsdD01LHA9MSQwWWZEUmpFb2R0az
 JIb0ZiRWhKV0lBJFBFU0R4cllWY3g0dS9USitoMVZGUkNQbFozMXNCWnJHc2d4ZEkvRnNYems=
structuralObjectClass: olcDatabaseConfig
entryUUID: cf92b09b-dfa0-4057-b441-3d60543329a5
creatorsName: cn=config
createTimestamp: 20261125101100Z
entryCSN: 20261125101100.344272Z#000000#000#000000
modifiersName: cn=config
modifyTimestamp: 20261125101100Z
```

**change the admin password with slappasswd command**
``` bash
ldap:/$ slappasswd -s xxxxxxxxxx
{SSHA}NAEqORXJ9uaJ4hnBSLWyW7lRyIBw3fdS
```

**and copy the output to the olcRootPW attribute in the olcDatabase={0}config.ldif file**

``` bash
ldap:/$ vi /etc/openldap/slapd.d/cn=config/olcDatabase={0}config.ldif
[...]
olcRootPW: {SSHA}NAEqORXJ9uaJ4hnBSLWyW7lRyIBw3fdS               
```


**add other users to the admin group by creating a new ldif file and applying it with ldapmodify**


**copy admin-rights.ldif**
``` bash
sudo podman cp openldap/admin-rights.ldif openldap:/admin-rights.ldif
```

**copy lanathome_org.ldif**
``` bash
sudo podman cp openldap/lanathome_org.ldif openldap:/lanathome_org.ldif
```


**apply with ldapmodify**

``` bash
ldap:/$ ldapmodify -x -D "cn=admin,cn=config" -w xxxxxxxxxx -H ldapi:/// -f /admin-rights.ldif
```

**check the certificate is valid and trusted by the system**

``` bash
echo "" | openssl s_client \
  -CAfile /etc/pki/ca-trust/source/anchors/lanathome.org-root.crt \
  -connect ldap.lanathome.org:6360 \
  -servername ldap.lanathome.org
```

**do a simple ldapsearch to verify the connection and credentials**

``` bash
ldapsearch -x -H ldaps://ldap.lanathome.org:6360 \
-D "cn=admin,ou=services,dc=lanathome,dc=org"   \
-w xxxxxxxxxx \
-b "dc=lanathome,dc=org" \
sAMAccountName=admin
```



**troubleshoot the openldap and phpldapadmin containers**

``` bash
sudo podman logs --tail 50 phpldapadmin
sudo podman logs --tail 50 openldap
```

**stop openldap container**

``` bash
sudo podman stop openldap
```

**delete openldap container**
``` bash
sudo podman rm openldap
```

**remove associated volume from openldap container**
``` bash
sudo podman volume prune
```

**git commands to create a new branch for openldap container development**

``` bash
git branch -a
  dev-1
  main
  openldap/dev-1
  openldap/dev-2
* openldap/dev-3
```

``` bash
git checkout -q openldap/dev-3
```

``` bash
git branch dev main
```

``` bash
git add config.json
```

``` bash
git commit -m "xxx" ./xxxxxx
```

``` bash
git push -u openldap openldap/dev-3
```

**Checks your local repository configuration (.git/config) to see what VS Code has recorded as the base branch for main.**

• Breakdown:
	• --get: Read a value.
	• --local: Look only in the current repository's config (not your global user config).
	• branch.main.vscode-merge-base: The custom setting name VS Code creates for the main branch.


``` bash
$ git config --get --local branch.main.vscode-merge-base
```

**Does the exact same thing as the first command, but checks the recorded base branch for your openldap/dev-4 branch instead.**

``` bash
$ git config --get --local branch.openldap/dev-4.vscode-merge-base
```


**Searches the local history (reflog) of the openldap/dev-4 branch specifically for the log entry created when the branch was first branched off.**

• Why VS Code runs this: If the previous git config check returned nothing, VS Code runs this command to figure out where openldap/dev-4 originally came from (e.g., "branch: Created from openldap/main").

``` bash
$ git reflog openldap/dev-4 --grep-reflog=branch
```


**Does the exact same thing as the first command, but checks the recorded base branch for your openldap/dev-4 branch instead.**

``` bash
$ git config --get --local branch.openldap/dev-4.vscode-merge-base
```

**Searches the local history (reflog) of the openldap/dev-4 branch specifically for the log entry created when the branch was first branched off.**

• Why VS Code runs this: If the previous git config check returned nothing, VS Code runs this command to figure out where openldap/dev-4 originally came from (e.g., "branch: Created from openldap/main").

``` bash
$ git reflog openldap/dev-4 --grep-reflog=branch
```


**Saves openldap/main as the official base branch for openldap/dev-4 in your local .git/config file.**

• Why VS Code runs this: Now that it figured out from step 3 that openldap/dev-4 was created from openldap/main, it saves that information so it doesn't have to search the reflog again next time.

``` bash
git config --add --local branch.openldap/dev-4.vscode-merge-base openldap/main
```


``` bash
git push -u openldap openldap/dev-4
```