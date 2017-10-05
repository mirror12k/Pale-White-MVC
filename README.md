# Pale-White MVC Framework
Pale-White is a model-view-controller framework designed to simplify design by abstracting away from php/sql/html.
PaleWhite models and controllers are compiled to standard php classes to provide easy of support and debugging.
A database abstraction layer allows full use of database-backed models without writing any database queries,
and provides security against injection attacks like SQLi.
A templating language based on Jade provides fast and extensible front-end development.
More goodies are provided along the way.

## Requirements
requires perl Sugar library for compiling models/views/controllers.
also requires perl Make::SSH library to compile the example project.make's.

## Why?
Standard php-mysql backend development tends to get bogged down quickly with security and conformity.
Implementing template views, secure logins, file uploads, localization, and plugin apis,
are always necessary when a project grows large enough.
Pale-White provides tools to simplify these jobs and prevent reinventing the wheel.

The framework also tries to stay away from any language-dependent specifics to allow
targeted compilation to any standard language/database combination.

## Security in Mind
The framework comes with numerous tools to secure your backend from error.
- XSS Protection - Glass templates provide XSS protection to all inputs inlined in your html.
- CSRF Tokens - An easy api for CSRF tokens is provided to validate all input.
- Ajax CSRF - All ajax is forcefully validated with CSRF to prevent any accidents.
- Secure File Uploads - File uploads are easy and secure with file directories;
no file extensions are allowed, and filenames are secure hashes.
- Database Injection - Models implement strict security in their values to prevent any database injection attacks.
Additionally a database-api layer is provided so that extensions and plugins can provide the same safety from attacks.
- Password Hashing - Secure password hashing is easy and simple with support from the framework.
- Input Validation - Tons of tools are provided to controllers to strictly validate input coming in from users and other server-side components.

## Extensibility Built-In
Seeing how critical extensible plugins are to the Wordpress, phpBB, and other communities,
it is crucial that every pale-white application come ready with a plugin api.
The framework provides seemless support for plugins to come in and interface with your logic,
as well as serving the role of drag-and-drop logic components.

## Writing Your First Controller
Controllers are simple to write, yet easy to expand on later:
```
controller MainController {
	path "/" {
		render HelloWorldTemplate;
	}
}
```
This controller will render a HelloWorldTemplate when the user visits the root site directory.
Now lets define that template in Glass.

## Writing Your First Template
Templates are written in Glass, a jade-based language tailored to html templating:
```
!template HelloWorldTemplate
	html
		head
			title "Hello World!"
		body
			h1 "Welcome to my site."
			p "Hello world!"
```

We can also create a base template to simplify future templates:
```
!template BaseTemplate
	html
		head
			!block head
		body
			!block body


!template HelloWorldTemplate extends BaseTemplate
	!block head
		title "Hello World!"
	!block body
		h1 "Welcome to my site."
		p "Hello world!"
```

We can pass data from controllers to templates by specifying arguments to it:
```
controller MainController {
	path "/test" {
		render ArgsTemplate arg1="Hello", arg2="World";
	}
}
```
Then we can utilize these values in our template:
```
!template HelloWorldTemplate extends BaseTemplate
	!block body
		h1 "Welcome to my site."
		p "{{arg1}} {{arg2}}!"
```
Now lets give it some user-interaction using models.

## Writing Your First Model
Models are written in a basic flatbuffers-like syntax:
```
model MessageModel {
	# variable length string up to 255 characters
	string[255] author;
	# arbitrary length long string
	string message;
}
```
Models are useless without logic to create and show them:
```
controller MainController {
	path "/create_message" ( !_csrf_token, string[1:255] author, string message ) {
		create MessageModel author=author, message=message;

		# redirect back to home on successfully creating the message
		status "302 Redirect";
		redirect "/";
	}
}
```
Now we need to display a page with the form:
```
controller MainController {
	path "/" {
		render MainPageViewTemplate;
	}

	# ...
}
```
And a template to show the form:
```
!template MainPageViewTemplate extends BaseTemplate
	!body
		h1 "post your message:"
		form method="POST" action="/create_message"
			!_csrf_token_input
			input type="text" name="author" placeholder="author"
			input type="text" name="message" placeholder="message"
			button "post message!"
```

And finally, we need to display these messages on the main page:
```
controller MainController {
	path "/" {
		messages_list = list MessageModel;
		render MainPageViewTemplate messages_list=messages_list;
	}
	# ...
}
```

```
!template MainPageViewTemplate extends BaseTemplate
	!body
		!foreach messages_list as message_model
			h1 "{{message_model.author}} wrote:"
			p {message_model.message}
		h1 "post your message:"
		form method="POST" action="/create_message"
			!_csrf_token_input
			input type="text" name="author" placeholder="author"
			input type="text" name="message" placeholder="message"
			button "post message!"
```



