# Pale-White Framework Hello World
This is a basic tutorial on how to write your first hello world website in Pale-White.

## Writing Your First Controller
Controllers are simple to write, yet easy to expand on later:

**controllers.white**:
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

**templates.glass**:
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

**templates.glass**:
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

**controllers.white**:
```
controller MainController {
	path "/test" {
		render ArgsTemplate arg1="Hello", arg2="World";
	}
}
```
Then we can utilize these values in our template:

**templates.glass**:
```
!template HelloWorldTemplate extends BaseTemplate
	!block body
		h1 "Welcome to my site."
		p "{{arg1}} {{arg2}}!"
```
Now lets give it some user-interaction using models.

## Writing Your First Model
Models are written in a basic flatbuffers-like syntax:

**models.white**:
```
model MessageModel {
	# variable length string up to 255 characters
	string[255] author;
	# arbitrary length long string
	string message;
}
```
Models are useless without logic to create and show them:

**controllers.white**:
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

**controllers.white**:
```
controller MainController {
	path "/" {
		render MainPageViewTemplate;
	}

	# ...
}
```
And a template to show the form:

**templates.glass**:
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

**controllers.white**:
```
controller MainController {
	path "/" {
		messages_list = list MessageModel;
		render MainPageViewTemplate messages_list=messages_list;
	}
	# ...
}
```

**templates.glass**:
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
