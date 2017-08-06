


SSH_SERVER = 192.168.11.3:22

USER = dmin
PASSWORD = dminpassword

APACHE_LOG = /var/log/apache2/error.log

WWW_DIRECTORY = /var/www/html
SITE_DIRECTORY = test/site
SITE_FOLDER = site


build:
	sh
		~/src/perl/repo/Sugar/Lang/GrammarCompiler.pm grammar/glass_parser.sugar > PaleWhite/Glass/Parser.pm
		~/src/perl/repo/Sugar/Lang/GrammarCompiler.pm grammar/pale_white_parser.sugar > PaleWhite/MVC/Parser.pm
		# ~/src/perl/repo/Sugar/Lang/GrammarCompiler.pm grammar/controller_parser.sugar > PaleWhite/ControllerParser.pm

tail_log:
	ssh $(USER):$(PASSWORD)@$(SSH_SERVER)
		tail -n 40 $(APACHE_LOG)


upload:
	sftp $(USER):$(PASSWORD)@$(SSH_SERVER)
		delete $(WWW_DIRECTORY)/$(SITE_FOLDER)
		put $(SITE_DIRECTORY) => $(WWW_DIRECTORY)/$(SITE_FOLDER)


