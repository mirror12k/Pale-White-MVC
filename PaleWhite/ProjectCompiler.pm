#!/usr/bin/env perl
package PaleWhite::ProjectCompiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;

use Sugar::IO::File;
use Sugar::IO::Dir;

use PaleWhite::Glass::PHPCompiler;
use PaleWhite::MVC::Compiler;
use PaleWhite::JS::Compiler;
use PaleWhite::Delta::DeltaSQLCompiler;
use PaleWhite::Local::PHPCompiler;



sub default_event_model {
	return "

model _EventModel {
	int trigger_time;
	string[512] controller_class;
	string[512] controller_event;
	json args;
}

"
}

sub default_php_config_file {
	return "<?php

global \$config;

\$config = array(
	// set site base if the website isnt located at the root of the webserver
	'site_base' => '',
	// main controller launched to start the application
	'main_controller' => 'MainController',

	// whether a fatal exception's stack trace will be shown in browser
	'show_exception_trace' => true,
	// additional logfile used by controllers
	'log_file' => '',
	// set maintenance_mode to true to switch the site into maintenance mode
	'maintenance_mode' => false,
	// during maintenance_mode, the maintenance_mode_controller will be launched instead of the main_controller
	// DefaultMaintenanceController is a simple controller displaying a maintenance message
	'maintenance_mode_controller' => '\\\\PaleWhite\\\\DefaultMaintenanceController',

	// initial localization setting set at the start of each request
	// leave empty for no default
	'default_localization' => '',
	// whether to enable event processing queue (utilizes the database)
	// dies if an event is scheduled while events are disabled
	'enable_events' => false,

	// database configuration
	// only used if database access is performed using models
	// dies if access is requested and information is incorrect
	'database_config' => array(
		'mysql_host' => 'localhost',
		'mysql_username' => 'root',
		'mysql_password' => '',
		'mysql_database' => '',
	),
	
	// list of plugins destined to be loaded into the application
	// listed by key value pairs, with the key being the plugin identifier,
	// and the value is the plugin specific config,
	// with the special key 'plugin_class' defining the class to be instantiated by the system
	// loaded plugins can then be accessed programmatically through runtime.plugins.PLUGIN_NAME
	'plugins' => array(),
	// location where plugins are stored
	// plugins must be stored by their full plugin class name
	'plugins_folder' => 'plugins',
);

"
}

sub default_htaccess_file {
	return "
<IfModule mod_rewrite.c>
	RewriteEngine On
	RewriteCond %{REQUEST_FILENAME} !-f
	RewriteRule ^ index.php [L]
</IfModule>
"
}

sub default_php_index_file {
	return "<?php

require_once 'includes.php';
require_once 'config.php';

\$executor = new \\PaleWhite\\HTTPRequestExecutor();
\$executor->execute();

"
}

sub compile_includes {
	my (@includes) = @_;

	my @code;

	push @code, "<?php\n";
	push @code, "\n";
	push @code, "\n";

	push @code, "require_once '$_';\n" foreach @includes;
	push @code, "\n";
	push @code, "\n";

	return join '', @code
}

sub compile_project_directory {
	my ($src_dir, $bin_dir, %options) = @_;
	$src_dir = Sugar::IO::Dir->new($src_dir);
	$bin_dir = Sugar::IO::Dir->new($bin_dir);

	if ($options{plugin}) {
		say "compiling PaleWhite plugin: $src_dir => $bin_dir";
	} else {
		say "compiling PaleWhite project: $src_dir => $bin_dir";
	}

	my @includes;

	$bin_dir->mk unless $bin_dir->exists;

	my $setup_sql_file = Sugar::IO::File->new("$bin_dir/setup.sql");
	my $includes_file = Sugar::IO::File->new("$bin_dir/includes.php");
	my $config_file = Sugar::IO::File->new("$bin_dir/config.php");
	my $htaccess_file = Sugar::IO::File->new("$bin_dir/.htaccess");
	my $index_file = Sugar::IO::File->new("$bin_dir/index.php");

	# clear the setup.sql file
	$setup_sql_file->write('');
	# add in PaleWhite library as an include
	push @includes, "phplib/PaleWhite/lib.php" unless $options{plugin};

	my @all_files = $src_dir->recursive_files;

	my @mvc_files;
	my @template_files;
	my @js_files;
	my @delta_files;
	my @local_files;
	my @user_files;

	foreach my $file (@all_files) {
		if ($file =~ /\.white\Z/) {
			push @mvc_files, $file;
		} elsif ($file =~ /\.glass\Z/) {
			push @template_files, $file;
		} elsif ($file =~ /\.white_js\Z/) {
			push @js_files, $file;
		} elsif ($file =~ /\.delta\Z/) {
			push @delta_files, $file;
		} elsif ($file =~ /\.local\Z/) {
			push @local_files, $file;
		} else {
			push @user_files, $file;
		}
	}

	if (not $options{plugin}) {
		# compile default event queue model
		my $relative_path = "_EventModel.php";
		my $destination_path = "$bin_dir/$relative_path";
		
		my $compiler = PaleWhite::MVC::Compiler->new;
		$compiler->parse_text(default_event_model);
		$compiler->compile_references;

		my $compiled_php = $compiler->compile_php;
		my $destination_file = Sugar::IO::File->new($destination_path);
		$destination_file->dir->mk unless $destination_file->dir->exists;
		$destination_file->write($compiled_php);

		my $compiled_sql = $compiler->compile_sql;
		$setup_sql_file->append($compiled_sql);


		push @includes, @{$compiler->{native_library_includes}};
		push @includes, $relative_path;
	}

	foreach my $source_path (@mvc_files) {

		my $relative_path = $source_path =~ s/\A$src_dir\/*//r;
		$relative_path =~ s/\.white\Z/\.php/;
		my $destination_path = "$bin_dir/$relative_path";
		my $destination_directory = $destination_path =~ s#/[^/]+\Z##r;
		# say "model: $source_path ($relative_path => $destination_path ($destination_directory))";
		say "\tmvc: $source_path => $destination_path";

		my $compiler = PaleWhite::MVC::Compiler->new;
		$compiler->parse_file($source_path);
		$compiler->compile_references;

		my $compiled_php = $compiler->compile_php;
		my $destination_file = Sugar::IO::File->new($destination_path);
		$destination_file->dir->mk unless $destination_file->dir->exists;
		$destination_file->write($compiled_php);

		my $compiled_sql = $compiler->compile_sql;
		$setup_sql_file->append($compiled_sql);


		push @includes, @{$compiler->{native_library_includes}};
		push @includes, $relative_path;
	}

	foreach my $source_path (@template_files) {

		my $relative_path = $source_path =~ s/\A$src_dir\/*//r;
		$relative_path =~ s/\.glass\Z/\.php/;
		my $destination_path = "$bin_dir/$relative_path";
		my $destination_directory = $destination_path =~ s#/[^/]+\Z##r;
		# say "\tmodel: $source_path ($relative_path => $destination_path ($destination_directory))";
		say "\ttemplate: $source_path => $destination_path";

		my $compiled_php = PaleWhite::Glass::PHPCompiler::compile_file($source_path);
		my $destination_file = Sugar::IO::File->new($destination_path);
		$destination_file->dir->mk unless $destination_file->dir->exists;
		$destination_file->write($compiled_php);
		
		push @includes, $relative_path;
	}

	foreach my $source_path (@js_files) {
		my $relative_path = $source_path =~ s/\A$src_dir\/*//r;
		$relative_path =~ s/\.white_js\Z/\.js/;
		my $destination_path = "$bin_dir/$relative_path";
		my $destination_directory = $destination_path =~ s#/[^/]+\Z##r;
		# say "model: $source_path ($relative_path => $destination_path ($destination_directory))";
		say "\tjs: $source_path => $destination_path";

		my $compiler = PaleWhite::JS::Compiler->new;
		my $compile_js = $compiler->compile_file($source_path);

		my $destination_file = Sugar::IO::File->new($destination_path);
		$destination_file->dir->mk unless $destination_file->dir->exists;
		$destination_file->write($compile_js);
	}

	foreach my $source_path (@delta_files) {

		my $relative_path = $source_path =~ s/\A$src_dir\/*//r;
		$relative_path =~ s/\.delta\Z/\.sql/;
		my $destination_path = "$bin_dir/$relative_path";
		my $destination_directory = $destination_path =~ s#/[^/]+\Z##r;
		# say "\tmodel: $source_path ($relative_path => $destination_path ($destination_directory))";
		say "\tdelta: $source_path => $destination_path";

		my $compiled_sql = PaleWhite::Delta::DeltaSQLCompiler::compile_file($source_path);
		my $destination_file = Sugar::IO::File->new($destination_path);
		$destination_file->dir->mk unless $destination_file->dir->exists;
		$destination_file->write($compiled_sql);
	}

	foreach my $source_path (@local_files) {

		my $relative_path = $source_path =~ s/\A$src_dir\/*//r;
		$relative_path =~ s/\.local\Z/\.php/;
		my $destination_path = "$bin_dir/$relative_path";
		my $destination_directory = $destination_path =~ s#/[^/]+\Z##r;
		# say "\tmodel: $source_path ($relative_path => $destination_path ($destination_directory))";
		say "\tlocal: $source_path => $destination_path";

		my $compiled_php = PaleWhite::Local::PHPCompiler::compile_file($source_path);
		my $destination_file = Sugar::IO::File->new($destination_path);
		$destination_file->dir->mk unless $destination_file->dir->exists;
		$destination_file->write($compiled_php);
		
		push @includes, $relative_path;
	}

	foreach my $source_path (@user_files) {

		my $relative_path = $source_path =~ s/\A$src_dir\/*//r;
		my $destination_path = "$bin_dir/$relative_path";
		my $destination_directory = $destination_path =~ s#/[^/]+\Z##r;
		# say "\tmodel: $source_path ($relative_path => $destination_path ($destination_directory))";
		say "\tuser data: $source_path => $destination_path";

		my $text = $source_path->read;
		my $destination_file = Sugar::IO::File->new($destination_path);
		# say "debug file: " . $destination_file->dir;
		$destination_file->dir->mk unless $destination_file->dir->exists;
		$destination_file->write($text);
	}

	my $compiled_php = compile_includes(@includes);
	say "\tincludes file: $includes_file";
	$includes_file->write($compiled_php);
	say "\tsetup.sql file: $setup_sql_file";

	if (not $options{plugin}) {
		unless ($config_file->exists) {
			say "\tconfig file: $config_file";

			$config_file->write(default_php_config_file);

			say "\t\tdefault config written, please add your settings to properly setup your app";
		}

		unless ($htaccess_file->exists) {
			say "\thtaccess file: $htaccess_file";

			$htaccess_file->write(default_htaccess_file);

			say "\t\tdefault htaccess written, please edit it if necessary";
		}

		unless ($index_file->exists) {
			say "\tindex file: $index_file";
			$index_file->write(default_php_index_file);
		}
	}

}


sub main {

	die "usage: $0 [--plugin] <src directory> <bin directory>" unless @_ >= 2;

	my %options;
	while (@_ > 2) {
		my $arg = shift;
		if ($arg eq '--plugin') {
			$options{plugin} = 1;
		} else {
			die "invalid option: $arg";
		}
	}

	compile_project_directory(@_, %options);
}

caller or main(@ARGV);


