docker build --build-arg NO_CACHE=$(date +%s) \
       	--build-arg AMPDBPASS='8randombytes' \
       	--build-arg AMPDBUSER='freepbxuser' \
	--build-arg AMPDBHOST='192.168.222.115' \
	--build-arg AMPDBPORT='3306' \
	--build-arg AMPDBNAME='asterisk' \
	--build-arg AMPDBENGINE='mysql' \
	$@ \
	-t lacoursj/st-fpbx:latest .
