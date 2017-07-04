#!/usr/bin/env perl
package PaleWhite::ProjectCompiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;

use Sugar::IO::File;
use Sugar::IO::Dir;

use PaleWhite::ControllerPHPCompiler;
use PaleWhite::Glass::PHPCompiler;
use PaleWhite::ModelPHPCompiler;
use PaleWhite::ModelSQLCompiler;




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
	my ($src_dir, $bin_dir) = @_;
	$src_dir = Sugar::IO::Dir->new($src_dir);
	$bin_dir = Sugar::IO::Dir->new($bin_dir);

	say "compiling PaleWhite project: $src_dir => $bin_dir";

	my @includes;

	my $setup_sql_file = Sugar::IO::File->new("$bin_dir/setup.sql");
	my $includes_file = Sugar::IO::File->new("$bin_dir/includes.php");
	my $config_file = Sugar::IO::File->new("$bin_dir/config.php");
	my $htaccess_file = Sugar::IO::File->new("$bin_dir/.htaccess");
	my $index_file = Sugar::IO::File->new("$bin_dir/index.php");

	# clear the setup.sql file
	$setup_sql_file->write('');
	# add in PaleWhite library as an include
	push @includes, "phplib/PaleWhite/lib.php";

	my @all_files = $src_dir->recursive_files;

	my @model_files;
	my @template_files;
	my @controller_files;
	my @user_files;

	foreach my $file (@all_files) {
		if ($file =~ /\.model\Z/) {
			push @model_files, $file;
		} elsif ($file =~ /\.glass\Z/) {
			push @template_files, $file;
		} elsif ($file =~ /\.controller\Z/) {
			push @controller_files, $file;
		} else {
			push @user_files, $file;
		}
	}

	foreach my $source_path (@model_files) {

		my $relative_path = $source_path =~ s/\A$src_dir\/*//r;
		$relative_path =~ s/\.model\Z/\.php/;
		my $destination_path = "$bin_dir/$relative_path";
		my $destination_directory = $destination_path =~ s#/[^/]+\Z##r;
		# say "model: $source_path ($relative_path => $destination_path ($destination_directory))";
		say "\tmodel: $source_path => $destination_path";

		my $compiled_php = PaleWhite::ModelPHPCompiler::compile_file($source_path);
		my $destination_file = Sugar::IO::File->new($destination_path);
		$destination_file->dir->mk unless $destination_file->dir->exists;
		$destination_file->write($compiled_php);
		my $compiled_sql = PaleWhite::ModelSQLCompiler::compile_file($source_path);
		$setup_sql_file->append($compiled_sql);

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

	foreach my $source_path (@controller_files) {

		my $relative_path = $source_path =~ s/\A$src_dir\/*//r;
		$relative_path =~ s/\.controller\Z/\.php/;
		my $destination_path = "$bin_dir/$relative_path";
		my $destination_directory = $destination_path =~ s#/[^/]+\Z##r;
		# say "\tmodel: $source_path ($relative_path => $destination_path ($destination_directory))";
		say "\tcontroller: $source_path => $destination_path";

		my $compiled_php = PaleWhite::ControllerPHPCompiler::compile_file($source_path);
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

	unless ($config_file->exists) {
		say "\tconfig file: $config_file";

		$config_file->write("<?php

global \$config;

\$config = array(
	'site_base' => '',
	'main_controller' => 'MainController',
	'database_config' => array(
		'mysql_host' => 'localhost',
		'mysql_username' => 'root',
		'mysql_password' => '',
		'mysql_database' => '',
	),
);

");
	}

	unless ($htaccess_file->exists) {
		say "\thtaccess file: $htaccess_file";

		$htaccess_file->write("
<IfModule mod_rewrite.c>
	RewriteEngine On
	RewriteCond %{REQUEST_FILENAME} !-f
	RewriteRule ^ index.php [L]
</IfModule>
");
	}

	unless ($index_file->exists) {
		say "\tindex file: $index_file";
		$index_file->write("<?php

require_once 'includes.php';
require_once 'config.php';

\$executor = new \\PaleWhite\\HTTPRequestExecutor();
\$executor->execute();

");
	}

}



sub main {

	die "usage: $0 <src directory> <bin directory>" unless @_ == 2;
	compile_project_directory(@_);
}

caller or main(@ARGV);


