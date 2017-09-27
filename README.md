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
Glass templates provide XSS protection to all inputs inlined in your html.
An easy api for CSRF tokens is provided to validate all input.
All ajax is forcefully validated with CSRF to prevent any accidents.
File uploads are easy and secure with file directories;
no file extensions are allowed, and filenames are secure hashes.
Models implement strict security in their values to prevent any database injection attacks.
Additionally a database-api layer is provided so that extensions and plugins can provide the same safety from attacks.
Secure password hashing is easy and simple with support from the framework.
Tons of tools are provided to controllers to validate input coming in from users and other server-side components.

## Extensibility Built-In
Seeing how critical extensible plugins are to the Wordpress, phpBB, and other communities,
it is crucial that every pale-white application come ready with a plugin api.
The framework provides seemless support for plugins to come in and interface with your logic,
as well as serving the role of drag-and-drop logic components.

## Writing Your First Controller
Controllers are simple to write, yet easy to expand on later:
'''
controller MainController {
	path "/" {
		render HelloWorldTemplate;
	}
}
'''
This controller will render a HelloWorldTemplate when the user visits the root site directory.
Now lets define that template in Glass.
'''
!template HelloWorldTemplate
	html
		head
			title "Hello World!"
		body
			h1 "Welcome to my site."
			p "Hello world!"
'''
We can also create a base template to simplify future templates:
'''
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
'''
We can pass data from controllers to templates by specifying arguments to it:
'''
controller MainController {
	path "/test" {
		render ArgsTemplate arg1="Hello", arg2="World";
	}
}
'''
Then we can utilize these values in our template:
'''
!template HelloWorldTemplate extends BaseTemplate
	!block body
		h1 "Welcome to my site."
		p "{{arg1}} {{arg2}}!"
'''

