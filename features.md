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



