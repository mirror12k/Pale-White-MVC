
PROJECT_DIRECTORY = pale-videos

SSH_SERVER = 192.168.11.3:22

USER = dmin
PASSWORD = dminpassword

APACHE_LOG = /var/log/apache2/error.log

WWW_DIRECTORY = /var/www/html
SITE_DIRECTORY = $(PROJECT_DIRECTORY)
SITE_FOLDER = $(PROJECT_DIRECTORY)

build:
	sh
		cd ../..
		./PaleWhite/ProjectCompiler.pm example/$(PROJECT_DIRECTORY)/src example/$(PROJECT_DIRECTORY)/bin
		cp -r phplib example/$(PROJECT_DIRECTORY)/bin
		-mkdir example/$(PROJECT_DIRECTORY)/bin/uploads




tail_log:
	ssh $(USER):$(PASSWORD)@$(SSH_SERVER)
		tail -n 40 $(APACHE_LOG)

upload:
	sftp $(USER):$(PASSWORD)@$(SSH_SERVER)
		-delete $(WWW_DIRECTORY)/$(SITE_FOLDER)
		put bin => $(WWW_DIRECTORY)/$(SITE_FOLDER)

	# fix permissions for upload directory
	ssh $(USER):$(PASSWORD)@$(SSH_SERVER)
		# chown www-data:www-data $(WWW_DIRECTORY)/$(SITE_FOLDER)/uploads
		chmod -R 0777 $(WWW_DIRECTORY)/$(SITE_FOLDER)/uploads

