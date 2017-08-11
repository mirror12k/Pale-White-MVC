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

sub map_class_name {
	my ($self, $classname) = @_;

	return "/$classname" =~ s/\//\\/gr;
}

sub compile_controller {
	my ($self, $controller) = @_;
	die "invalid controller: $controller->{type}" unless $controller->{type} eq 'controller_definition';

	my $identifier = $controller->{identifier};
	my @code;

	my $parent = 'PaleWhite/Controller'; # $template->{arguments}[2] // 
	$parent = $self->map_class_name($parent);

	push @code, $self->compile_controller_route($controller);
	push @code, $self->compile_controller_route_ajax($controller);
	push @code, $self->compile_controller_validate($controller);
	push @code, $self->compile_controller_action($controller);
	
	@code = map "\t$_", @code;
	@code = ("class $identifier extends $parent {\n", @code, "}\n", "\n");

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
	push @code, "\n";
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
	push @code, "\n";
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

sub compile_path {
	my ($self, $path, $first) = @_;
	my @code;

	if (@{$path->{arguments}}) {
		my $args_var = $self->{context_args_variable};
		foreach my $arg (grep $_->{type} eq 'argument_specifier', @{$path->{arguments}}) {
			push @code, "if (!isset(${args_var}['$arg->{identifier}']))\n";
			push @code, "\tthrow new \\Exception('missing argument \"$arg->{identifier}\" to path \"$path->{path}\"');\n";
		}
		push @code, "\n";
		push @code, $self->compile_action_block($path->{arguments});
		push @code, "\n";
	}

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
	}

	return @code
}

our $identifier_regex = qr/[a-zA-Z_][a-zA-Z0-9_]*+/;

sub compile_path_condition {
	my ($self, $condition) = @_;

	my $condition_code;
	my @match_code;

	# warn "debug condition: $condition";
	my @condition_vars = ($condition =~ 
			/(?|\{\{($identifier_regex=\[\])\}\}|\{\{($identifier_regex)\}\}|\{\{((?:$identifier_regex=)?\.\.\.)\}\})/g);

	if (@condition_vars) {
		# warn "debug condition vars: " . join ',', @condition_vars;

		$condition =~ s/\{\{($identifier_regex=\[\])\}\}/(.+?)/sg;
		$condition =~ s/\{\{($identifier_regex)\}\}/([^\/]+?)/sg;
		$condition =~ s/\{\{(($identifier_regex=)?\.\.\.)\}\}/(.+?)/sg;
		$condition =~ s#/#\\/#g;

		# warn "debug regex condition: $condition";

		$condition_code = "preg_match('/\\A$condition\\Z/', \$req->path, \$_matches)";

		foreach my $i (0 .. $#condition_vars) {
			my $var = $condition_vars[$i];
			my $index = $i + 1;
			if ($var =~ /\A($identifier_regex)=\[\]\Z/) {
				$var = $1;
				push @match_code, "\$$var = explode('/', \$_matches[$index]);\n";
			} elsif ($var =~ /\A($identifier_regex)=\.\.\.\Z/) {
				$var = $1;
				push @match_code, "\$$var = \$_matches[$index];\n";
			} elsif ($var =~ /\A\.\.\.\Z/) {
				# nothing
			} else {
				push @match_code, "\$$var = \$_matches[$index];\n";
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

	my $first = 1;
	foreach my $action (@actions) {
		push @code, $self->compile_controller_action_call($action, $first);
		$first = 0;
	}
	push @code, "} else {\n", "\treturn parent::action(\$action, \$args);\n", "}\n";

	@code = map "\t$_", @code;
	@code = ("public function action (\$action, array \$args) {\n", @code, "}\n", "\n");

	return @code
}

sub compile_controller_action_call {
	my ($self, $action, $first) = @_;
	my @code;

	if (@{$action->{arguments}}) {
		my $args_var = $self->{context_args_variable};
		foreach my $arg (grep $_->{type} eq 'argument_specifier', @{$action->{arguments}}) {
			push @code, "if (!isset(${args_var}['$arg->{identifier}']))\n";
			push @code, "\tthrow new \\Exception('missing argument \"$arg->{identifier}\" to action \"$action->{identifier}\"');\n";
		}
		push @code, "\n";
		push @code, $self->compile_action_block($action->{arguments});
		push @code, "\n";
	}

	push @code, map "$_\n", map s/\A\t\t?//r, split "\n", $action->{code};

	@code = map "\t$_", @code;
	if ($first) {
		@code = ("if (\$action === '$action->{identifier}') {\n", @code);
	} else {
		@code = ("} elseif (\$action === '$action->{identifier}') {\n", @code);
	}

	return @code
}

sub compile_action_block {
	my ($self, $block) = @_;
	return map $self->compile_action($_), @$block;
}

sub compile_action {
	my ($self, $action) = @_;

	if ($action->{type} eq 'render_template') {
		my $arguments = $self->compile_arguments_array($action->{arguments});
		return "\$res->body = \$this->render_template('$action->{identifier}', $arguments);\n"

	} elsif ($action->{type} eq 'render_file') {
		my $expression = $self->compile_expression($action->{expression});
		return "\$res->body = $expression;\n"

	} elsif ($action->{type} eq 'render_json') {
		my $arguments = $self->compile_arguments_array($action->{arguments});
		return "\$res->body = $arguments;\n"

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

	} elsif ($action->{type} eq 'controller_action') {
		my $arguments = $self->compile_arguments_array($action->{arguments});
		return "\$this->action('$action->{identifier}', $arguments);\n"

	} elsif ($action->{type} eq 'route_controller') {
		my $path_argument = exists $action->{arguments}{path} ? $self->compile_expression($action->{arguments}{path}) : '$path';
		my $args_argument = exists $action->{arguments}{args} ? $self->compile_expression($action->{arguments}{args}) : '$args';
		# my $arguments = $self->compile_arguments_array($action->{arguments});
		return "\$this->route_subcontroller('$action->{identifier}', \$res, $path_argument, $args_argument);\n"

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
					"\tthrow new \\Exception('argument \"$action->{identifier}\" "
							. "exceeded max length of $action->{validator_max_size}');\n"
			}
			if (exists $action->{validator_min_size}) {
				push @code, "if (strlen(\$$action->{identifier}) < $action->{validator_min_size})\n",
					"\tthrow new \\Exception('argument \"$action->{identifier}\" "
							. "doesnt reach min length of $action->{validator_min_size}');\n"
			}
			return @code

		} elsif ($action->{validator_identifier} =~ $model_identifier_regex) {
			my $model_class = $action->{validator_identifier};
			$model_class =~ s/\Amodel::/\\/s;
			$model_class =~ s/::/\\/s;
			return "if (! (\$$action->{identifier} instanceof \\PaleWhite\\Model && \$$action->{identifier} instanceof $model_class))\n",
				"\tthrow new \\Exception('argument \"$action->{identifier}\" not an instance of \"$model_class\" model');\n"

		} elsif ($action->{validator_identifier} eq '_file_upload') {
			return "if (! \$$action->{identifier} instanceof \\PaleWhite\\FileUpload)\n",
				"\tthrow new \\Exception('argument \"$action->{identifier}\" not a file upload');\n"

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
		return "\$_SESSION['$action->{identifier}'] = $expression;\n"

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


sub compile_expression {
	my ($self, $expression) = @_;

	if ($expression->{type} eq 'load_optional_model_expression') {
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "$expression->{identifier}::get_by($arguments)"
		
	} elsif ($expression->{type} eq 'load_model_expression') {
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "\$this->load_model('$expression->{identifier}', $arguments)"
		
	} elsif ($expression->{type} eq 'load_file_expression') {
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "\$this->load_file('$expression->{identifier}', $arguments)"
		
	} elsif ($expression->{type} eq 'load_model_list_expression') {
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "$expression->{identifier}::get_list($arguments)"
		
	} elsif ($expression->{type} eq 'create_model_expression') {
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "$expression->{identifier}::create($arguments)"
		
	} elsif ($expression->{type} eq 'render_template_expression') {
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "((new $expression->{identifier}())->render($arguments))"
		
	} elsif ($expression->{type} eq 'render_file_expression') {
		my $subexpression = $self->compile_expression($expression->{expression});
		return "file_get_contents(${subexpression}->filepath)"

	} elsif ($expression->{type} eq 'controller_action_expression') {
		my $arguments = $self->compile_arguments_array($expression->{arguments});
		return "\$this->action('$expression->{identifier}', $arguments)"

	} elsif ($expression->{type} eq 'string_expression') {
		return "\"$expression->{value}\""
		
	} elsif ($expression->{type} eq 'integer_expression') {
		return "$expression->{value}"
		
	} elsif ($expression->{type} eq 'object_expression') {
		return $self->compile_arguments_array($expression->{value})
		
	} elsif ($expression->{type} eq 'session_variable_expression') {
		return "\$_SESSION['$expression->{identifier}']";

	} elsif ($expression->{type} eq 'variable_expression') {
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		if ($expression->{identifier} eq '_csrf_token') {
			return "\$_SESSION['pale_white_csrf_token']";
		} else {
			return "\$$expression->{identifier}";
		}

	} elsif ($expression->{type} eq 'access_expression') {
		my $sub_expression = $self->compile_expression($expression->{expression});
		# $self->{text_accumulator} .= "' . \$args[\"$expression->{identifier}\"] . '";
		return "$sub_expression->$expression->{identifier}";

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
