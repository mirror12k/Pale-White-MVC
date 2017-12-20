# Pale-White Framework Features
Pale-White supports numerous features for ease of production, heres a sampling of some of them:

## Localization
Localization is easy by writing localization files and embedding scoped strings:

**localization.white**:
```
localization MyText:en {
	title = "Hello"
	world = "World"
}
```
This creates a localization scope under the *en* group.
Now we can refer to these strings in a template:

**localized_template.glass**
```
!template TextTemplate extends BaseTemplate
	!block body
		h1 @MyText/title
		p
			@MyText/world
			"!"
```

*Notice*: the localization setting must be set either in the config file or in a controller with `set_localization "en";`.

## Secure File Uploads
Controllers provide the ability to securely receive file uploads and models can store these files in an easy to use manner.
First we declare a file directory to store the files:

**controllers.white**
```
file_directory DataFilesDirectory "./my_files" {
	suffix_timestamp;
}
```

Next we create a controller endpoint to receive the a file upload and store it in our directory:

**controllers.white**
```
...
	ajax "/my_endpoint" (_file_upload new_file) {
		# verify file size
		if (new_file.file_size < 1024) {
			render_json status="error", error="file too small";
			return;
		}
		if (new_file.file_size > 4096) {
			render_json status="error", error="file too large";
			return;
		}

		# verify file mime-type
		if (new_file.mime_type != 'image/jpeg') {
			render_json status="error", error="expected jpg file";
			return;
		}

		# accept the file upload to the DataFilesDirectory directory
		my_file = file DataFilesDirectory accept_upload=new_file;

		...
	}
...
```

We can create a model with a file pointer property:
**models.white**
```
model MyModel {
	file::DataFilesDirectory my_file;
}
```

And now we can store the file reference in endpoint code:
**controllers.white**
```
		...
		# accept the file upload to the DataFilesDirectory directory
		my_file = file DataFilesDirectory accept_upload=new_file;

		my_model = create MyModel my_file=my_file;

		render_json status="success";
	}
```

Finally, we can load the file and send it to the user from a path:
**controllers.white**
```
...
	path "/my_model/{{id}}" {
		# load the model
		my_model = model MyModel id=id;

		# send the file as a response
		render_file my_model.my_file;
	}
...
```

## Dynamic Model Templates
Templates can be declared as Model Templates which keep their arguments with them and can easily be rerendered from javascript

**templates.glass**
```
# we declare a model template for posts with it's arguments
!model_template PostModelTemplate (author, text)
	div.post
		div.title {model.author}
		div.text {model.text}

# next we use this render this template in a page
!template MainPageTemplate extends BaseTemplate
	!block body
		!render PostModelTemplate model={author="admin", text="test"} id="my-model"
```

This template file will need to be specially compiled to javascript with the `PaleWhite/Glass/JSCompiler.pm` and loaded on the page as javascript.

**app.js**
```javascript
// finally we can access this model data in our template
console.log("my post author: ", $('#my-model')[0].pw_model.author);

// as well as modifying it
$('#my-model')[0].pw_model.author = "ADMIN";
// this will automagically re-render the model with the new data

// alternatively, we can set the the whole model object to new data, and rerender it with the new content
$('#my-model')[0].pw_model = { author: "anon", text: "hijack" };
```

## Model Template Lists
Extending the Model Templates mentioned above, you can create a list node for easily adding/removing new model template entries to the dom:
**templates.glass**
```
!template MainPageTemplate extends BaseTemplate
	!block body
		# we have a node with the pw-model-template-list class to let PaleWhite know that we want a list here
		div.pw-model-template-list#my-list "data-model-template"="PostModelTemplate"

```

Now we can add/remove models to this list in js:

**app.js**
```javascript
// we can append a new model to the list
$('#my-list')[0].pw_model_list.append_model({author: "user", text: "first"});

// we can modify the elements of a model template list as we did before
$('#my-list')[0].children[0].pw_model.text = "hello world!";

// we can remove models from the list by index
$('#my-list')[0].pw_model_list.remove_model(0);

// we can reassign the whole list of items directly:
$('#my-list')[0].pw_model_list = [
	{ author: "a", text: "first"},
	{ author: "b", text: "second"},
	{ author: "c", text: "third"},
];
```

## Secure Password Hashes
Securely storing and verifying passwords is easier than ever.

We start by declaring a user model with a salted_sha256 password:
**models.white**
```
model UserModel {
	string[255] username unique;
	salted_sha256 password;
}
```

Next we can assign the password property as any other string property,
and it will be securely salted and hashed before being saved in the database.
**controllers.white**
```
...
	action create_user (string[1:255] username, string[1:255] password) {
		# password is passed in plaintext
		user_model = create UserModel username=username, password=password;
		# password is automatically hashed on storage
		return user_model;
	}
...
```

Now we need to be able to compare this password value:
**controllers.white**
```
...
	action validate_login (string[1:255] username, string[1:255] password) {
		user_model = model? UserModel username=username;
		# ensure there is a user model with this username
		if (!user_model) {
			# if the user is not found, return null
			return;
		}

		# check that the password hash matches
		if (!user_model.matches_hashed_field("password", password)) {
			# if the password hash doesnt match, return null
			return;
		}

		# if every check passed, return the user model
		return user_model;
	}
```
