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

``` bash
podman run --name openldap --hostname ldap.lanathome.org \
  --publish 3890:3890 \
  --publish 6360:6360 \
  --network ngr-macvlan \
  --volume certs:/container/services/openldap/assets/certs:Z \
  --env-file .env \
  quay.io/agrosshans/ngr-container-openldap
```


**change the admin password**

``` bash
podman exec -it openldap-dev3 /usr/bin/ldappasswd -Q -Y EXTERNAL -H ldapi:/// \
  -D "cn=admin,ou=services,dc=lanathome,dc=org" -w xxxxxxxxxx \
  -s xxxxxxxxxx "cn=admin,ou=services,dc=lanathome,dc=org"
```

``` bash
/usr/bin/ldappasswd -Q -Y EXTERNAL -H ldapi:/// \
  -D "cn=admin,ou=services,dc=lanathome,dc=org" -w xxxxxxxxxx \
  -s xxxxxxxxxx "cn=admin,ou=services,dc=lanathome,dc=org"
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