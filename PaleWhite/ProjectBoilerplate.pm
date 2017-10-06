#!/usr/bin/env perl
package PaleWhite::ProjectBoilerplate;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;

use Sugar::IO::File;
use Sugar::IO::Dir;



sub default_user_model {
	my ($user_model_name, %options) = @_;
	return "


model $user_model_name {
	string[255] username unique;" .
	($options{login} ? "

	# +login
	salted_sha256 password;
	string[32] last_login_timestamp;" : '') .
	($options{registration} ? "

	# +registration
	string[32] registration_timestamp;" : '') .
	"
}


"
	# +login
	# 	salted_sha256 password;
	# 	string[32] last_login_timestamp;
	# +registration
	# 	string[32] registration_timestamp;
}


sub default_user_controller {
	my ($user_model_name, $controller_name, %options) = @_;
	return "


controller $controller_name {
	action get_current_user {
		if (session.${controller_name}_login_token) {
			user = model? $user_model_name id=session.${controller_name}_login_token;
			return user;
		} else {
			return 0;
		}
	}

	action set_current_user (model::$user_model_name user) {
		session.${controller_name}_login_token = user.id;
	}

	action clear_current_user {
		session.${controller_name}_login_token = 0;
	}" .
	($options{login} ? "

	# +login
	action verify_user_login (string[1:255] username, string[1:255] password) {
		user = model? $user_model_name username=username;
		if (!user) {
			return 0;
		}

		if (user.matches_hashed_field(\"password\", password)) {
			user.last_login_timestamp = _time;
			return user;
		} else {
			return 0;
		}
	}" : '') .
	($options{registration} ? "

	# +registration
	action register_user (string[1:255] username, string[1:255] password) {
		user = create $user_model_name username=username, password=password, registration_timestamp=_time;
		return user;
	}" : '') .
	"
}


"
	# +login
		# action verify_user_login (string[1:255] username, string[1:255] password) {
		# 	user = model? $user_model_name username=username;
		# 	if (!user) {
		# 		return 0;
		# 	}

		# 	if (user.matches_hashed_field(\"password\", password)) {
		# 		user.last_login_timestamp = _time;
		# 		return user;
		# 	} else {
		# 		return 0;
		# 	}
		# }

	# +registration
		# action register_user (string[1:255] username, string[1:255] password) {
		# 	user = create $user_model_name username=username, password=password, registration_timestamp=_time;
		# 	return user;
		# }
}

sub write_user_controller {
	my ($project_directory, $user_model_name, $controller_name, %options) = @_;

	my $dir = Sugar::IO::Dir->new($project_directory);
	die "directory $dir doesnt exist" unless $dir->exists;

	$dir->new_file("$user_model_name.white")->write(default_user_model($user_model_name, %options));
	$dir->new_file("$controller_name.white")->write(default_user_controller($user_model_name, $controller_name, %options));
}

sub main {

	die "usage: $0 <options...> <project directory name>\n
	options:
		--user-controller <user_model_name> <controller_name> [+login] [+registration]" unless @_;

	my %options;

	my $target;
	my @target_args;
	while (@_ > 1) {
		my $arg = shift;
		if ($arg eq '--user-controller') {
			$target = 'user_controller';
			push @target_args, shift // die "user model name argument required";
			push @target_args, shift // die "controller name argument required";

		} elsif ($arg eq '+login') {
			$options{login} = 1;
		} elsif ($arg eq '+registration') {
			$options{registration} = 1;

		} else {
			die "invalid option: $arg";
		}
	}
	die "please choose a target" unless defined $target;

	my $project_directory = shift // die "project_directory required";

	if ($target eq 'user_controller') {
		write_user_controller($project_directory, @target_args, %options);
	} else {
		...
	}
}

caller or main(@ARGV);
