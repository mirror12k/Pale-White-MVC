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
}


sub default_user_controller {
	my ($user_model_name, $controller_name, %options) = @_;
	return "


controller $controller_name {
	action is_logged_in {
		return action get_current_user;
	}

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
	($options{api} ? "

	# +api
	ajax \"/login\" (string[1:255] username, string[1:255] password) {
		# action check_create_default;
		
		user = action verify_user_login username=username, password=password;
		if (user) {
			action set_current_user user=user;
			render_json status=\"success\", action=\"refresh\";
		} else {
			render_json status=\"error\", error=\"incorrect login\";
		}
	}
	
	ajax \"/logout\" {
		action clear_current_user;
		render_json status=\"success\", action=\"refresh\";
	}

	ajax \"/edit/password\" (string[1:255] old_password, string[1:255] new_password1, string[1:255] new_password2) {
		user = action get_current_user;
		if (!user) {
			render_json status=\"error\", error=\"not logged in\";
			return;
		}

		if (new_password1 != new_password2) {
			render_json status=\"error\", error=\"new passwords dont match\";
			return;
		}

		if (!user.matches_hashed_field(\"password\", old_password)) {
			render_json status=\"error\", error=\"incorrect password\";
			return;
		}

		user.password = new_password1;
		render_json status=\"success\", action=\"refresh\";
	}" : '') .
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
	($options{create_default} ? "

	# +create_default
	action check_create_default {
		count_users = count $user_model_name;
		if (count_users == 0) {
			default_user = create $user_model_name username=\"admin\", password=\"password\";
			return default_user;
		}
		return 0;
	}" : '') .
	"
}


"
}


sub default_paged_item_controller {
	my ($item_model_name, $controller_name, %options) = @_;
	return "


controller $controller_name {
	PAGE_SIZE = 10;

	action list_page (int page, string? order) {
		offset = page * controller::$controller_name.PAGE_SIZE;

		if (order) {
			page_items = list $item_model_name _limit=controller::$controller_name.PAGE_SIZE, _offset=offset, _order=order;
		} else {
			page_items = list $item_model_name _limit=controller::$controller_name.PAGE_SIZE, _offset=offset;
		}

		return page_items;
	}

	action has_next_page (int page) {
		offset = (page + 1) * controller::$controller_name.PAGE_SIZE;

		model_count = count $item_model_name;
		return model_count > offset;
	}

	action has_previous_page (int page) {
		return page > 0;
	}

	action last_page {
		model_count = count $item_model_name;

		validate page_count as int;
		# round up if there is a remainder
		if (model_count % controller::$controller_name.PAGE_SIZE) {
			page_count = page_count + 1;
		}

		return page_count;
	}" .
	($options{search} ? "

	# +search
	action list_search_page (int page, query, string? order) {
		offset = page * controller::$controller_name.PAGE_SIZE;

		query._limit = controller::$controller_name.PAGE_SIZE;
		query._offset = offset;
		if (order) {
			query._order = order;
		}

		page_items = model::$item_model_name.get_list(query);

		return page_items;
	}

	action has_next_search_page (int page, query) {
		offset = (page + 1) * controller::$controller_name.PAGE_SIZE;

		model_count = model::$item_model_name.count(query);
		return model_count > offset;
	}

	action has_previous_search_page (int page) {
		return page > 0;
	}

	action last_search_page (query) {
		model_count = model::$item_model_name.count(query);

		validate page_count as int;
		# round up if there is a remainder
		if (model_count % controller::$controller_name.PAGE_SIZE) {
			page_count = page_count + 1;
		}

		return page_count;
	}" : '') .
	"

}" .
($options{view_controller} ? "

# +view_controller
view_controller $options{view_controller} {
	args (int page) {
		# shift back from zero-based to one-based
		view_page = page + 1;

		items_list = action controller::$controller_name.list_page page=page;
		view_args = {
			page=view_page,
			items_list=items_list,
		};

		# compute if there is a next_page and previous_page
		if (action controller::$controller_name.has_next_page board_model=board_model, page=page) {
			view_args.next_page = view_page + 1;
		} else {
			view_args.next_page = 0;
		}
		if (action controller::$controller_name.has_previous_page board_model=board_model, page=page) {
			view_args.previous_page = view_page - 1;
		} else {
			view_args.previous_page = 0;
		}
		
		return view_args;
	}
}" : '') .
"


"
}

sub write_user_controller {
	my ($project_directory, $user_model_name, $controller_name, %options) = @_;

	my $dir = Sugar::IO::Dir->new($project_directory);
	die "directory $dir doesnt exist" unless $dir->exists;

	$dir->new_file("$user_model_name.white")->write(default_user_model($user_model_name, %options));
	$dir->new_file("$controller_name.white")->write(default_user_controller($user_model_name, $controller_name, %options));
}

sub write_paged_list_controller {
	my ($project_directory, $item_model_name, $controller_name, %options) = @_;

	my $dir = Sugar::IO::Dir->new($project_directory);
	die "directory $dir doesnt exist" unless $dir->exists;

	$dir->new_file("$controller_name.white")->write(default_paged_item_controller($item_model_name, $controller_name, %options));
}

sub main {

	die "usage: $0 <options...> <project directory name>\n
	options:
		--user-controller <user_model_name> <controller_name> [+api] [+login] [+registration] [+create_default]
		--paged-list-controller <item_model_name> <controller_name> [+search] [+view_controller <view_controller_name>]" unless @_;

	my %options;

	my $target;
	my @target_args;
	while (@_ > 1) {
		my $arg = shift;
		if ($arg eq '--user-controller') {
			$target = 'user_controller';
			push @target_args, shift // die "user model name argument required";
			push @target_args, shift // die "controller name argument required";
		} elsif ($arg eq '--paged-list-controller') {
			$target = 'paged_list_controller';
			push @target_args, shift // die "item model name argument required";
			push @target_args, shift // die "controller name argument required";

		} elsif ($arg eq '+api') {
			$options{api} = 1;
		} elsif ($arg eq '+create_default') {
			$options{create_default} = 1;
		} elsif ($arg eq '+login') {
			$options{login} = 1;
		} elsif ($arg eq '+registration') {
			$options{registration} = 1;
		} elsif ($arg eq '+search') {
			$options{search} = 1;
		} elsif ($arg eq '+view_controller') {
			$options{view_controller} = shift;

		} else {
			die "invalid option: $arg";
		}
	}
	die "please choose a target" unless defined $target;

	my $project_directory = shift // die "project_directory required";

	if ($target eq 'user_controller') {
		write_user_controller($project_directory, @target_args, %options);
	} elsif ($target eq 'paged_list_controller') {
		write_paged_list_controller($project_directory, @target_args, %options);
	} else {
		...
	}
}

caller or main(@ARGV);
