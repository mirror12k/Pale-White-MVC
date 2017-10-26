
PaleWhite = {
	registered_hooks: [],
	registered_scroll_hooks: [],

	get_class: function (class_name) {
		var class_parts = class_name.split('::');
		var class_obj = window[class_parts[0]];
		for (var i = 1; i < class_parts.length; i++) {
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

	onload: function () {
		this.add_hooks(document.body);
		window.addEventListener('scroll', function (event) { PaleWhite.onscroll(event); });
		this.onscroll(undefined);
	},
	onscroll: function (event) {
		// console.log('scrolled to ', window.scrollY, window.scrollY + window.innerHeight);
		this.registered_scroll_hooks.forEach(function (hook) {
			var nodes = document.querySelectorAll(hook.selector);
			for (var i = 0; i < nodes.length; i++) {
				var node = nodes[i];
				var y_min = node.offsetTop;
				var y_max = node.offsetTop + node.offsetHeight;

				if (window.scrollY + window.innerHeight >= y_min && window.scrollY < y_max) {
					// console.log('scrolled to item ', hook.selector);
					hook.callback.call(node, event);
				}
			}
		});
	},
	add_hooks: function (dom) {
		this.registered_hooks.forEach(function (hook) {
			var nodes = dom.querySelectorAll(hook.selector);
			for (var i = 0; i < nodes.length; i++) {
				if (hook.event === 'load')
					hook.callback.call(nodes[i]);
				else
					nodes[i].addEventListener(hook.event, hook.callback);
			}
		});
	},
	register_hook: function (selector, event, callback) {
		if (event === 'scroll') {
			this.registered_scroll_hooks.push({
				selector: selector,
				callback: callback,
			});
		} else {
			this.registered_hooks.push({
				selector: selector,
				event: event,
				callback: callback,
			});
		}
	},
	get_csrf_token: function () {
		var token = document.head.querySelector("meta#_csrf_token");

		if (token === undefined)
			throw "csrf token meta-tag required on the page!";

		return token.getAttribute("content");
	},
	get_site_base: function () {
		var token = document.head.querySelector("meta#_site_base");

		if (token === undefined)
			throw "site base meta-tag required on the page!";

		return token.getAttribute("content");
	},
	ajax: function (url, args, callback) {
		url = this.get_site_base() + url;

		var xhr = new XMLHttpRequest();
		xhr.open("POST", url, true);
		xhr.setRequestHeader("X-Requested-With", "pale_white/ajax");
		xhr.addEventListener('readystatechange', function () {
			if (xhr.readyState == 4) {
				var response;
				if (xhr.response === "") {
					console.log("[PaleWhite] empty response!");
					response = {};
				} else {
					response = JSON.parse(xhr.response);
				}
				PaleWhite.on_ajax_response(response);

				if (callback)
					callback(response);
			}
		});
		
		if (args instanceof FormData) {
			// xhr.setRequestHeader("Content-Type", "multipart/form-data");
			args.append("_csrf_token", PaleWhite.get_csrf_token());
			xhr.send(args);

		} else {
			xhr.setRequestHeader("Content-Type", "application/json");
			args._csrf_token = PaleWhite.get_csrf_token();
			xhr.send(JSON.stringify(args));
		}
	},
	on_ajax_response: function (data) {
		console.log("[PaleWhite] got response: ", data);

		if (data.status === 'success') {
			if (data.dom_content !== undefined) {
				PaleWhite.substitute_dom_content(data.dom_content);
			}
			if (data.action === 'redirect' && data.redirect !== undefined) {
				window.location = data.redirect;
			}
			if (data.action === 'refresh') {
				window.location.reload();
			}

		} else if (data.status === 'error') {
			console.log("[PaleWhite] Server Error: ", data.error);
			if (data.exception_trace !== undefined) {
				console.log("[PaleWhite] Exception fired in " + data.exception_trace.file + ":" + data.exception_trace.line);
				for (var i = 0; i < data.exception_trace.stacktrace.length; i++) {
					console.log("\t" + data.exception_trace.stacktrace[i]);
				}
			}

		} else {
			console.log("[PaleWhite] unknown ajax response: ", data);
		}
	},
	substitute_dom_content: function (dom_content) {
		Object.keys(dom_content).forEach(function (selector) {
			var nodes = document.querySelectorAll(selector);
			for (var i = 0; i < nodes.length; i++) {
				var node = nodes[i];

				// create the new dom and add javascript hooks
				var newdom = document.createElement('div');
				newdom.innerHTML = dom_content[selector];
				PaleWhite.add_hooks(newdom);
				newdom = newdom.firstChild;

				node.appendChild(newdom);
				// // replace the target with it
				// node.parentNode.replaceChild(newdom, node);
			}
		});
	},
	parse_form_input: function (form) {
		var form_data = new FormData(form);

		// see if the input has any files
		for(var pair of form_data.entries()) {
			if (pair[1] instanceof File) {
				// if there is a file, we return the form data as is
				return form_data;
			}
		}

		// otherwise we parse a JSON-ready object
		var data = {};
		for(var pair of form_data.entries()) {
			if (pair[0].endsWith("[]")) {
				// append to array
				var array_name = pair[0].substring(0, pair[0].length - 2);
				if (data[array_name] === undefined) {
					data[array_name] = [];
				}
				data[array_name].push(pair[1]);
			} else if (pair[0].endsWith("']") && pair[0].indexOf("['") !== -1) {
				// append to map
				var index = pair[0].indexOf("['");
				var map_name = pair[0].substring(0, index);
				var map_key = pair[0].substring(index + 2, pair[0].length - 2);
				if (data[map_name] === undefined) {
					data[map_name] = {};
				}
				data[map_name][map_key] = pair[1];
			} else {
				data[pair[0]] = pair[1];
			}
		}
		return data;
	},
	api_request: function (url, args, callback) {
		url = this.get_site_base() + url;

		var xhr = new XMLHttpRequest();
		xhr.open("POST", url, true);
		xhr.setRequestHeader("X-Requested-With", "pale_white/api");
		xhr.addEventListener('readystatechange', function () {
			if (xhr.readyState == 4) {
				var response;
				if (xhr.response === "") {
					console.log("[PaleWhite] empty response!");
					response = {};
				} else {
					response = JSON.parse(xhr.response);
					console.log("[PaleWhite] got api response: ", response);
				}
				if (callback)
					callback(response);
			}
		});
		
		if (args instanceof FormData) {
			// xhr.setRequestHeader("Content-Type", "multipart/form-data");
			args.append("_csrf_token", PaleWhite.get_csrf_token());
			xhr.send(args);

		} else {
			xhr.setRequestHeader("Content-Type", "application/json");
			args._csrf_token = PaleWhite.get_csrf_token();
			xhr.send(JSON.stringify(args));
		}
	},
	html_nodes: function (html_text) {
		var newdom = document.createElement('div');
		newdom.innerHTML = html_text;
		PaleWhite.add_hooks(newdom);

		var children = [];
		for (var i = 0; i < newdom.children.length; i++) {
			children[i] = newdom.children[i];
		}
		return children;
	},
	query: function (nodes, css_selector) {
		if (css_selector === undefined) {
			css_selector = nodes;
			nodes = [document];
		}

		var new_nodes = [];
		for (var i = 0; i < nodes.length; i++) {
			var found = nodes[i].querySelectorAll(css_selector);
			for (var k = 0; k < found.length; k++) {
				new_nodes.push(found[k]);
			}
		}

		return new_nodes;
	},

	pwa_command: function (nodes, command) {
		var instruction_strings = command.split(/\s*;\s*/m);
		for (var i = 0; i < instruction_strings.length; i++) {
			var parts = instruction_strings[i].split(/\s*:\s*/m, 3);
			var targets;
			var selector;
			var action;
			if (parts.length == 3) {
				if (parts[0] === 'document') {
					targets = [document];
				} else if (parts[0] === 'this') {
					targets = nodes;
				} else if (parts[0] === 'parent') {
					targets = [];
					for (var k = 0; k < nodes.length; k++) {
						targets.push(nodes[k].parentNode);
					}
				} else {
					console.log("invalid target: ", parts[0]);
					return;
				}

				selector = parts[1];
				action = parts[2];
			} else if (parts.length == 2) {
				targets = [document];
				selector = parts[0];
				action = parts[1];
			} else {
				targets = nodes;
				action = parts[0];
			}

			if (selector) {
				targets = PaleWhite.query(targets, selector);
			}

			PaleWhite.pwa_action(targets, action);
		}
	},
	pwa_action: function (nodes, action) {
		var action_strings = action.split(/\s+/m);
		for (var i = 0; i < action_strings.length; i++) {
			if (action_strings[i].startsWith("+")) {
				var class_name = action_strings[i].substring(1);
				for (var k = 0; k < nodes.length; k++)
					nodes[k].classList.add(class_name);
			} else if (action_strings[i].startsWith("-")) {
				var class_name = action_strings[i].substring(1);
				for (var k = 0; k < nodes.length; k++)
					nodes[k].classList.remove(class_name);
			} else if (action_strings[i].startsWith("~")) {
				var class_name = action_strings[i].substring(1);
				for (var k = 0; k < nodes.length; k++)
					nodes[k].classList.toggle(class_name);
			} else {
				console.log("invalid pwa action: ", action_strings[i]);
			}
		}
	},


	object_pairs: function (obj) {
		var pairs = [];
		Object.keys(obj).forEach(function (key) {
			pairs.push([key, obj[key]]);
		});
		return pairs;
	}
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
PaleWhite.Glass = {};

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
		return String(text).replace(/[&<>"'"]/g, function(m) { return map[m]; });
	},
};

// object for storing model template data and allowing easy rerendering
PaleWhite.Glass.ModelTemplateData = function (node, fields, data) {
	this._node = node;
	this._data = data;
	this._fields = fields;

	var getter = function (field) {
		return this._data[field];
	};
	var setter = function (field, value) {
		this._data[field] = value;
		this._rerender();
	};

	var properties = {};
	for (var i = 0; i < fields.length; i++) {
		properties[fields[i]] = {
			get: getter.bind(this, fields[i]),
			set: setter.bind(this, fields[i]),
		};
	}

	Object.defineProperties(this, properties);
};
PaleWhite.Glass.ModelTemplateData.prototype._rerender = function () {
	var template_class = PaleWhite.get_template(this._node.dataset.modelTemplate);
	var rendered_html = template_class.render({ model: this._data });
	var new_node = PaleWhite.html_nodes(rendered_html)[0];
	PaleWhite.add_hooks(new_node);

	this._node.parentNode.replaceChild(new_node, this._node);
};

PaleWhite.Glass.ModelTemplateList = function (node) {
	this.node = node;
};
PaleWhite.Glass.ModelTemplateList.prototype.insert_model = function (index, data) {
	var template_class = PaleWhite.get_template(this.node.dataset.modelTemplate);
	var rendered_html = template_class.render({ model: data });
	var new_node = PaleWhite.html_nodes(rendered_html)[0];
	PaleWhite.add_hooks(new_node);
	this.node.insertBefore(new_node, this.node.children[index]);
};
PaleWhite.Glass.ModelTemplateList.prototype.prepend_model = function (data) {
	this.insert_model(0, data);
};
PaleWhite.Glass.ModelTemplateList.prototype.append_model = function (data) {
	this.insert_model(this.node.children.length, data);
};
PaleWhite.Glass.ModelTemplateList.prototype.remove_model = function (index) {
	var data = this.node.children[index].pw_model._data;
	this.node.removeChild(this.node.children[index]);
	return data;
};
PaleWhite.Glass.ModelTemplateList.prototype.pop_model = function () {
	return this.remove_model(this.node.children.length - 1);
};
PaleWhite.Glass.ModelTemplateList.prototype.clear_models = function () {
	while(this.node.firstChild)
		this.node.removeChild(this.node.firstChild);
};
PaleWhite.Glass.ModelTemplateList.prototype.find = function (data) {
	var data_keys = Object.keys(data);
	
	var nodes = [];
	for (var i = 0; i < this.node.children.length; i++) {
		var node_data = this.node.children[i].pw_model._data;
		var matches = true;
		for (var k = 0; k < data_keys.length; k++) {
			if (node_data[data_keys[k]] !== data[data_keys[k]])
				matches = false;
		}

		if (matches)
			nodes.push(this.node.children[i]);
	}
	return nodes;
};


window.addEventListener('load', function () { PaleWhite.onload(); });
PaleWhite.register_hook('form.ajax_trigger', 'submit', function (event) {
	event.preventDefault();
	event.stopPropagation();
	var form = this;
	PaleWhite.ajax(this.dataset.triggerAction, PaleWhite.parse_form_input(this), function (data) {
		// if the response is an error, and the form has an on_error attribute
		if (data.status === 'error') {
			if (form.dataset.onTriggerError) {
				var selector = form.dataset.onTriggerError;
				var error_container = document.body.querySelector(selector);
				error_container.innerText = data.error;
			}
		}
	});
});
PaleWhite.register_hook('.pwa-clickable', 'click', function (event) {
	event.preventDefault();
	event.stopPropagation();
	PaleWhite.pwa_command([this], this.dataset.pwaCommand);
	// PaleWhite.execute_pwa_command(this, this.dataset.pwaCommand);
});
PaleWhite.register_hook('.pw-model-template', 'load', function () {
	var data = JSON.parse(this.dataset.modelData);
	var model_template = this.dataset.modelTemplate;
	var fields = PaleWhite.get_class(model_template).fields;
	this._pw_model = new PaleWhite.Glass.ModelTemplateData(this, fields, data);

	Object.defineProperty(this, 'pw_model', {
		get: (function () { return this._pw_model; }).bind(this),
		set: (function (value) { this._pw_model._data = value; this._pw_model._rerender(); }).bind(this),
	});
});
PaleWhite.register_hook('.pw-model-template-list', 'load', function () {
	this._pw_model_list = new PaleWhite.Glass.ModelTemplateList(this);

	Object.defineProperty(this, 'pw_model_list', {
		get: (function () { return this._pw_model_list; }).bind(this),
		set: (function (data_list) {
			this._pw_model_list.clear_models();
			for (var i = 0; i < data_list.length; i++)
				this._pw_model_list.append_model(data_list[i]);
		}).bind(this),
	});
});


