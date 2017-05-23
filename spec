<?php

templated and pre-compiled mvc
	model templates which describe the sql database structure and a Model oject
		model UserLink {
			int id auto;
			string[512] link;

			getter link {{
				// does php to retrieve the link after it has been retrieved from the database as $_
			}}

			setter link {{
			}}

			getter my_virtual_property {{
			}}

			function my_special_method () {{
			}}

			static function my_static_method () {{
			}}

			cast link to string {{
				// transform a link to a string suitable for the database
			}}
			cast link from string {{
				// transform a link to a version suitable for use
			}}
		}

		this will automatically produce a php class for UserLinkModel with appropriate database insertion, selection, and updating procedures
			retrieval is performed on get_by methods and all model data is stored in a _data property
		the class will have __get and __set functions setup to allow magic requesting of any of these fields
		the class can also have automatic casting performed of the type to render it before and after the dataase
		get_by_id and other get_by functions will be setup as appropriate
			__get
			__set
			get_by_id
				retrieval by id
			get_by
				allows retrieval by field(s)
			create
				creates a new object and loads it from
			create_many
				simply an array loop of create
			list
				queries a list of items based on arguments
			cast_field_to_string
			cast_field_from_string
			flush_cache
				flushes all cached objects
		staticly cache model objects by id and other fields to prevent retrieving them multiple times
		this will also produce a setup.sql file for the create table statement for this model

		further wishlist:
			meta arrays and meta objects for models



	glass templates
		modeled on jade, designed to pre-compile to a php template object
		easy to use, just pass in an array of args, and html text is returned

		examples:
				#template Base
					html
						body
							#block body


			compiles to

				class BaseTemplate extends \Glass\Template {
					public function render (array $args) {
						$text = "";

						$text .= "<html><body>";
						$text .= $this->render_block('body', $args);
						$text .= "</body></html>";

						return $text;
					}

					public function render_block (string $block, array $args) {
						$text = $this->parent::render_block($block, $args);
						return $text;
					}
				}

			also

				#template Page extends Base
					#block body
						p hello world!

			complies to

				class PageTemplate extends BaseTemplate {
					public function render_block (string $block, array $args) {
						$text = $this->parent::render_block($block, $args);

						if ($block === 'body') {
							$text .= "<p>hello world!</p>";
						}

						return $text;
					}
				}

		wishlist
			extensible helper plugins
			optional compilation to a big javascript package to allow client-side sites

	controllers
		compile directly to php classes, they define paths, rewrite rules, and path arguments
			controller Main {
				// this is a normal GET path
				path '/' {
					render PageTemplate
				}
				// this is a normal GET path which takes an argument from the path
				path '/key/{{path_argument}}' {
					validate path_argument as key
					render ArgyTemplate path=path_argument
				}
				// this is a POST path which requires a 'link' argument
				path '/create' [ 'link_string' ] {
					validate link_string as link
					link_id = action new_link link=link_string
					if (link_id) {
						redirect '/link/{{link_id}}'
					} else {
						render ErrorTemplate error='failed to create link', message='please go back and try again'
					}
				}

				// default path
				path default {
					status '404 Not Found'
					render ErrorTemplate error='404 Not Found'
				}

				// this is an action callable by the paths
				action new_link () {{
					// new_link code
					// returns the created link id
				}}

				// a php code validator which throws an error if data is incorrect
				validator key {{
					$key = (string)$_;
					if ($key === '')
						throw new \Exception('invalid key');
					return $key;
				}}

				// a fast validator using regex
				validator link =~ /\Ahttps?:\/\//
			}

		compiles:
			class MainController extends \Controller {
				// this is a normal GET path

				public function route ($path, $args) {
					if ($path === '/') {
						echo new PageTemplate()->render(array());
					} elseif ($path ... matches '/key/(.*)') {
						$match = $path ... matches '/key/(.*)';
						$path_argument = $match[1];
						$path_argument = $this->validate('key', $path_argument);
						echo new ArgyTemplate()->render(array('path' => $path_argument));
					} elseif ($path === '/create' && isset($args['link_string'])) {
						$link_string = $args['link_string'];
						$link_string = $this->validate('link', $link_string);
						$link_id = $this->action('new_link', array('link' => $link_string));
						if ($link_id) {
							$this->redirect("/link/${link_id}");
						} else {
							echo new ErrorTemplate()->render(array('error' => 'failed to create link', message => 'please go back and try again'));
						}
					} else {
						$this->set_status('404 Not Found');
						echo new ErrorTemplate()->render(array('error' => '404 Not Found'));
					}
				}

				public function action ($action, $args) {
					if ($action === 'new_link') {
						// do stuff
					} else {
						// Controller::action will simply throw an error about invalid methods
						return $this->parent::action($action, $args);
					}
				}

				public function validate ($type, $_) {
					if ($type === 'key') {
						$key = (string)$_;
						if ($key === '')
							throw new \Exception("invalid key: $key");
						return $key;
					} elseif ($type === 'link') {
						if ($_ .... matches /\Ahttps?:\/\//)
							return $_;
						else
							throw new \Exception("invalid link: $_");
					} else {
						return $this->parent::validate($type, $_);
					}
				} 
			}


		wishlist:
			ajax paths which return json responses
			user session and permission validation
			sugar syntax for loading objects as models
			websockets/ajax client-heavy site
				load all glass templates as client-side javascript files
				and have all actions exposed via websockets or ajax
				have controllers mostly loaded on client-side
			library inclusion
			transplant comments directly to compiled php code
			a cli to perform server-side action easier?
