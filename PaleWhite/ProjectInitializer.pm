#!/usr/bin/env perl
package PaleWhite::ProjectInitializer;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;

use Sugar::IO::File;
use Sugar::IO::Dir;



sub default_controllers_file {
	return '

controller MainController {
	path "/" {
		render HelloWorldTemplate;
	}

	# path global {}
	# path error {}

	path default {
		status "404 Not Found";
		render ErrorTemplate error="Not Found";
	}
}

'
}

sub default_models_file {
	return '

model ExampleModel {
	string[255] name;

	# get: prop {}
	# on create {}
	# on delete {}
}

'
}

sub default_localization_file {
	return '

localization my_app:en {
	hello = "Hello"
	world = "World!"
}

'
}

sub default_templates_file {
	return '

!template BaseTemplate
	html
		head
			!_csrf_token_meta
			link href="/css/style.css" type="text/css" rel="stylesheet"
			# script src="/js/pale_white.js" type="text/javascript"
			# script src="/js/app.js" type="text/javascript"
			!block head
		body
			div.content
				!block content

!template HelloWorldTemplate extends BaseTemplate
	!block content
		h1 "Hello world!"
		button.hello_world "Say Hello!"

!template ErrorTemplate extends BaseTemplate
	!block content
		div.error_container
			div.title
				h1 "Error!"
			div.text
				p {error}

'
}

sub default_style_file {
	return '

body {
	margin: 0px;
}

'
}

sub default_js_file {
	return '

button.hello_world => on click
	event.preventDefault();
	alert("Hello world!");

'
}

sub initilize_project {
	my ($project_directory, %options) = @_;

	my $dir = Sugar::IO::Dir->new($project_directory);
	$dir->mk unless $dir->exists;

	my $src_dir = $dir->new_dir('src');
	$src_dir->mk;
	my $server_src_dir = $src_dir->new_dir('server_src');
	$server_src_dir->mk;

	$server_src_dir->new_file('controllers.white')->write(default_controllers_file);
	$server_src_dir->new_file('templates.glass')->write(default_templates_file);
	if ($options{models}) {
		$server_src_dir->new_file('models.white')->write(default_models_file);
	}
	if ($options{local}) {
		$server_src_dir->new_file('text_en.local')->write(default_localization_file);
	}
	$src_dir->new_dir('css')->mk;
	$src_dir->dir('css')->new_file('style.css')->write(default_style_file);
	if ($options{js}) {
		$src_dir->new_dir('js')->mk;
		$src_dir->dir('js')->new_file('app.white_js')->write(default_js_file);
	}
}

sub main {

	die "usage: $0 [+js] [+local] [+models] <project directory name>" unless @_;

	my %options;

	while (@_ > 1) {
		my $arg = shift;
		if ($arg eq '+js') {
			$options{js} = 1;
		} elsif ($arg eq '+local') {
			$options{local} = 1;
		} elsif ($arg eq '+models') {
			$options{models} = 1;
		} else {
			die "invalid option: $arg";
		}
	}

	initilize_project(@_, %options);
}

caller or main(@ARGV);
