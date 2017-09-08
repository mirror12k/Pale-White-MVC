#!/usr/bin/env perl
package PaleWhite::MVC::Compiler;
use strict;
use warnings;

use feature 'say';

use Carp;
use Data::Dumper;

use Sugar::IO::File;
use PaleWhite::MVC::Parser;
use PaleWhite::MVC::ModelSQLCompiler;
use PaleWhite::MVC::ControllerPHPCompiler;
use PaleWhite::MVC::FileDirectoryPHPCompiler;
# use PaleWhite::MVC::ModelPHPCompiler;



sub new {
	my ($class, %args) = @_;
	my $self = bless {}, $class;

	$self->{native_library_includes} = [];

	return $self
}

sub parse_text {
	my ($self, $text) = @_;

	my $parser = PaleWhite::MVC::Parser->new;
	$parser->{text} = $text;
	$self->{syntax_tree} = $parser->parse;
	# say Dumper $self->{syntax_tree};
}

sub parse_file {
	my ($self, $file) = @_;

	my $filepath = Sugar::IO::File->new($file);
	croak "file not found: $filepath" unless $filepath->exists;

	my $parser = PaleWhite::MVC::Parser->new;
	$parser->{filepath} = $filepath;
	$self->{syntax_tree} = $parser->parse;
	# say Dumper $self->{syntax_tree};
}

sub compile_references {
	my ($self) = @_;

	foreach my $item (@{$self->{syntax_tree}}) {
		if ($item->{type} eq 'native_library_declaration') {
			push @{$self->{native_library_includes}}, $item->{include_file};
		}
	}
}

sub compile_sql {
	my ($self) = @_;

	my @code;

	push @code, "\n";

	foreach my $model (grep $_->{type} eq 'model_definition', @{$self->{syntax_tree}}) {
		push @code, PaleWhite::MVC::ModelSQLCompiler::compile_model($model);
	}

	return join '', @code
}

sub compile_php {
	my ($self) = @_;

	my @code;

	push @code, "<?php\n\n\n";

	foreach my $item (@{$self->{syntax_tree}}) {
		if ($item->{type} eq 'model_definition') {
			# push @code, PaleWhite::MVC::ModelPHPCompiler::compile_model($item);
			my $compiler = PaleWhite::MVC::ControllerPHPCompiler->new;
			push @code, $compiler->compile_model($item);
		} elsif ($item->{type} eq 'controller_definition') {
			my $compiler = PaleWhite::MVC::ControllerPHPCompiler->new;
			push @code, $compiler->compile_controller($item);
		} elsif ($item->{type} eq 'plugin_definition') {
			my $compiler = PaleWhite::MVC::ControllerPHPCompiler->new;
			push @code, $compiler->compile_plugin($item);
		} elsif ($item->{type} eq 'file_directory_definition') {
			my $compiler = PaleWhite::MVC::FileDirectoryPHPCompiler->new;
			push @code, $compiler->compile_file_directory($item);
		} elsif ($item->{type} eq 'native_library_declaration') {
			# ignored
		} else {
			die "unimplemented mvc syntax item: $item->{type}";
		}
	}

	return join '', @code
}



sub main {
	foreach my $file (@_) {
		my $compiler = PaleWhite::MVCCompiler->new;
		$compiler->parse_file;
		say $compiler->compile_php;
	}
}

caller or main(@ARGV);
