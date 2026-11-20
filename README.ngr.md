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