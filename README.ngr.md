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
  




``` bash
echo "" | openssl s_client \
  -CAfile /etc/pki/ca-trust/source/anchors/lanathome.org-root.crt \
  -connect ldap.lanathome.org:6360 \
  -servername ldap.lanathome.org


``` bash
ldapsearch -x -H ldaps://ldap.lanathome.org:6360 \
-D "cn=admin,ou=services,dc=lanathome,dc=org"   \
-w xxxxxxxxxx \
-b "dc=lanathome,dc=org" \
sAMAccountName=admin
