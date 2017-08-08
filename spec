<?php

templated and pre-compiled mvc
	model templates which describe the sql database structure and a Model oject
		model UserLink {
			auto_id id;
			link_type link;

			cast link_type to string[512] {{
				// transform a link to a string suitable for the database
			}}
			cast link_type from string[512] {{
				// transform a link to a version suitable for use
			}}

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

		on-creation and on deletion hooks:
			on create {{
				error_log("model created!");
			}}
			on delete {{
				error_log("model deleted!");
			}}

		further wishlist:
			meta arrays and meta objects for models
			an admin backend for viewing/editting models as listed items
			salted+hashed password field for easy comparison



	glass templates
		modeled on jade, designed to pre-compile to a php template object
		easy to use, just pass in an array of args, and html text is returned

		examples:
				!template Base
					html
						body
							!block body


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

				!template Page extends Base
					!block body
						p "hello world!"

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

		done:
			tag classes and ids
				div.container#main_container

			tag properties
				a href="https://asdf", alt="my link"

			template args inlined into text
				!template ArgyTemplate
					p "hello there {{username}}!"

			loops
				!foreach users as user
					li "user: {{user.username}}"

		wishlist
			inline html
				div.container
					{< html_var >}
			calling sub templates with optional arguments
				!template SuperTemplate
					div.user_container
						!template UserContainerTemplate user=user, color='red'

			passing templates as arguments and values
				!template SuperTemplate
					div.super_container
						// invoke template from variable
						!template $dynamic_template
						// pass the name of a template
						!template RenderContainerTemplate template="UserContainerTemplate"

			anonymous template definitions
				!template SuperTemplate
					// include the template here,
					!template RenderContainerTemplate
						// render blocks INSIDE the included template
						!block border
							{my_awesome_border}
						!block container
							!template UserContainerTemplate

			simpler div containers
				!template NestedDivsTemplate
					#main_container
						.container

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
				path '/create' [ link_string, username ] {
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

		done:
			argument list paths which match multiple words seperated by slashes
				// this will match paths like '/search/asdf/qwer/zxcv' and produce an array of terms ['asdf', 'qwer', 'zxcv']
				path '/search/{{terms=[]}}' {}

			global paths to act like middleware
				path global {
					// perform user authentication
				}

			user session and permission validation
				// try to find a user by given user_id
				current_user = model? UserModel id=user_id
				if (current_user) {
					// if it is a valid user, we can set the session to his id
					session.current_user = user.id;
					render MessageTemplate message="logged in";
				} else {
					// otherwise report an error
					render MessageTemplate message="no such user found";
				}

				// after login, can always access the user by session
				current_user = model? UserModel id=session.current_user

			sugar syntax for loading objects as models
				// call UserLinkModel->get_by(array('id' => $link))
				link = model UserLinkModel id=link;
				// call UserLinkModel->get_by(array('link' => $link_string))
				link = model UserLinkModel link=link_string;
				// call UserLinkModel->list(array('page' => $page))
				links = list UserLinkModel page=page;

			dispatch another controller
				path '/special/.*' {
					// launches AnotherController->route($path, $args)
					route AnotherController;
				}
		
			an automatically generated index.php file generated to include all pacakges and start the controller



			csrf tokens
				// set in glass compilers:
				form
					!_csrf_token_input
				// equivalent to
				form
					input name="_csrf_token", type="hidden", value={_csrf_token}

				// alternatively add a meta tag in the head for javascript to use:
				head
					!_csrf_token_meta
				// equivalent to
				head
					meta id="_csrf_token", name="_csrf_token", content={_csrf_token}

				// optionally generated serverside
				ajax '/get_csrf_token' {
					return token=_csrf_token
				}

				// validate in arguments
				path '/check_csrf_token' [ !_csrf_token ] {
					// good to go!
				}

				// optionally validate later
				path '/check_later' [ _csrf_token ] {
					validate _csrf_token as _csrf_token;
					// good to go!
				}

			model validation:
				action post_comment [model::ParentBlogModel blog] {
					// good to go!
				}

		wishlist:
			regex path arguments
				path '/page/{{page=/\d+/}}' {}

			ajax paths which return json responses
				// arguments are taken from json data
				ajax '/create/link' [ asdf, zxcv ] {
					validate asdf as qwer with zxcv=zxcv
					// stuff
					// returns a json response
					return status='success', data=link_id
				}

			secure file upload
				// declare a file directory for uploading stuff
				file_upload_directory meme_videos => '/meme_videos' {
					// can validate user permissions before accepting the file
				}

				// use it in an ajax path
				ajax '/do_stuff' [ file::meme_videos file ] {
					// validate the user and arguments
					validate ...;

					// after validation, we accept the file transfer
					filepath = accept_file_upload file;

					// record the file somehow by creating a model out of it or something
					return status="success"
				}

				// later we can load the file by filepath and specify the content_type
				path "/video/{{video_id}}.webm" {
					video = model VideoModel video_id=video_id;
					content_type "video/webm";
					render_file video.filepath;
				}

				// models can tie files to themselves so that the file is deleted when the model is deleted
				// by simply creating the VideoModel with this file argument, it is tied to the file
				model VideoModel {
					file::meme_videos filepath;
					model::comment[] comments;
				}

				files are stored on disk by file hash and with no extention to forbid any extention-based execution

			log file recording all exceptions occuring in the application

			websockets/ajax client-heavy site
				load all glass templates as client-side javascript files
				and have all actions exposed via websockets or ajax
				have controllers mostly loaded on client-side
				hook location switches and have a client-side controller process to perform a simple server request
					server picks the template and template args for it, as well as performing any controller actions required
					server returns a json response which tells client-side which template with which arguments to load
				templates should be optionally markable as client-side only using cached model data to avoid excessive server-side requests
					this would require client-side controllers fully implementing the template and model picking logic for those paths
					can mark these paths as static so that they are compiled into the client-side controller
			library inclusion
			transplant comments directly to compiled php code
			a cli to perform server-side action easier?
			automatic admin backend for viewing and editting modeled objects?
			a description package which outlines all contained packages?
			view controllers to easily assign logic to specific views?

			a testing suite which is done from server-side cli php execution
				doesnt render templates fully, just returns the template names and arguments passed as the test status
				this way controller logic can be checked without depending on templating output

