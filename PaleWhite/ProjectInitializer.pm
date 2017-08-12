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

	path default {
		status "404 Not Found";
		render ErrorTemplate error="Not Found";
	}
}

'
}

sub default_templates_file {
	return '

!template BaseTemplate
	html
		head
			!block head
			link href="/css/style.css" type="text/css" rel="stylesheet"
			# script src="/js/pale_white.js" type="text/javascript"
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
	my ($project_directory) = @_;

	my $dir = Sugar::IO::Dir->new($project_directory);
	$dir->mk unless $dir->exists;

	my $src_dir = $dir->new_dir('src');
	$src_dir->mk;

	$src_dir->new_file('controllers.white')->write(default_controllers_file);
	$src_dir->new_file('templates.glass')->write(default_templates_file);
	$src_dir->new_dir('css')->mk;
	$src_dir->dir('css')->new_file('style.css')->write(default_style_file);
	$src_dir->new_dir('js')->mk;
	$src_dir->dir('js')->new_file('code.white_js')->write(default_js_file);
}

sub main {

	die "usage: $0 <project directory name>" unless @_ == 1;
	initilize_project(@_);
}

caller or main(@ARGV);
