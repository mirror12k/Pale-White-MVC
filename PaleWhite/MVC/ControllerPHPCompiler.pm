#!/usr/bin/env perl
package PaleWhite::MVC::ControllerPHPCompiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;



our $identifier_regex = qr/\A[a-zA-Z_][a-zA-Z0-9_]*+\Z/s;
our $model_identifier_regex = qr/\Amodel::[a-zA-Z_][a-zA-Z0-9_]*+(?:::[a-zA-Z_][a-zA-Z0-9_]*+)*\Z/s;


sub new {
	my ($class, %args) = @_;
	my $self = bless {}, $class;

	return $self
}



# sub compile {
# 	my ($self, $tree) = @_;

# 	my $code = "<?php\n\n";
# 	$code .= join '', $self->compile_controller($_) foreach @$tree;

# 	return $code
# }

# sub map_class_name {
# 	my ($self, $classname) = @_;

# 	return "/$classname" =~ s/\//\\/gr;
# }

sub format_classname {
	my ($self, $classname) = @_;
	return "\\$classname" =~ s/::/\\/gr
}

sub compile_model {
	my ($self, $model) = @_;


	my @code;

	push @code, "public static \$table_name = '$model->{identifier}';\n\n";
	push @code, "public static \$_model_cache = array('id' => array());\n";

	my @model_properties =
			grep { not exists $_->{modifiers}{array_property} and not exists $_->{modifiers}{map_property} }
			@{$model->{properties}};
	my @model_array_properties = grep { exists $_->{modifiers}{array_property} } @{$model->{properties}};
	my @model_map_properties = grep { exists $_->{modifiers}{map_property} } @{$model->{properties}};
	my @model_submodel_properties = grep { $_->{type} eq 'model_pointer_property' } @{$model->{properties}};
	my @model_file_properties = grep { $_->{type} eq 'file_pointer_property' } @{$model->{properties}};
	my @model_json_properties = grep { $_->{type} eq 'model_property' and $_->{property_type} eq 'json' } @{$model->{properties}};
	my @model_owned_properties = grep { exists $_->{modifiers}{owned} } @{$model->{properties}};

	if (@model_properties) {
		push @code, "public static \$model_properties = array(\n";
		push @code, "\t'id' => 'int',\n";
		push @code, "\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_properties;
		push @code, ");\n";
	} else {
		push @code, "public static \$model_properties = array();\n";
	}

	if (@model_map_properties) {
		push @code, "public static \$model_map_properties = array(\n";
		push @code, "\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_map_properties;
		push @code, ");\n";
	} else {
		push @code, "public static \$model_map_properties = array();\n";
	}

	if (@model_array_properties) {
		push @code, "public static \$model_array_properties = array(\n";
		push @code, "\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_array_properties;
		push @code, ");\n";
	} else {
		push @code, "public static \$model_array_properties = array();\n";
	}

	if (@model_submodel_properties) {
		push @code, "public static \$model_submodel_properties = array(\n";
		push @code, "\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_submodel_properties;
		push @code, ");\n";
	} else {
		push @code, "public static \$model_submodel_properties = array();\n";
	}

	if (@model_file_properties) {
		push @code, "public static \$model_file_properties = array(\n";
		push @code, "\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_file_properties;
		push @code, ");\n";
	} else {
		push @code, "public static \$model_file_properties = array();\n";
	}

	if (@model_json_properties) {
		push @code, "public static \$model_json_properties = array(\n";
		push @code, "\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_json_properties;
		push @code, ");\n";
	} else {
		push @code, "public static \$model_json_properties = array();\n";
	}

	if (@model_owned_properties) {
		push @code, "public static \$model_owned_properties = array(\n";
		push @code, "\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_owned_properties;
		push @code, ");\n";
	} else {
		push @code, "public static \$model_owned_properties = array();\n";
	}

	if (@{$model->{virtual_properties}}) {
		push @code, "public static \$model_virtual_properties = array(\n";
		push @code, "\t'$_->{identifier}' => '1',\n" foreach @{$model->{virtual_properties}};
		push @code, ");\n";
	} else {
		push @code, "public static \$model_virtual_properties = array();\n";
	}

	push @code, "\n";
	push @code, $self->compile_controller_constants($model);
	push @code, $self->compile_model_get_virtual_property($model);
	push @code, "\n";

	my %model_functions;
	foreach my $function (@{$model->{functions}}) {
		die "duplicate function $function->{identifier} defined in model $model->{identifier}"
				if exists $model_functions{$function->{identifier}};
		$model_functions{$function->{identifier}} = 1;

		$self->{block_context_type} = $function->{type};
		if ($function->{type} eq 'model_function') {
			push @code, "public function $function->{identifier} (array \$args = array()) {\n";
			push @code, "global \$runtime;\n\n";
			push @code, map "\t$_ ", $self->compile_path_arguments_validation($function->{arguments},
					"model function \"$function->{identifier}\"");
			push @code, map "\t$_ ", $self->compile_action_block($function->{block});
			# push @code, map "$_\n", split "\n", $function->{code};
			push @code, "}\n";
		} elsif ($function->{type} eq 'model_static_function') {
			push @code, "public static function $function->{identifier} (array \$args = array()) {\n";
			push @code, "global \$runtime;\n\n";
			push @code, map "\t$_ ", $self->compile_path_arguments_validation($function->{arguments},
					"model function \"$function->{identifier}\"");
			push @code, map "\t$_ ", $self->compile_action_block($function->{block});
			# push @code, map "$_\n", split "\n", $function->{code};
			push @code, "}\n";
		} elsif ($function->{type} eq 'on_event_function') {
			push @code, "public function $function->{identifier} () {\n";
			push @code, "\tparent::$function->{identifier}();\n";
			push @code, "global \$runtime;\n\n";
			push @code, map "\t$_ ", $self->compile_action_block($function->{block});
			# push @code, map "$_\n", split "\n", $function->{code};
			push @code, "}\n";
		} else {
			die "unimplemented function type $function->{type}";
		}
	}
	push @code, "\n";




	@code = map "\t$_", @code;
	@code = ("class $model->{identifier} extends \\PaleWhite\\Model {\n", @code, "}\n\n\n");

	return @code
}

sub compile_model_get_virtual_property {
	my ($self, $model) = @_;
	my @code;	

	return unless @{$model->{virtual_properties}};

	$self->{block_context_type} = 'model_virtual_properties';

	push @code, "global \$runtime;\n\n";

	my $first = 1;
	foreach my $property (@{$model->{virtual_properties}}) {
		if ($first) {
			push @code, "if (\$name === '$property->{identifier}') {\n";
		} else {
			push @code, "} elseif (\$name === '$property->{identifier}') {\n";
		}
		$first = 0;

		push @code, map "\t$_ ", $self->compile_action_block($property->{block});
	}

	push @code, "} else {\n";
	push @code, "\tparent::get_virtual_property(\$name);\n";
	push @code, "}\n";

	@code = map "\t$_", @code;
	@code = ("public function get_virtual_property(\$name) {\n", @code, "}\n", "\n");

	return @code;
}



sub compile_view_controller {
	my ($self, $view_controller) = @_;
	die "invalid view_controller: $view_controller->{type}" unless $view_controller->{type} eq 'view_controller_definition';

	my $identifier = $view_controller->{identifier};
	my @code;

	my $parent = 'PaleWhite::ViewController';
	$parent = $self->format_classname($parent);

	push @code, $self->compile_view_controller_args_block($view_controller);
	push @code, $self->compile_controller_action($view_controller);
	
	@code = map "\t$_", @code;
	@code = ("class $identifier extends $parent {\n", @code, "}\n", "\n");

	return @code
}

sub compile_view_controller_args_block {
	my ($self, $view_controller) = @_;
	my @code;

	$self->{context_args_variable} = '$args';
	$self->{block_context_type} = 'view_controller_args_block';

	return @code unless defined $view_controller->{args_block};

	push @code, "global \$runtime;\n\n";

	push @code, $self->compile_path($view_controller->{args_block});

	@code = map "\t$_", @code;
	@code = ("public function load_args (array \$args) {\n", @code, "}\n", "\n");

	return @code
}

sub compile_plugin {
	my ($self, $plugin) = @_;
	die "invalid plugin: $plugin->{type}" unless $plugin->{type} eq 'plugin_definition';

	my $identifier = $plugin->{identifier};
	my @code;

	my $parent = 'PaleWhite::Plugin';
	$parent = $self->format_classname($parent);

	push @code, $self->compile_plugin_event_hooks($plugin);
	push @code, $self->compile_plugin_action_hooks($plugin);
	push @code, $self->compile_plugin_controller_route_hooks($plugin);
	push @code, $self->compile_plugin_controller_ajax_hooks($plugin);
	push @code, $self->compile_plugin_controller_api_hooks($plugin);

	push @code, "\n";

	push @code, $self->compile_plugin_route_event($plugin);
	push @code, $self->compile_plugin_route_action($plugin);
	push @code, $self->compile_plugin_route_path($plugin);
	push @code, $self->compile_plugin_route_ajax($plugin);
	push @code, $self->compile_plugin_route_api($plugin);
	push @code, $self->compile_controller_action($plugin);
	
	@code = map "\t$_", @code;
	@code = ("class $identifier extends $parent {\n", @code, "}\n", "\n");

	return @code
}

sub compile_plugin_event_hooks {
	my ($self, $plugin) = @_;

	my @code;

	$plugin->{event_hooks} //= [];
	if (@{$plugin->{event_hooks}}) {
		push @code, "public \$event_hooks = array(\n";
		foreach my $event (@{$plugin->{event_hooks}}) {
			push @code, "\t'$event->{controller_class}:$event->{identifier}',\n";
		}
		push @code, ");\n";
	} else {
		push @code, "public \$event_hooks = array();\n";
	}

	return @code
}

sub compile_plugin_action_hooks {
	my ($self, $plugin) = @_;

	my @code;

	$plugin->{action_hooks} //= [];
	if (@{$plugin->{action_hooks}}) {
		push @code, "public \$action_hooks = array(\n";
		foreach my $event (@{$plugin->{action_hooks}}) {
			push @code, "\t'$event->{controller_class}:$event->{identifier}',\n";
		}
		push @code, ");\n";
	} else {
		push @code, "public \$action_hooks = array();\n";
	}

	return @code
}

sub compile_plugin_controller_route_hooks {
	my ($self, $plugin) = @_;

	my @code;

	$plugin->{controller_route_hooks} //= [];
	if (@{$plugin->{controller_route_hooks}}) {
		push @code, "public \$controller_route_hooks = array(\n";
		foreach my $event (@{$plugin->{controller_route_hooks}}) {
			push @code, "\t'$event->{controller_class}',\n";
		}
		push @code, ");\n";
	} else {
		push @code, "public \$controller_route_hooks = array();\n";
	}

	return @code
}

sub compile_plugin_controller_ajax_hooks {
	my ($self, $plugin) = @_;

	my @code;

	$plugin->{controller_ajax_hooks} //= [];
	if (@{$plugin->{controller_ajax_hooks}}) {
		push @code, "public \$controller_ajax_hooks = array(\n";
		foreach my $event (@{$plugin->{controller_ajax_hooks}}) {
			push @code, "\t'$event->{controller_class}',\n";
		}
		push @code, ");\n";
	} else {
		push @code, "public \$controller_ajax_hooks = array();\n";
	}

	return @code
}

sub compile_plugin_controller_api_hooks {
	my ($self, $plugin) = @_;

	my @code;

	$plugin->{controller_api_hooks} //= [];
	if (@{$plugin->{controller_api_hooks}}) {
		push @code, "public \$controller_api_hooks = array(\n";
		foreach my $event (@{$plugin->{controller_api_hooks}}) {
			push @code, "\t'$event->{controller_class}',\n";
		}
		push @code, ");\n";
	} else {
		push @code, "public \$controller_api_hooks = array();\n";
	}

	return @code
}

sub compile_plugin_route_event {
	my ($self, $plugin) = @_;
	my @code;

	$self->{context_args_variable} = '$args';
	$self->{block_context_type} = 'plugin_route_event';

	my @items;
	@items = (@items, @{$plugin->{event_hooks}}) if exists $plugin->{event_hooks};
	return @code unless @items;

	push @code, "global \$runtime;\n\n";

	my $first = 1;
	foreach my $item (@items) {
		push @code, $self->compile_path($item, $first);
		push @code, "\n";
		$first = 0;
	}

	push @code, "} else {\n";
	push @code, "\tparent::route_event_hook(\$event, \$args);\n";
	push @code, "}\n";

	@code = map "\t$_", @code;
	@code = ("public function route_event_hook (\$event, array \$args) {\n", @code, "}\n", "\n");

	return @code
}

sub compile_plugin_route_action {
	my ($self, $plugin) = @_;
	my @code;

	$self->{context_args_variable} = '$args';
	$self->{block_context_type} = 'plugin_route_action';

	my @items;
	@items = (@items, @{$plugin->{action_hooks}}) if exists $plugin->{action_hooks};
	return @code unless @items;

	push @code, "global \$runtime;\n\n";

	my $first = 1;
	foreach my $item (@items) {
		push @code, $self->compile_path($item, $first);
		push @code, "\n";
		$first = 0;
	}

	push @code, "} else {\n";
	push @code, "\tparent::route_action_hook(\$action, \$args);\n";
	push @code, "}\n";

	@code = map "\t$_", @code;
	@code = ("public function route_action_hook (\$action, array \$args) {\n", @code, "}\n", "\n");

	return @code
}

sub compile_plugin_route_path {
	my ($self, $plugin) = @_;
	my @code;

	$self->{context_args_variable} = '$req->args';
	$self->{block_context_type} = 'plugin_route_path';

	my @items;
	@items = (@items, @{$plugin->{controller_route_hooks}}) if exists $plugin->{controller_route_hooks};
	return @code unless @items;

	push @code, "global \$runtime;\n\n";

	my $first = 1;
	foreach my $item (@items) {
		push @code, $self->compile_path($item, $first);
		push @code, "\n";
		$first = 0;
	}

	push @code, "} else {\n";
	push @code, "\tparent::route_path_hook(\$controller, \$req, \$res);\n";
	push @code, "}\n";

	@code = map "\t$_", @code;
	@code = ("public function route_path_hook (\$controller, \\PaleWhite\\Request \$req, \\PaleWhite\\Response \$res) {\n",
			@code, "}\n", "\n");

	return @code
}

sub compile_plugin_route_ajax {
	my ($self, $plugin) = @_;
	my @code;

	$self->{context_args_variable} = '$req->args';
	$self->{block_context_type} = 'plugin_route_ajax';

	my @items;
	@items = (@items, @{$plugin->{controller_ajax_hooks}}) if exists $plugin->{controller_ajax_hooks};
	return @code unless @items;

	push @code, "global \$runtime;\n\n";

	my $first = 1;
	foreach my $item (@items) {
		push @code, $self->compile_path($item, $first);
		push @code, "\n";
		$first = 0;
	}

	push @code, "} else {\n";
	push @code, "\tparent::route_ajax_hook(\$controller, \$req, \$res);\n";
	push @code, "}\n";

	@code = map "\t$_", @code;
	@code = ("public function route_ajax_hook (\$controller, \\PaleWhite\\Request \$req, \\PaleWhite\\Response \$res) {\n",
			@code, "}\n", "\n");

	return @code
}

sub compile_plugin_route_api {
	my ($self, $plugin) = @_;
	my @code;

	$self->{context_args_variable} = '$req->args';
	$self->{block_context_type} = 'plugin_route_api';

	my @items;
	@items = (@items, @{$plugin->{controller_api_hooks}}) if exists $plugin->{controller_api_hooks};
	return @code unless @items;

	push @code, "global \$runtime;\n\n";

	my $first = 1;
	foreach my $item (@items) {
		push @code, $self->compile_path($item, $first);
		push @code, "\n";
		$first = 0;
	}

	push @code, "} else {\n";
	push @code, "\tparent::route_api_hook(\$controller, \$req, \$res);\n";
	push @code, "}\n";

	@code = map "\t$_", @code;
	@code = ("public function route_api_hook (\$controller, \\PaleWhite\\Request \$req, \\PaleWhite\\Response \$res) {\n",
			@code, "}\n", "\n");

	return @code
}






sub compile_controller {
	my ($self, $controller) = @_;
	die "invalid controller: $controller->{type}" unless $controller->{type} eq 'controller_definition';

	my $identifier = $controller->{identifier};
	my @code;

	my $parent = 'PaleWhite::Controller'; # $template->{arguments}[2] // 
	$parent = $self->format_classname($parent);

	push @code, $self->compile_controller_events_list($controller);

	push @code, $self->compile_controller_constants($controller);
	push @code, $self->compile_controller_route($controller);
	push @code, $self->compile_controller_route_ajax($controller);
	push @code, $self->compile_controller_route_api($controller);
	push @code, $self->compile_controller_route_event($controller);
	push @code, $self->compile_controller_validate($controller);
	push @code, $self->compile_controller_action($controller);
	
	@code = map "\t$_", @code;
	@code = ("class $identifier extends $parent {\n", @code, "}\n", "\n");

	return @code
}

sub compile_controller_events_list {
	my ($self, $controller) = @_;

	my @code;

	$controller->{controller_events} //= [];
	if (@{$controller->{controller_events}}) {
		push @code, "public static \$events = array(\n";
		foreach my $event (@{$controller->{controller_events}}) {
			push @code, "\t'$event->{identifier}',\n";
		}
		push @code, ");\n";
	} else {
		push @code, "public static \$events = array();\n";
	}

	push @code, "\n";

	return @code
}

sub compile_controller_constants {
	my ($self, $controller) = @_;

	my @code;

	$controller->{constants} //= [];
	if (@{$controller->{constants}}) {
		foreach my $constant (@{$controller->{constants}}) {
			my $expression = $self->compile_expression($constant->{expression});
			push @code, "\tpublic static \$$constant->{identifier} = $expression;\n";
		}
		push @code, "\n";
	}

	push @code, "\n";

	return @code
}

sub compile_controller_route {
	my ($self, $controller) = @_;
	my @code;

	$self->{context_args_variable} = '$req->args';
	$self->{block_context_type} = 'controller_route';

	my @paths;
	@paths = (@paths, @{$controller->{global_paths}}) if exists $controller->{global_paths};
	@paths = (@paths, @{$controller->{paths}}) if exists $controller->{paths};
	return @code unless @paths;

	push @code, "parent::route(\$req, \$res);\n";
	push @code, "global \$runtime;\n\n";
	my $first = 1;
	foreach my $path (@paths) {
		push @code, $self->compile_path($path, $first);
		push @code, "\n";
		$first = 0 if $path->{type} eq 'match_path';
	}

	if (exists $controller->{default_path}) {
		push @code, "} else {\n";
		push @code, map "\t$_", $self->compile_path($controller->{default_path});
	}
	push @code, "}\n";

	if (exists $controller->{error_path}) {
		@code = map "\t$_", @code;
		my @exception_code = map "\t$_", $self->compile_path($controller->{error_path});
		unshift @exception_code, "\t\$runtime->log_exception(get_called_class(), \$e);\n";

		@code = ("try {\n", @code, "} catch (\\Exception \$e) {\n", @exception_code, "}\n");
	}
	@code = map "\t$_", @code;

	@code = ("public function route (\\PaleWhite\\Request \$req, \\PaleWhite\\Response \$res) {\n", @code, "}\n", "\n");

	return @code
}

sub compile_controller_route_ajax {
	my ($self, $controller) = @_;
	my @code;

	$self->{context_args_variable} = '$req->args';
	$self->{block_context_type} = 'controller_route_ajax';

	my @paths;
	@paths = (@paths, @{$controller->{global_ajax_paths}}) if exists $controller->{global_ajax_paths};
	@paths = (@paths, @{$controller->{ajax_paths}}) if exists $controller->{ajax_paths};
	return @code unless @paths;

	push @code, "parent::route_ajax(\$req, \$res);\n";
	push @code, "global \$runtime;\n\n";
	my $first = 1;
	foreach my $path (@paths) {
		push @code, $self->compile_path($path, $first);
		push @code, "\n";
		$first = 0 if $path->{type} eq 'match_path';
	}

	if (exists $controller->{default_ajax_path}) {
		push @code, "} else {\n";
		push @code, map "\t$_", $self->compile_path($controller->{default_ajax_path});
	}
	push @code, "}\n";

	if (exists $controller->{error_ajax_path}) {
		@code = map "\t$_", @code;
		my @exception_code = map "\t$_", $self->compile_path($controller->{error_ajax_path});
		@code = ("try {\n", @code, "} catch (\\Exception \$e) {\n", @exception_code, "}\n");
	}
	@code = map "\t$_", @code;

	@code = ("public function route_ajax (\\PaleWhite\\Request \$req, \\PaleWhite\\Response \$res) {\n", @code, "}\n", "\n");

	return @code
}

sub compile_controller_route_api {
	my ($self, $controller) = @_;
	my @code;

	$self->{context_args_variable} = '$req->args';
	$self->{block_context_type} = 'controller_route_api';

	my @paths;
	@paths = (@paths, @{$controller->{global_api_paths}}) if exists $controller->{global_api_paths};
	@paths = (@paths, @{$controller->{api_paths}}) if exists $controller->{api_paths};
	return @code unless @paths;

	push @code, "parent::route_api(\$req, \$res);\n";
	push @code, "global \$runtime;\n\n";
	my $first = 1;
	foreach my $path (@paths) {
		push @code, $self->compile_path($path, $first);
		push @code, "\n";
		$first = 0 if $path->{type} eq 'match_path';
	}

	if (exists $controller->{default_api_path}) {
		push @code, "} else {\n";
		push @code, map "\t$_", $self->compile_path($controller->{default_api_path});
	}
	push @code, "}\n";

	if (exists $controller->{error_api_path}) {
		@code = map "\t$_", @code;
		my @exception_code = map "\t$_", $self->compile_path($controller->{error_api_path});
		@code = ("try {\n", @code, "} catch (\\Exception \$e) {\n", @exception_code, "}\n");
	}
	@code = map "\t$_", @code;

	@code = ("public function route_api (\\PaleWhite\\Request \$req, \\PaleWhite\\Response \$res) {\n", @code, "}\n", "\n");

	return @code
}

sub compile_controller_route_event {
	my ($self, $controller) = @_;
	my @code;

	$self->{context_args_variable} = '$args';
	$self->{block_context_type} = 'controller_route_event';

	my @events;
	@events = (@events, @{$controller->{controller_events}}) if exists $controller->{controller_events};
	return @code unless @events;

	push @code, "global \$runtime;\n\n";

	my $first = 1;
	foreach my $event (@events) {
		push @code, $self->compile_path($event, $first);
		push @code, "\n";
		$first = 0;
	}

	push @code, "} else {\n";
	push @code, "\tparent::route_event(\$event, \$args);\n";
	push @code, "}\n";

	@code = map "\t$_", @code;
	@code = ("public function route_event (\$event, array \$args) {\n", @code, "}\n", "\n");

	return @code
}

sub compile_controller_action {
	my ($self, $controller) = @_;
	my @code;

	$self->{context_args_variable} = '$args';
	$self->{block_context_type} = 'controller_action';

	my @actions;
	if (exists $controller->{actions}) {
		@actions = @{$controller->{actions}};
	}
	return @code unless @actions;

	push @code, "global \$runtime;\n\n";

	my $first = 1;
	foreach my $action (@actions) {
		# push @code, $self->compile_controller_action_block($action, $first);
		push @code, $self->compile_path($action, $first);
		$first = 0;
	}
	push @code, "} else {\n", "\treturn parent::action(\$action, \$args);\n", "}\n";

	@code = map "\t$_", @code;
	@code = ("public function action (\$action, array \$args) {\n", @code, "}\n", "\n");

	return @code
}

sub compile_path {
	my ($self, $path, $first) = @_;
	my @code;

	my $target;
	if ($path->{type} eq 'event_block') {
		$target = "event \"$path->{identifier}\"";
	} elsif ($path->{type} eq 'action_block') {
		$target = "action \"$path->{identifier}\"";
	} elsif ($path->{type} eq 'default_path') {
		$target = "path default";
	} elsif ($path->{type} eq 'global_path') {
		$target = "path default";
	} elsif ($path->{type} eq 'event_hook') {
		$target = "event hook \"$path->{controller_class}:$path->{identifier}\"";
	} elsif ($path->{type} eq 'action_hook') {
		$target = "action hook \"$path->{controller_class}:$path->{identifier}\"";
	} elsif ($path->{type} eq 'controller_route_hook') {
		$target = "controller route hook \"$path->{controller_class}\"";
	} elsif ($path->{type} eq 'controller_ajax_hook') {
		$target = "controller ajax hook \"$path->{controller_class}\"";
	} elsif ($path->{type} eq 'args_block') {
		$target = "args block";
	} else {
		$target = "path \"$path->{path}\"";
	}

	push @code, $self->compile_path_arguments_validation($path->{arguments}, $target) if exists $path->{arguments};

	push @code, $self->compile_action_block($path->{block});

	my $condition_code;
	if ($path->{type} eq 'match_path') {
		my $match_code;
		($condition_code, $match_code) = $self->compile_path_condition($path->{path});
		@code = (@$match_code, @code);
	} elsif ($path->{type} eq 'event_block') {
		$condition_code = "\$event === '$path->{identifier}'";
	} elsif ($path->{type} eq 'action_block') {
		$condition_code = "\$action === '$path->{identifier}'";
	} elsif ($path->{type} eq 'event_hook') {
		$condition_code = "\$event === '$path->{controller_class}:$path->{identifier}'";
	} elsif ($path->{type} eq 'action_hook') {
		$condition_code = "\$action === '$path->{controller_class}:$path->{identifier}'";
	} elsif ($path->{type} eq 'controller_route_hook') {
		$condition_code = "\$controller === '$path->{controller_class}'";
	} elsif ($path->{type} eq 'controller_ajax_hook') {
		$condition_code = "\$controller === '$path->{controller_class}'";
	}

	if (defined $condition_code) {
		@code = map "\t$_", @code;
		if ($first) {
			@code = ("if ($condition_code) {\n", @code);
		} else {
			@code = ("} elseif ($condition_code) {\n", @code);
		}
	}

	return @code
}

sub compile_path_arguments_validation {
	my ($self, $arguments, $target) = @_;
	my @code;

	return unless @$arguments;

	my $args_var = $self->{context_args_variable};

	foreach my $arg (grep $_->{type} eq 'argument_specifier', @$arguments) {
		push @code, "if (!isset(${args_var}['$arg->{identifier}']))\n";
		push @code, "\tthrow new \\PaleWhite\\ValidationException"
				. "('missing argument \"$arg->{identifier}\" to $target');\n";
	}
	push @code, "\n";
	push @code, $self->compile_action_block($arguments);
	push @code, "\n";

	return @code
}


sub compile_path_condition {
	my ($self, $condition) = @_;

	my $condition_code;
	my @match_code;

	if (ref $condition eq 'ARRAY') {
		my $condition_regex = join '', map {
			$_->{type} eq 'string_token'
				? $_->{value} =~ s#/#\\/#gr
				: '(' . ($_->{regex} =~ s#/#\\/#gr) . ')'
		} @$condition;

		$condition_code = "preg_match('/\\A$condition_regex\\Z/', \$req->path, \$_matches)";

		my @match_conditions = grep $_->{type} ne 'string_token', @$condition;
		foreach my $i (0 .. $#match_conditions) {
			my $match = $match_conditions[$i];
			my $index = $i + 1;
			if ($match->{type} eq 'match_list_identifier') {
				push @match_code, "\$$match->{identifier} = explode('$match->{seperator}', \$_matches[$index]);\n";
			} elsif ($match->{type} eq 'match_identifier') {
				push @match_code, "\$$match->{identifier} = \$_matches[$index];\n";
			} else {
				# nothing
			}
		}

	} else {
		$condition_code = "\$req->path === '$condition'";
	}
	# warn "debug condition code: $condition_code";
	# warn "debug match code: " . join '', @match_code;

	return $condition_code, \@match_code
}

sub compile_controller_validate {
	my ($self, $controller) = @_;
	my @code;

	my @validators;
	if (exists $controller->{validators}) {
		@validators = @{$controller->{validators}};
	}
	return @code unless @validators;

	push @code, "global \$runtime;\n\n";

	my $first = 1;
	foreach my $validator (@validators) {
		push @code, $self->compile_validator($validator, $first);
		$first = 0;
	}
	push @code, "} else {\n", "\treturn parent::validate(\$type, \$value);\n", "}\n";

	@code = map "\t$_", @code;
	@code = ("public function validate (\$type, \$value) {\n", @code, "}\n", "\n");

	return @code
}

sub compile_validator {
	my ($self, $validator, $first) = @_;
	my @code;

	push @code, map "$_\n", map s/\A\t\t?//r, split "\n", $validator->{code};

	@code = map "\t$_", @code;
	if ($first) {
		@code = ("if (\$type === '$validator->{identifier}') {\n", @code);
	} else {
		@code = ("} elseif (\$type === '$validator->{identifier}') {\n", @code);
	}

	return @code
}

sub compile_action_block {
	my ($self, $block) = @_;
	return map $self->compile_action($_), @$block;
}

sub compile_action {
	my ($self, $action) = @_;

	if ($action->{type} eq 'log_message') {
		my $expression = $self->compile_expression($action->{expression});
		return "\$runtime->log_message(get_called_class(), $expression);\n"

	} elsif ($action->{type} eq 'log_exception') {
		my $expression = $self->compile_expression($action->{expression});
		return "\$runtime->log_exception(get_called_class(), $expression);\n"

	} elsif ($action->{type} eq 'render_template') {
		my $class = $self->format_classname($action->{identifier});
		my $arguments = $self->compile_arguments_array($action->{arguments});
		return "\$res->body = \$runtime->get_template('$class')->render($arguments);\n"

	} elsif ($action->{type} eq 'render_file') {
		my $expression = $self->compile_expression($action->{expression});
		return "\$res->body = $expression;\n"

	} elsif ($action->{type} eq 'render_json') {
		my $arguments = $self->compile_arguments_array($action->{arguments});
		return "\$res->body = $arguments;\n"

	} elsif ($action->{type} eq 'set_localization') {
		my $expression = $self->compile_expression($action->{expression});
		return "\$runtime->set_localization($expression);\n"

	} elsif ($action->{type} eq 'assign_status') {
		my $expression = $self->compile_expression($action->{expression});
		return "\$res->status = $expression;\n"

	} elsif ($action->{type} eq 'assign_redirect') {
		my $expression = $self->compile_expression($action->{expression});
		return "\$res->redirect = $expression;\n"

	} elsif ($action->{type} eq 'assign_header') {
		my $expression = $self->compile_expression($action->{expression});
		my $header = lc $action->{header_string};
		return "\$res->headers['$header'] = $expression;\n"

	} elsif ($action->{type} eq 'schedule_event') {
		my $arguments = $self->compile_arguments_array($action->{arguments});
		return "\$runtime->schedule_event(get_called_class(), '$action->{controller_identifier}', "
				. "'$action->{event_identifier}', $arguments);\n"

	# } elsif ($action->{type} eq 'shell_execute') {
	# 	my $arguments_list = $self->compile_expression_list($action->{arguments_list});
	# 	return "\$runtime->shell_execute(get_called_class(), array($arguments_list));\n"

	# } elsif ($action->{type} eq 'controller_action') {
	# 	my $arguments = $self->compile_arguments_array($action->{arguments});
	# 	return "\$runtime->trigger_action(get_called_class(), '$action->{identifier}', $arguments);\n"

	} elsif ($action->{type} eq 'route_controller') {
		my $class = $self->format_classname($action->{identifier});
		my $path_argument = exists $action->{arguments}{path}
				? $self->compile_expression($action->{arguments}{path}) : '$req->path';
		my $args_argument = exists $action->{arguments}{args}
				? $self->compile_expression($action->{arguments}{args}) : $self->{context_args_variable};
		# my $arguments = $self->compile_arguments_array($action->{arguments});
		if ($self->{block_context_type} eq 'controller_route' or $self->{block_context_type} eq 'plugin_route_path') {
			return "\$runtime->route_controller_path('$class', $path_argument, $args_argument, \$res);\n"
		} elsif ($self->{block_context_type} eq 'controller_route_ajax' or $self->{block_context_type} eq 'plugin_route_ajax') {
			return "\$runtime->route_controller_ajax('$class', $path_argument, $args_argument, \$res);\n"
		} elsif ($self->{block_context_type} eq 'controller_route_api' or $self->{block_context_type} eq 'plugin_route_api') {
			return "\$runtime->route_controller_api('$class', $path_argument, $args_argument, \$res);\n"
		} else {
			die "attempt to route controller in invalid context '$self->{block_context_type}' on line $action->{line_number}";
		}

	} elsif ($action->{type} eq 'return_statement') {
		return "return;\n"

	} elsif ($action->{type} eq 'return_value_statement') {
		my $expression = $self->compile_expression($action->{expression});
		return "return $expression;\n"

	} elsif ($action->{type} eq 'argument_specifier') {
		my $args_var = $self->{context_args_variable};
		return "\$$action->{identifier} = ${args_var}['$action->{identifier}'];\n"

	} elsif ($action->{type} eq 'optional_argument_specifier') {
		my $args_var = $self->{context_args_variable};
		return "\$$action->{identifier} = isset(${args_var}['$action->{identifier}']) "
				. "? ${args_var}['$action->{identifier}'] : null;\n"

	} elsif ($action->{type} eq 'validate_variable' or $action->{type} eq 'optional_validate_variable') {
		my @code;

		my ($min_size, $max_size);
		if (exists $action->{validator_max_size}) {
			$max_size = $action->{validator_max_size};
			# if max_size is a constant reference, compile it as such
			$max_size = "self::\$$max_size" if $max_size =~ $identifier_regex;
		}
		if (exists $action->{validator_min_size}) {
			$min_size = $action->{validator_min_size};
			# if min_size is a constant reference, compile it as such
			$min_size = "self::\$$min_size" if $min_size =~ $identifier_regex;
		}

		if ($action->{validator_identifier} eq 'int') {
			push @code, "\$$action->{identifier} = (int)\$$action->{identifier};\n";

		} elsif ($action->{validator_identifier} eq 'string') {
			push @code, "\$$action->{identifier} = (string)\$$action->{identifier};\n";
			if (defined $max_size) {
				push @code, "if (strlen(\$$action->{identifier}) > $max_size)\n",
					"\tthrow new \\PaleWhite\\ValidationException('argument \"$action->{identifier}\" "
							. "exceeded max length of ' . $max_size);\n";
			}
			if (defined $min_size) {
				push @code, "if (strlen(\$$action->{identifier}) < $min_size)\n",
					"\tthrow new \\PaleWhite\\ValidationException('argument \"$action->{identifier}\" "
							. "doesnt reach min length of ' . $min_size);\n";
			}

		} elsif ($action->{validator_identifier} =~ $model_identifier_regex) {
			my $model_class = $action->{validator_identifier};
			$model_class =~ s/\Amodel::/\\/s;
			$model_class =~ s/::/\\/s;
			push @code, "if (! (\$$action->{identifier} instanceof \\PaleWhite\\Model "
					. "&& \$$action->{identifier} instanceof $model_class))\n",
				"\tthrow new \\PaleWhite\\ValidationException"
					. "('argument \"$action->{identifier}\" not an instance of \"$model_class\" model');\n";

		} elsif ($action->{validator_identifier} eq '_file_upload') {
			push @code, "if (! \$$action->{identifier} instanceof \\PaleWhite\\FileUpload)\n",
				"\tthrow new \\PaleWhite\\ValidationException('argument \"$action->{identifier}\" not a file upload');\n";
			if (defined $max_size) {
				push @code, "if (\$$action->{identifier}->file_size > $max_size)\n",
					"\tthrow new \\PaleWhite\\ValidationException('file argument \"$action->{identifier}\" "
							. "exceeded max length of ' . $max_size);\n";
			}
			if (defined $min_size) {
				push @code, "if (\$$action->{identifier}->file_size < $min_size)\n",
					"\tthrow new \\PaleWhite\\ValidationException('file argument \"$action->{identifier}\" "
							. "doesnt reach min length of ' . $min_size);\n";
			}

		} elsif ($action->{validator_identifier} eq '_csrf_token') {
			push @code, "\$runtime->validate_csrf_token(\$$action->{identifier});\n"

		} else {
			push @code, "\$$action->{identifier} = \$this->validate('$action->{validator_identifier}', \$$action->{identifier});\n"
		}

		if ($action->{type} eq 'optional_validate_variable') {
			@code = map "\t$_", @code;
			@code = ("if (isset(\$$action->{identifier})) {\n", @code, "}\n");
		}

		return @code
		
	} elsif ($action->{type} eq 'if_statement') {
		my $expression = $self->compile_expression($action->{expression});
		my @block = map "\t$_", $self->compile_action_block($action->{block});
		if ($action->{expression}{type} eq 'access_expression') {
			return "if (isset($expression) && ($expression)) {\n", @block, "}\n"
		} else {
			return "if ($expression) {\n", @block, "}\n"
		}

	} elsif ($action->{type} eq 'else_statement') {
		my @block = map "\t$_", $self->compile_action_block($action->{block});
		return "else {\n", @block, "}\n"

	} elsif ($action->{type} eq 'assign_variable') {
		my $expression = $self->compile_expression($action->{expression});
		return "\$$action->{identifier} = $expression;\n"

	} elsif ($action->{type} eq 'assign_member_variable') {
		my $expression = $self->compile_expression($action->{expression});
		return "\$$action->{variable_identifier}->$action->{identifier} = $expression;\n"

	} elsif ($action->{type} eq 'assign_session_variable') {
		my $expression = $self->compile_expression($action->{expression});
		return "\$runtime->set_session_variable('$action->{identifier}', $expression);\n"

	} elsif ($action->{type} eq 'expression_statement') {
		if ($action->{expression}{type} ne 'method_call_expression'
				and $action->{expression}{type} ne 'shell_execute_expression'
				and $action->{expression}{type} ne 'plugin_action_expression'
				and $action->{expression}{type} ne 'controller_action_expression'
				and $action->{expression}{type} ne 'local_controller_action_expression') {
			die "expression statement cannot be of type '$action->{expression}{type}'"
				. " on line $action->{expression}{line_number}";
		}

		my $expression = $self->compile_expression($action->{expression});
		return "$expression;\n"

	} else {
		die "invalid action: $action->{type}";
	}
}

sub compile_arguments_array {
	my ($self, $arguments) = @_;


	my @expressions;
	foreach my $key (sort keys %$arguments) {
		push @expressions, "'$key' => " . $self->compile_expression($arguments->{$key});
	}

	return 'array(' . join (', ', @expressions) . ')'
}

sub compile_object_expression_array {
	my ($self, $arguments) = @_;


	my @expressions;
	foreach my $key (@$arguments) {
		if ($key->{type} eq 'identifier_object_key') {
			push @expressions, "'$key->{identifier}' => " . $self->compile_expression($key->{expression});
		} elsif ($key->{type} eq 'string_object_key') {
			my $key_string = $key->{value};
			$key_string =~ s/([\\'])/\\$1/gs;
			push @expressions, "'$key_string' => " . $self->compile_expression($key->{expression});
		} else {
			push @expressions, $self->compile_expression($key->{key_expression})
					. " => " . $self->compile_expression($key->{value_expresssion});
		}
	}

	return 'array(' . join (', ', @expressions) . ')'
}


sub compile_expression_list {
	my ($self, $expression_list) = @_;

	return join ', ', map $self->compile_expression($_), @$expression_list
}


sub compile_expression {
	my ($self, $expression) = @_;

	if ($expression->{type} eq 'load_optional_model_expression') {
		my $class = $self->format_classname($expression->{identifier});
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "$class\::get_by($arguments)"
		
	} elsif ($expression->{type} eq 'load_model_expression') {
		my $class = $self->format_classname($expression->{identifier});
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "\$runtime->load_model('$class', $arguments)"
		
	} elsif ($expression->{type} eq 'load_file_expression') {
		my $class = $self->format_classname($expression->{identifier});
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "\$runtime->load_file('$class', $arguments)"
		
	} elsif ($expression->{type} eq 'load_model_list_expression') {
		my $class = $self->format_classname($expression->{identifier});
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "$class\::get_list($arguments)"
		
	} elsif ($expression->{type} eq 'load_model_count_expression') {
		my $class = $self->format_classname($expression->{identifier});
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "$class\::count($arguments)"
		
	} elsif ($expression->{type} eq 'create_optional_model_expression') {
		my $class = $self->format_classname($expression->{identifier});
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "$class\::create($arguments)"
		
	} elsif ($expression->{type} eq 'create_model_expression') {
		my $class = $self->format_classname($expression->{identifier});
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "\$runtime->create_model('$class', $arguments)"
		
	} elsif ($expression->{type} eq 'render_template_expression') {
		my $class = $self->format_classname($expression->{identifier});
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "(\$runtime->get_template('$class')->render($arguments))"
		
	} elsif ($expression->{type} eq 'render_file_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		return "file_get_contents(${sub_expression}->filepath)"
		
	} elsif ($expression->{type} eq 'render_json_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		return "json_encode(${sub_expression})"
		
	} elsif ($expression->{type} eq 'shell_execute_expression') {
		my $arguments_list = $self->compile_expression_list($expression->{arguments_list});
		return "\$runtime->shell_execute(get_called_class(), array($arguments_list))"

	} elsif ($expression->{type} eq 'plugin_action_expression') {
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "\$runtime->plugins->$expression->{plugin_identifier}\->action('$expression->{action_identifier}', $arguments)"

	} elsif ($expression->{type} eq 'controller_action_expression') {
		my $class = $self->format_classname($expression->{controller_identifier});
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "\$runtime->trigger_action('$class', '$expression->{action_identifier}', $arguments)"

	} elsif ($expression->{type} eq 'local_controller_action_expression') {
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "\$runtime->trigger_action(get_called_class(), '$expression->{action_identifier}', $arguments)"

	} elsif ($expression->{type} eq 'string_expression') {
		my $string = $expression->{value};
		$string =~ s/([\\'])/\\$1/gs;
		return "'$string'";

	} elsif ($expression->{type} eq 'localized_string_expression') {
		return "\$runtime->get_localized_string('$expression->{namespace_identifier}', '$expression->{identifier}')"

	} elsif ($expression->{type} eq 'string_interpolation_expression') {
		my $expression_list = $self->compile_expression_list($expression->{expression_list});
		return "implode('', array($expression_list))"
		
	} elsif ($expression->{type} eq 'integer_expression') {
		return "$expression->{value}"
		
	} elsif ($expression->{type} eq 'not_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		return "!( $sub_expression )"
		
	} elsif ($expression->{type} eq 'object_expression') {
		return '(object)' . $self->compile_object_expression_array($expression->{values})
		
	} elsif ($expression->{type} eq 'array_expression') {
		return 'array(' . $self->compile_expression_list($expression->{value}) . ')'
		
	} elsif ($expression->{type} eq 'parentheses_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		return "( $sub_expression )"
		
	} elsif ($expression->{type} eq 'session_variable_expression') {
		return "\$runtime->get_session_variable('$expression->{identifier}')";

	} elsif ($expression->{type} eq 'length_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		return "count($sub_expression)"

	} elsif ($expression->{type} eq 'variable_expression') {
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		# if ($expression->{identifier} eq '_csrf_token') {
		# 	return "\$_SESSION['pale_white_csrf_token']";
		# } els
		if ($expression->{identifier} eq '_time') {
			return "time()";
		} elsif ($expression->{identifier} eq 'plugins') {
			return "\$runtime->plugins";
		} else {
			return "\$$expression->{identifier}";
		}

	} elsif ($expression->{type} eq 'model_class_expression') {
		my $class = $self->format_classname($expression->{identifier});
		return $class

	} elsif ($expression->{type} eq 'native_library_expression') {
		my $class = $self->format_classname($expression->{identifier});
		return $class

	} elsif ($expression->{type} eq 'controller_expression') {
		my $class = $self->format_classname($expression->{identifier});
		return $class

	} elsif ($expression->{type} eq 'method_call_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		my $arguments_list = $self->compile_expression_list($expression->{arguments_list});

		if ($expression->{expression}{type} eq 'variable_expression') {
			return "$sub_expression->$expression->{identifier}($arguments_list)";
		} elsif ($expression->{expression}{type} eq 'access_expression') {
			return "$sub_expression->$expression->{identifier}($arguments_list)";
		} elsif ($expression->{expression}{type} eq 'model_class_expression') {
			return "$sub_expression\::$expression->{identifier}($arguments_list)";
		} elsif ($expression->{expression}{type} eq 'native_library_expression') {
			return "$sub_expression\::$expression->{identifier}($arguments_list)";
		} elsif ($expression->{expression}{type} eq 'controller_expression') {
			return "$sub_expression\::$expression->{identifier}($arguments_list)";
		} else {
			die "invalid method call on a '$expression->{expression}{type}' on line $expression->{line_number}";
		}
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";

	} elsif ($expression->{type} eq 'access_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});

		if ($expression->{expression}{type} eq 'variable_expression') {
			return "$sub_expression->$expression->{identifier}";
		} elsif ($expression->{expression}{type} eq 'access_expression') {
			return "$sub_expression->$expression->{identifier}";
		} elsif ($expression->{expression}{type} eq 'model_class_expression') {
			return "$sub_expression\::\$$expression->{identifier}";
		} elsif ($expression->{expression}{type} eq 'native_library_expression') {
			return "$sub_expression\::\$$expression->{identifier}";
		} elsif ($expression->{expression}{type} eq 'controller_expression') {
			return "$sub_expression\::\$$expression->{identifier}";
		} else {
			die "invalid access on a '$expression->{expression}{type}' on line $expression->{line_number}";
		}

	} elsif ($expression->{type} eq 'less_than_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "( $left_expression < $right_expression )";

	} elsif ($expression->{type} eq 'greather_than_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "( $left_expression > $right_expression )";

	} elsif ($expression->{type} eq 'less_than_or_equal_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "( $left_expression <= $right_expression )";

	} elsif ($expression->{type} eq 'greather_than_or_equal_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "( $left_expression >= $right_expression )";

	} elsif ($expression->{type} eq 'equals_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "( $left_expression === $right_expression )";

	} elsif ($expression->{type} eq 'not_equals_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "( $left_expression !== $right_expression )";

	} elsif ($expression->{type} eq 'addition_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "( $left_expression + $right_expression )";

	} elsif ($expression->{type} eq 'subtraction_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "( $left_expression - $right_expression )";

	} elsif ($expression->{type} eq 'multiplication_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "( $left_expression * $right_expression )";

	} elsif ($expression->{type} eq 'division_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "( $left_expression / $right_expression )";

	} elsif ($expression->{type} eq 'modulo_expression') {
		my $left_expression = $self->compile_expression($expression->{left_expression});
		my $right_expression = $self->compile_expression($expression->{right_expression});
		return "( $left_expression % $right_expression )";

	} else {
		die "unknown expression: $expression->{type}";
	}
}


# sub compile_file {
# 	my ($file) = @_;
# 	use Sugar::IO::File;
# 	use PaleWhite::ControllerParser;

# 	my $parser = PaleWhite::ControllerParser->new;
# 	$parser->{filepath} = Sugar::IO::File->new($file);
# 	my $tree = $parser->parse;
# 	# say Dumper $tree;

# 	my $compiler = __PACKAGE__->new;
# 	my $text = $compiler->compile($tree);
# 	return $text;
# }


# sub main {
# 	foreach my $file (@_) {
# 		say compile_file($file);
# 	}
# }

# caller or main(@ARGV);

1;
