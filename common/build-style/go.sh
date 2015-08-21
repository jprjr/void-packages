#
# This helper is for templates for Go packages.
#

do_build() {
	if [[ "${go_get}" != "yes" ]]; then
		local path="${GOPATH}/src/${go_import_path}"
		mkdir -p "$(dirname ${path})"
		ln -fs $PWD "${path}"
	fi

	go_package=${go_package:-$go_import_path}
	go get -d -x ${go_package}
}

do_install() {
	find "${GOBIN}" -type f -executable | while read line
	do
		vbin "${line}"
	done
}
