*my personal notes for running the openldap container*

**create dummy certs for openldap container**

``` bash
mkdir -p certs
```

``` bash
cd certs/
```

**Generate a 4096-bit RSA root private key**
``` bash
openssl genrsa -out lanathome.org-root.key 4096
```




**Create the self-signed Root CA certificate (valid for 10 years)**
``` bash
openssl req -x509 -new -nodes -key lanathome.org-root.key -sha256 -days 3650 \
  -subj "/C=FR/ST=/L=SAINT-PIERRE en FAUCIGNY/O=Lanathome/OU=IT/CN=Lanathome.org Root CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -out lanathome.org-root.crt
```


**Generate host private key**
``` bash
openssl genrsa -out ldap.lanathome.org.key 2048
```


**Create a CSR for ldap.lanathome.org**
``` bash
openssl req -new -key ldap.lanathome.org.key \
  -subj "/C=FR/ST=/L=SAINT-PIERRE en FAUCIGNY/O=Lanathome/OU=IT/CN=ldap.lanathome.org" \
  -out ldap.lanathome.org.csr
```
``` bash
vi ldap.ext

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
openssl x509 -req -in ldap.lanathome.org.csr \
  -CA lanathome.org-root.crt -CAkey lanathome.org-root.key -CAcreateserial \
  -out ldap.lanathome.org.crt -days 825 -sha256 -extfile ldap.ext
```



**Verify and Deploy**

**Verify the chain against your Root CA:**
``` bash
openssl verify -CAfile lanathome.org-root.crt ldap.lanathome.org.crt
```


**get latest openldap container image**

``` bash
podman pull quay.io/agrosshans/ngr-container-openldap:latest
``` 

**stop openldap container**

``` bash
podman stop openldap
```

**delete openldap container**
``` bash
podman rm openldap
```

**remove associated volume from openldap container**
``` bash
podman volume prune
```

**create rootfull network for openldap and phpldapadmin containers**
``` bash
sudo podman network create --driver bridge \
  --subnet 10.89.12.0/24 \
  --gateway 10.89.12.1 \
  phpldapadmin-bridge
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
sudo resolvectl dns podman6 10.89.12.1
sudo resolvectl domain podman6 "~podman"
```

**change the admin password**

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

``` bash
ldap:/$ slappasswd -s xxxxxxxxxx
{SSHA}NAEqORXJ9uaJ4hnBSLWyW7lRyIBw3fdS
```

``` bash
ldap:/$ vi /etc/openldap/slapd.d/cn=config/olcDatabase={0}config.ldif
[...]
olcRootPW: {SSHA}NAEqORXJ9uaJ4hnBSLWyW7lRyIBw3fdS               
```


**add other users to the admin group by creating a new ldif file and applying it with ldapmodify**


**copy admin-rights.ldif**
``` bash
sudo podman cp admin-rights.ldif openldap:/admin-rights.ldif
```

**copy lanathome_org.ldif**
``` bash
sudo podman cp lanathome_org.ldif openldap:/lanathome_org.ldif
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
``

git commit -m "xxx" ./xxxxxx


git push -u openldap openldap/dev-3