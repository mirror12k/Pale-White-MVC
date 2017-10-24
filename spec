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
			list
				queries a list of items based on arguments
				special arguments of _offset, _limit, and _order allow more specific listing
			count
				counts the number of entries matching the given list query

		getter functions for meta array properties
			add
				adds an item to the back of the meta array
			remove
				removes a number/all instances of the item from the meta array
			contains
				whether or not the item exists in the item's meta array
			list_array
				returns a list of items in the model's meta array
				allows special arguments to retrieve only a small portion of the fields
			count_array
				counts the list of items matching the query in a model's meta array

		produce a setup.sql file for the create table statements for this model
		staticly cache model objects by id and other fields to prevent retrieving them multiple times

		on-creation and on deletion hooks:
			on create {{
				error_log("model created!");
			}}
			on delete {{
				error_log("model deleted!");
			}}

		database table delta files:
			# special files dedicated to refractoring the database
			modeldelta MyModel {
				# add a field
				+int hitcount;
				# add a field duplicating values from an existing column
				+string[255] author_bak = author;
				# delete a field
				-int hitcount;

				# resize a field
				*string[255] author_bak -> string[5] author_bak;
				# rename a field
				*string[5] author_bak -> string[5] author_old;

				# create an array field
				+int[] hitcount;
				# create an array field copying values from an existing one
				+int[] double_count = hitcount;
				# delete an array field
				-int[] hitcount;

				# rename an array field
				*int[] double_count -> int[] count_old;
			}
			# compiles into a simple sql file executable on the server

		json fields:
			// simply declare json fields in a model
				model MyModel {
					json data;
				}
			// now arbitrary objects and arrays can be assigned to it, and will be stored in database as a json string
			// accessing these fields again produces the same objects/arrays originally assigned or null by default

		salted password fields:
			// create a model with a salted hashed password field
				model UserModel {
					string[255] username;
					salted_sha256 password;
				}
			// create the model as normal
				user = create UserModel username="admin", password="pass";
			// password is automatically salted and hashed before being stored in the database
			// now it can be compared in controllers:
				if (user.matches_hashed_field("password", my_password)) {
					...
				} else {
					...
				}



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
				a href="https://asdf" alt="my link"

			template args inlined into text
				!template ArgyTemplate
					p "hello there {{username}}!"

			loops
				!foreach users as user
					li "user: {{user.username}}"
			calling sub templates with optional arguments
				!template SuperTemplate
					div.user_container
						!template UserContainerTemplate user=user, color='red'
			inline html
				div.container
					{< html_var >}



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
				// csrf meta token is used by pale-white's ajax action to inject csrf tokens into every request

				// optionally generated serverside
				ajax "/get_csrf_token" {
					render_json token=_csrf_token;
				}

				// validate in arguments
				path "/check_csrf_token" [ !_csrf_token ] {
					// good to go!
				}

				// optionally validate later
				path "/check_later" [ _csrf_token ] {
					validate _csrf_token as _csrf_token;
					// good to go!
				}

			model validation:
				action post_comment [model::ParentBlogModel blog] {
					// good to go!
				}

			ajax paths which return json responses
				// arguments are taken from json data
				ajax "/create/link" [ asdf, zxcv ] {
					validate asdf as qwer;
					// stuff
					// returns a json response
					render_json status="success", data=link_id;
				}

			secure file upload
				// declare a file directory for uploading stuff
				file_directory MemeVideoUploadDirectory '/meme_videos' {
					// properties of file directory
				}

				// use it in an ajax path
				ajax "/do_stuff" [ _file_upload user_file ] {
					// validate the user and arguments
					// validate ...;

					// after validation, we accept the file transfer
					filepath = file MemeVideoUploadDirectory from=user_file;

					// record the file by creating a model referencing it
					video = create VideoModel filepath=filepath;

					render_json status="success";
				}

				// later we can load the file by filepath and specify the content_type
				path "/video/{{video_id}}.webm" {
					video = model VideoModel video_id=video_id;
					header "Content-Type" = "video/webm";
					render_file video.filepath;
				}

				// files are referenced in models by their directories
				model VideoModel {
					file::MemeVideoUploadDirectory filepath;
					model::comment[] comments;
				}

				// files are stored on disk by file hash and with no extention to forbid any extention-based execution

			filedirectory timestamp suffixing
				// simply add a 'suffix_timestamp' property to the file directory declaration
				file_directory VideoUploadsDirectory "./uploads" {
					suffix_timestamp;
				}


			calling static and dynamic functions in controllers
				// method calling:
					my_model.func("asdf");
				// static model calling:
					model::MyModel.func("asdf");

			native code libraries for inclusion and usage in controllers and models
				// declare library in a controller for sanity and includes:
					native_library MyApp::MyLibrary => "lib/MyApp.php";

				// call libraries by referering to their classname:
					native::MyApp::MyLibrary.func("hello world");



			data logging
				// log strings with the log action:
					path global {
						log "got request {{path}}";
					}
				// specify an extra logging file in the config file
					"log_file" => "/var/pale/data.log",
				// fatal exceptions are automatically logged by HTTPRequestExecutor


			simple maintenance mode enabled from the config file
				// enabled from config.php
					'maintenance_mode' => true/false,
				// option to set controller launched durning maintenance mode:
					'maintenance_mode_controller' => '\\PaleWhite\\DefaultMaintenanceController',


			callback event scheduling
				// a model is injected during compile time into projects
					model _EventModel {
						int trigger_time;
						string[512] controller;
						string[512] event;
						string args;
					}
				// declare event callbacks in controllers:
					event say_hello {
						log "saying hello!";
					}
				// schedule events from controllers:
					path "/" {
						schedule_event EventController.say_hello offset=3600, args={
							a = 15,
							b = 25,
						};
					}
				// offset specifies the time in seconds relative to when it was scheduled to trigger the event
				// args is a simple object of string/integer values which will be encoded as json
					// compiles to:
						$this->schedule_event('EventController', 'say_hello', array('offset' => 3600, 'args' => array(...)));

				// a config option enables event processing:
					'enable_events' => true,
				// the HTTPRequestExecutor selects events to process after it is done with a normal request
				// if an event dies during processing, it wont be processed again
				// events are processed as soon as a page is loaded,
				// so a website without traffic will find it difficult to load events on time

			native system command calling
				// safely escapes arguments
				// logs invoked commands and return values
				// packages return code and output text in neat object

				// this provides the potential for very heavy algorithmic or computational work to be
				// done by server-side scripts/programs, such as packaging/unpackaging archives,
				// compiling files, and long-crawling outside data
				ajax "/echo/{{message}}" {
					ret = shell_execute "echo", "your message: ", message;
					if (ret.return_value == 0) {
						render_json status="success", data=ret.output;
					} else {
						render_json status="error", data=ret.return_value;
					}
				}
				// notice: executing arbitrary commands is still dangerous
				// recommended practice is calling secure perl/python scripts with arguments,
				// and employing safe practices in those scripts as well




	client-side js
		javascript-less ajax requests
			// implemented using html forms with a class of .ajax_trigger
				form.ajax_trigger action="/my_ajax_action"
					input type="hidden" value="some_action"
					button "submit"
			// this will trigger an ajax request to "/my_ajax_action" (with csrf security)

		angular-style dom replacement in ajax
			// specifying a "dom_content" field in a status="success" ajax response
					// will trigger replacement of specified dom selectors with new content
				render_json status="succeess", dom_content={
					"div.title" = "hello world!",
					"div.my_content" = render MyContentTemplate,
				}

		javascript syntactic sugar for declaring hooks
			body => on load
				// do javascript stuff
			div.tag => on click
				this.hide();

		javascript on load hooks
			on load
				console.log("loaded!");

		have javascript hooks reapplied to any imported html
			// this is done automatically to any new content imported with dom_content
			// can also be done manually from javascript:
				pale_white.add_hooks(my_node);

	localization files which tie to glass templates
		// first set a localization in a controller
			set_localization 'en';
		// this sets a global setting variable for which localization will be selected from a list of them
		// write a localization file "my_localization.local"
			localization my_page:en {
				title = "Hello"
				world = "World"
			}
		// then they can be referenced in templates:
			div.title
				@my_page/title
			div.content
				@my_page/world
		// or can be referenced in controllers:
			path error {
				render ErrorTemplate error=@my_page/error;
			}

		// localization compiles to a php class:
			namespace \Localization\en;
			class my_page {
				public static $title = "Hello";
				public static $world = "World";
			}

		// expressed as:
			$this->get_localization('my_page', 'title');
		// which will test the current runtime localization setting
			$class = "\\Localization\\$current_localization\\$localization_namespace";
			return $class::$$field;


glass templates in javascript
	// api:
		PaleWhite = {
			get_class: function (class_name) {
				var class_parts = class_name.split('::');
				var class_obj = window[class_parts[0]];
				for (int i = 1; i < class_parts.length; i++) {
					class_obj = class_obj[class_parts[i]];
				}
				return class_obj;
			},
			get_template: function (template_class) {
				var class_obj = this.get_class(template_class);
				if (!(class_obj.prototype instanceof PaleWhite.Glass.Template))
					throw new PaleWhite.InvalidException("attempt to get non-template class");
		
				return new class_obj(this);
			},
		};

		// exceptions:
		PaleWhite.PaleWhiteException = function (message) {
			this.message = "[PaleWhite]: " + message;
			this.stack = (new Error()).stack;
		}
		PaleWhite.PaleWhiteException.prototype = Object.create(Error, {});

		PaleWhite.InvalidException = function (message) {
			this.message = message;
			this.stack = (new Error()).stack;
		}
		PaleWhite.InvalidException.prototype = Object.create(Error, {});

		PaleWhite.ValidationException = function (message) {
			this.message = message;
			this.stack = (new Error()).stack;
		}
		PaleWhite.ValidationException.prototype = Object.create(Error, {});

		// base template:
		PaleWhite.Glass.Template = function () {};
		PaleWhite.Glass.Template.prototype = {
			render: function (args) {
				return '';
			},
			render_block: function (block, args) {
				return '';
			},
			htmlspecialchars: function (text) {
				var map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
				return text.replace(/[&<>"'"]/g, function(m) { return map[m]; });
			},
		};

	// reference
		!template AsdfTemplate
			div "test"
	// compiles to:
		function AsdfTemplate() {}
		AsdfTemplate.prototype = Object.create(PaleWhite.Glass.Template, {
			render: function (args) {
				var text = PaleWhite.Glass.Template.render.call(this, args);
				text += "<div>test</div>";
				return text;
			},
		});

	// reference 2
		!template AsdfTemplate
			div "content"
				!block content
	// compiles to:
		function AsdfTemplate() {}
		AsdfTemplate.prototype = Object.create(PaleWhite.Glass.Template, {
			render: function (args) {
				var text = PaleWhite.Glass.Template.render.call(this, args);
				text += "<div class='content'>";
				text += this.render_block('content', args);
				text += "</div>";
				return text;
			},
		});

	// reference 3
		!template AsdfTemplate extends BaseTemplate
			!block content
				p "hello!"
	// compiles to:
		function AsdfTemplate() {}
		AsdfTemplate.prototype = Object.create(BaseTemplate, {
			render_block: function (block, args) {
				var text = BaseTemplate.render_block.call(this, block, args);
				if (block === 'content') {
					text += "<p>hello!</p>";
				}
				return text;
			},
		});

	// reference 4
		!template AsdfTemplate
			div "content"
				!if value
					p {value}
	// compiles to:
		function AsdfTemplate() {}
		AsdfTemplate.prototype = Object.create(PaleWhite.Glass.Template, {
			render: function (args) {
				var text = PaleWhite.Glass.Template.render.call(this, args);
				text += "<div class='content'>";
				if (args.value) {
					text += "<p>";
					text += this.htmlspecialchars(args.value);
					text += "</p>";
				}
				text += "</div>";
				return text;
			},
		});

	// reference 5
		!template AsdfTemplate
			div "content"
				!foreach values_list as key => value
					p "{{key}} = {{value}}"
	// compiles to:
		function AsdfTemplate() {}
		AsdfTemplate.prototype = Object.create(PaleWhite.Glass.Template, {
			render: function (args) {
				var text = PaleWhite.Glass.Template.render.call(this, args);
				text += "<div class='content'>";
				Object.keys(values_list).forEach(function(key) {
					value = values_list[key];
					text += "<p>";
					text += this.htmlspecialchars(key);
					text += " = ";
					text += this.htmlspecialchars(value);
					text += "</p>";
				});
				text += "</div>";
				return text;
			},
		});

model views for animation by javascript
	// call model views in glass templates
		!model_view PostModelTemplate={my_post}
	// compiles to:
		!render PostModelTemplate model=my_post

	// ModelTemplates are declared just like templates and are interchangable with them
	// only difference is the presense of an argument list
	// any data object fitting these argument requirements is allowed to render
		!model_template PostModelTemplate model={string author, string text}
			div.my-class
				div.title {model.author}
				div.text {model.text}
	// compiles to:
		div.my-class.pw-model-template "data-model-template"="PostModelTemplate" "data-model-data"={PostModelTemplate.encode_data(my_post)}
			div.title {model.author}
			div.text {model.text}

	// model templates are hooked by the pale-white js and have properties and functions injected
		var my_mt = $('.my-class')[0];
		// retrieving data model in this template:
		console.log("my data model: ", my_mt.pw_model);
		// editting data model properties: (this will re-render the model template)
		my_mt.pw_model.text = "???";
		// replacing data model: (this will re-render the model template)
		my_mt.pw_model = {author: 'anon', text: 'lel'};

	// model views editting their own values?

