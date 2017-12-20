# Pale-White MVC Framework
Pale-White is a model-view-controller framework designed to simplify design by abstracting away from php/sql/html.
PaleWhite models and controllers are compiled to standard php classes to provide ease of support and debugging.
A database abstraction layer allows full use of database-backed models without writing any database queries,
and provides security against injection attacks like SQLi.
A templating language based on Jade provides fast and extensible front-end development.
More goodies are provided along the way.

## Requirements
requires perl Sugar library for compiling models/views/controllers.
also requires perl Make::SSH library to compile the example project.make's.

## Why?
Standard php-mysql backend development tends to get bogged down quickly with security and conformity.
Implementing template views, client-side templates, secure logins, file uploads, localization, and plugin apis,
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
The framework provides seamless support for plugins to come in and interface with your logic,
as well as serving the role of drag-and-drop logic components.

## Examples/Tutorials
See [hello world](hello_world.md) for an introduction to the framework.
See [features](features.md) for examples on how to use the framework features.
