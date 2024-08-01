#! /bin/bash
#
#01100110 01110101 01100011 01101011
#00100000 01110011 01100001 01101110
#01100111 01101111 01101101 01100001
#00001010 01101010 11010001 00101100
#
# Forcibly downloads, then extracts
#  all of the files in a deb package
#  into the root directory. Note that
#  I do not condone this process, and
#  am only doing this out of necessity.

# Create base directories
#mkdir "/tmp/force_install"
#for base_dir_name in freepbx asterisk; do
#       mkdir -p "/tmp/force_install/${base_dir_name}"
#done

# Download the package files
# run this in a subshell so we don't clobber pwd
#for package_type in freepbx asterisk; do
#       (cd "/tmp/force_install/${package_type}"
#        apt-get download $(dpkg -l|awk '/'"${package_type}"'/{print $2}'))
#done

# Start extracting the packages downloaded from above
for base_package_dir in "/tmp/force_install/"*; do
	# Create a new root dir to extract into
	newroot="${base_package_dir}/newroot"
	mkdir -p "${newroot}"
	# Iterate over the packages within the dir
	for package_file in "${base_package_dir}/"*".deb"; do
		# First, find the data file in the deb
		package_data=$(ar t "${package_file}" | grep ^data.tar)
		# Extract the data contianer from the deb file
		ar p "${package_file}" "${package_data}" > "${newroot}/${package_data}"
		# Extract the data file's contents into newroot
		tar -xf "${newroot}/${package_data}" -C "${newroot}"
		# Delete the data file
		rm -fv "${newroot}/${package_data}"
	done
done

