#!/usr/bin/env perl
package PaleWhite::MVC::ControllerPHPCompiler;
use strict;
use warnings;

use feature 'say';

use Data::Dumper;



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

	my @model_properties = grep { not exists $_->{modifiers}{array_property} } @{$model->{properties}};
	my @model_array_properties = grep { exists $_->{modifiers}{array_property} } @{$model->{properties}};
	my @model_submodel_properties = grep { $_->{type} eq 'model_pointer_property' } @{$model->{properties}};
	my @model_file_properties = grep { $_->{type} eq 'file_pointer_property' } @{$model->{properties}};
	my @model_json_properties = grep { $_->{type} eq 'model_property' and $_->{property_type} eq 'json' } @{$model->{properties}};

	if (@model_properties) {
		push @code, "public static \$model_properties = array(\n";
		push @code, "\t'id' => 'int',\n";
		push @code, "\t'$_->{identifier}' => '$_->{property_type}',\n" foreach @model_properties;
		push @code, ");\n";
	} else {
		push @code, "public static \$model_properties = array();\n";
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

	push @code, "\n";
	my %model_functions;
	foreach my $function (@{$model->{functions}}) {
		die "duplicate function $function->{identifier} defined in model $model->{identifier}"
				if exists $model_functions{$function->{identifier}};
		$model_functions{$function->{identifier}} = 1;

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

sub compile_controller {
	my ($self, $controller) = @_;
	die "invalid controller: $controller->{type}" unless $controller->{type} eq 'controller_definition';

	my $identifier = $controller->{identifier};
	my @code;

	my $parent = 'PaleWhite::Controller'; # $template->{arguments}[2] // 
	$parent = $self->format_classname($parent);

	push @code, $self->compile_controller_events_list($controller);

	push @code, $self->compile_controller_route($controller);
	push @code, $self->compile_controller_route_ajax($controller);
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

sub compile_controller_route {
	my ($self, $controller) = @_;
	my @code;

	$self->{context_args_variable} = '$req->args';

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

sub compile_controller_route_event {
	my ($self, $controller) = @_;
	my @code;

	$self->{context_args_variable} = '$args';

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
	} else {
		$target = "path \"$path->{path}\"";
	}

	push @code, $self->compile_path_arguments_validation($path->{arguments}, $target);
	# if (@{$path->{arguments}}) {

		# my $args_var = $self->{context_args_variable};
		# foreach my $arg (grep $_->{type} eq 'argument_specifier', @{$path->{arguments}}) {
		# 	push @code, "if (!isset(${args_var}['$arg->{identifier}']))\n";
		# 	if ($path->{type} eq 'event_block') {
		# 		push @code, "\tthrow new \\PaleWhite\\ValidationException"
		# 				. "('missing argument \"$arg->{identifier}\" to event \"$path->{identifier}\"');\n";
		# 	} elsif ($path->{type} eq 'action_block') {
		# 		push @code, "\tthrow new \\PaleWhite\\ValidationException"
		# 				. "('missing argument \"$arg->{identifier}\" to action \"$path->{identifier}\"');\n";
		# 	} else {
		# 		push @code, "\tthrow new \\PaleWhite\\ValidationException"
		# 				. "('missing argument \"$arg->{identifier}\" to path \"$path->{path}\"');\n";
		# 	}
		# }
		# push @code, "\n";
		# push @code, $self->compile_action_block($path->{arguments});
		# push @code, "\n";
	# }

	push @code, $self->compile_action_block($path->{block});

	if ($path->{type} eq 'match_path') {
		my ($condition_code, $match_code) = $self->compile_path_condition($path->{path});
		@code = (@$match_code, @code);

		@code = map "\t$_", @code;
		if ($first) {
			@code = ("if ($condition_code) {\n", @code);
		} else {
			@code = ("} elseif ($condition_code) {\n", @code);
		}
	} elsif ($path->{type} eq 'event_block') {
		my $condition_code = "\$event === '$path->{identifier}'";
		@code = map "\t$_", @code;
		if ($first) {
			@code = ("if ($condition_code) {\n", @code);
		} else {
			@code = ("} elseif ($condition_code) {\n", @code);
		}
	} elsif ($path->{type} eq 'action_block') {
		my $condition_code = "\$action === '$path->{identifier}'";
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
		# if ($path->{type} eq 'event_block') {
		# 	push @code, "\tthrow new \\PaleWhite\\ValidationException"
		# 			. "('missing argument \"$arg->{identifier}\" to event \"$path->{identifier}\"');\n";
		# } elsif ($path->{type} eq 'action_block') {
		# 	push @code, "\tthrow new \\PaleWhite\\ValidationException"
		# 			. "('missing argument \"$arg->{identifier}\" to action \"$path->{identifier}\"');\n";
		# } else {
		# }
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

sub compile_controller_action {
	my ($self, $controller) = @_;
	my @code;

	$self->{context_args_variable} = '$args';

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

# sub compile_controller_action_block {
# 	my ($self, $action, $first) = @_;
# 	my @code;

# 	if (@{$action->{arguments}}) {
# 		my $args_var = $self->{context_args_variable};
# 		foreach my $arg (grep $_->{type} eq 'argument_specifier', @{$action->{arguments}}) {
# 			push @code, "if (!isset(${args_var}['$arg->{identifier}']))\n";
# 			push @code, "\tthrow new \\PaleWhite\\ValidationException"
# 					. "('missing argument \"$arg->{identifier}\" to action \"$action->{identifier}\"');\n";
# 		}
# 		push @code, "\n";
# 		push @code, $self->compile_action_block($action->{arguments});
# 		push @code, "\n";
# 	}

# 	push @code, $self->compile_action_block($action->{block});
# 	# push @code, map "$_\n", map s/\A\t\t?//r, split "\n", $action->{code};

# 	@code = map "\t$_", @code;
# 	if ($first) {
# 		@code = ("if (\$action === '$action->{identifier}') {\n", @code);
# 	} else {
# 		@code = ("} elseif (\$action === '$action->{identifier}') {\n", @code);
# 	}

# 	return @code
# }

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
		return "\$res->body = \$this->render_template('$class', $arguments);\n"

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
		return "\$runtime->schedule_event('$action->{controller_identifier}', '$action->{event_identifier}', $arguments);\n"

	} elsif ($action->{type} eq 'controller_action') {
		my $arguments = $self->compile_arguments_array($action->{arguments});
		return "\$this->action('$action->{identifier}', $arguments);\n"

	} elsif ($action->{type} eq 'route_controller') {
		my $class = $self->format_classname($action->{identifier});
		my $path_argument = exists $action->{arguments}{path} ? $self->compile_expression($action->{arguments}{path}) : '$path';
		my $args_argument = exists $action->{arguments}{args} ? $self->compile_expression($action->{arguments}{args}) : '$args';
		# my $arguments = $self->compile_arguments_array($action->{arguments});
		return "\$this->route_subcontroller('$class', \$res, $path_argument, $args_argument);\n"

	} elsif ($action->{type} eq 'return_statement') {
		return "return;\n"

	} elsif ($action->{type} eq 'return_value_statement') {
		my $expression = $self->compile_expression($action->{expression});
		return "return $expression;\n"

	} elsif ($action->{type} eq 'argument_specifier') {
		my $args_var = $self->{context_args_variable};
		return "\$$action->{identifier} = ${args_var}['$action->{identifier}'];\n"

	} elsif ($action->{type} eq 'validate_variable') {
		if ($action->{validator_identifier} eq 'int') {
			return "\$$action->{identifier} = (int)\$$action->{identifier};\n"

		} elsif ($action->{validator_identifier} eq 'string') {
			my @code;
			push @code, "\$$action->{identifier} = (string)\$$action->{identifier};\n";
			if (exists $action->{validator_max_size}) {
				push @code, "if (strlen(\$$action->{identifier}) > $action->{validator_max_size})\n",
					"\tthrow new \\PaleWhite\\ValidationException('argument \"$action->{identifier}\" "
							. "exceeded max length of $action->{validator_max_size}');\n"
			}
			if (exists $action->{validator_min_size}) {
				push @code, "if (strlen(\$$action->{identifier}) < $action->{validator_min_size})\n",
					"\tthrow new \\PaleWhite\\ValidationException('argument \"$action->{identifier}\" "
							. "doesnt reach min length of $action->{validator_min_size}');\n"
			}
			return @code

		} elsif ($action->{validator_identifier} =~ $model_identifier_regex) {
			my $model_class = $action->{validator_identifier};
			$model_class =~ s/\Amodel::/\\/s;
			$model_class =~ s/::/\\/s;
			return "if (! (\$$action->{identifier} instanceof \\PaleWhite\\Model "
					. "&& \$$action->{identifier} instanceof $model_class))\n",
				"\tthrow new \\PaleWhite\\ValidationException"
					. "('argument \"$action->{identifier}\" not an instance of \"$model_class\" model');\n"

		} elsif ($action->{validator_identifier} eq '_file_upload') {
			return "if (! \$$action->{identifier} instanceof \\PaleWhite\\FileUpload)\n",
				"\tthrow new \\PaleWhite\\ValidationException('argument \"$action->{identifier}\" not a file upload');\n"

		} elsif ($action->{validator_identifier} eq '_csrf_token') {
			return "\$this->validate_csrf_token(\$$action->{identifier});\n"

		} else {
			return "\$$action->{identifier} = \$this->validate('$action->{validator_identifier}', \$$action->{identifier});\n"
		}
		
	} elsif ($action->{type} eq 'if_statement') {
		my $expression = $self->compile_expression($action->{expression});
		my @block = map "\t$_", $self->compile_action_block($action->{block});
		return "if ($expression) {\n", @block, "}\n"

	} elsif ($action->{type} eq 'else_statement') {
		my @block = map "\t$_", $self->compile_action_block($action->{block});
		return "else {\n", @block, "}\n"

	} elsif ($action->{type} eq 'assign_variable') {
		my $expression = $self->compile_expression($action->{expression});
		return "\$$action->{identifier} = $expression;\n"

	} elsif ($action->{type} eq 'assign_session_variable') {
		my $expression = $self->compile_expression($action->{expression});
		return "\$runtime->set_session_variable('$action->{identifier}', $expression);\n"

	} elsif ($action->{type} eq 'expression_statement') {
		if ($action->{expression}{type} ne 'method_call_expression') {
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
		return "\$this->load_model('$class', $arguments)"
		
	} elsif ($expression->{type} eq 'load_file_expression') {
		my $class = $self->format_classname($expression->{identifier});
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "\$this->load_file('$class', $arguments)"
		
	} elsif ($expression->{type} eq 'load_model_list_expression') {
		my $class = $self->format_classname($expression->{identifier});
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "$class\::get_list($arguments)"
		
	} elsif ($expression->{type} eq 'create_optional_model_expression') {
		my $class = $self->format_classname($expression->{identifier});
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "$class\::create($arguments)"
		
	} elsif ($expression->{type} eq 'create_model_expression') {
		my $class = $self->format_classname($expression->{identifier});
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "\$this->create_model('$class', $arguments)"
		
	} elsif ($expression->{type} eq 'render_template_expression') {
		my $class = $self->format_classname($expression->{identifier});
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "((new $class())->render($arguments))"
		
	} elsif ($expression->{type} eq 'render_file_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		return "file_get_contents(${sub_expression}->filepath)"

	} elsif ($expression->{type} eq 'controller_action_expression') {
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "\$this->action('$expression->{identifier}', $arguments)"

	} elsif ($expression->{type} eq 'string_expression') {
		return "'$expression->{value}'"

	} elsif ($expression->{type} eq 'localized_string_expression') {
		return "\$runtime->get_localized_string('$expression->{namespace_identifier}', '$expression->{identifier}')"

	} elsif ($expression->{type} eq 'string_interpolation_expression') {
		my $expression_list = $self->compile_expression_list($expression->{expression_list});
		return "implode('', array($expression_list))"
		
	} elsif ($expression->{type} eq 'integer_expression') {
		return "$expression->{value}"
		
	} elsif ($expression->{type} eq 'object_expression') {
		return '(object)' . $self->compile_arguments_array($expression->{value})
		
	} elsif ($expression->{type} eq 'array_expression') {
		return 'array(' . $self->compile_expression_list($expression->{value}) . ')'
		
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
		} else {
			return "\$$expression->{identifier}";
		}

	} elsif ($expression->{type} eq 'model_class_expression') {
		my $class = $self->format_classname($expression->{identifier});
		return $class

	} elsif ($expression->{type} eq 'native_library_expression') {
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
