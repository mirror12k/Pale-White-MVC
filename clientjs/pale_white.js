
pale_white = {
	registered_hooks: [],
	registered_scroll_hooks: [],

	onload: function () {
		this.add_hooks(document.body);
		window.addEventListener('scroll', function (event) { pale_white.onscroll(event); });
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
					hook.callback.call(node);
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
				if (xhr.response === "") {
					console.log("[PaleWhite] empty response!");
					response = {};
				} else {
					response = JSON.parse(xhr.response);
				}
				pale_white.on_ajax_response(response);

				if (callback)
					callback(response);
			}
		});
		
		if (args instanceof FormData) {
			// xhr.setRequestHeader("Content-Type", "multipart/form-data");
			args.append("_csrf_token", pale_white.get_csrf_token());
			xhr.send(args);

		} else {
			xhr.setRequestHeader("Content-Type", "application/json");
			args._csrf_token = pale_white.get_csrf_token();
			xhr.send(JSON.stringify(args));
		}
	},
	on_ajax_response: function (data) {
		console.log("[PaleWhite] got response: ", data);

		if (data.status === 'success') {
			if (data.dom_content !== undefined) {
				pale_white.substitute_dom_content(data.dom_content);
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
				pale_white.add_hooks(newdom);
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
		var xhr = new XMLHttpRequest();
		xhr.open("POST", url, true);
		xhr.setRequestHeader("X-Requested-With", "pale_white/api");
		xhr.addEventListener('readystatechange', function () {
			if (xhr.readyState == 4) {
				if (xhr.response === "") {
					console.log("[PaleWhite] empty response!");
					response = {};
				} else {
					response = JSON.parse(xhr.response);
				}
				if (callback)
					callback(response);
			}
		});
		
		if (args instanceof FormData) {
			// xhr.setRequestHeader("Content-Type", "multipart/form-data");
			args.append("_csrf_token", pale_white.get_csrf_token());
			xhr.send(args);

		} else {
			xhr.setRequestHeader("Content-Type", "application/json");
			args._csrf_token = pale_white.get_csrf_token();
			xhr.send(JSON.stringify(args));
		}
	},
	html_nodes: function (html_text) {
		var newdom = document.createElement('div');
		newdom.innerHTML = html_text;
		pale_white.add_hooks(newdom);

		var children = [];
		for (var i = 0; i < newdom.children.length; i++) {
			children[i] = newdom.children[i];
		}
		return children;
	},
	parse_pwa_command: function (command) {
		var instruction_strings = command.split(/\s*;\s*/m);
		var instructions = [];
		for (var i = 0; i < instruction_strings.length; i++) {
			var parts = instruction_strings[i].split(/\s*:\s*/m, 3);
			if (parts.length == 3) {
				instructions.push({
					target: parts[0],
					selector: parts[1],
					actions: this.parse_pwa_actions(parts[2]),
				});
			} else if (parts.length == 2) {
				instructions.push({
					target: 'document',
					selector: parts[0],
					actions: this.parse_pwa_actions(parts[1]),
				});
			} else {
				instructions.push({
					target: 'this',
					actions: this.parse_pwa_actions(parts[0]),
				});
			}
		}

		return instructions;
	},
	parse_pwa_actions: function (command) {
		var action_strings = command.split(/\s+/m);
		var actions = [];
		for (var i = 0; i < action_strings.length; i++) {
			if (action_strings[i].startsWith("+")) {
				actions.push({
					type: 'add_class',
					class: action_strings[i].substring(1),
				});
			} else if (action_strings[i].startsWith("-")) {
				actions.push({
					type: 'remove_class',
					class: action_strings[i].substring(1),
				});
			} else if (action_strings[i].startsWith("~")) {
				actions.push({
					type: 'toggle_class',
					class: action_strings[i].substring(1),
				});
			} else {
				console.log("invalid pwa action: ", action_strings[i]);
			}
		}
		return actions;
	},
	closure_pwa_instructions: function (context, instructions) {
		var closured_instructions = [];
		for (var i = 0; i < instructions.length; i++) {
			var selector = instructions[i].selector;
			// closure selector if it exists
			if (selector) {
				selector = selector.replace(/\$([a-zA-Z_][a-zA-Z_0-9]*)/, function (match, identifier) {
					return context.dataset[identifier];
				});
			}
			closured_instructions.push({
				target: instructions[i].target,
				selector: selector,
				actions: this.closure_pwa_actions(context, instructions[i].actions),
			});
		}
		return closured_instructions;
	},
	closure_pwa_actions: function (context, actions) {
		var closured_actions = [];
		for (var i = 0; i < actions.length; i++) {
			var action_class = actions[i].class;
			action_class = action_class.replace(/\$([a-zA-Z_][a-zA-Z_0-9]*)/, function (match, identifier) {
				return context.dataset[identifier];
			});

			closured_actions.push({
				type: actions[i].type,
				class: action_class,
			});
		}
		return closured_actions;
	},
	execute_pwa_command: function (target_node, command) {
		var instructions = this.parse_pwa_command(command);
		this.execute_pwa_instructions(target_node, instructions);
	},
	execute_pwa_instructions: function (target_node, instructions) {
		instructions = this.closure_pwa_instructions(target_node, instructions);
		for (var i = 0; i < instructions.length; i++) {
			// determine starting point
			var start_point;
			if (instructions[i].target == 'this') {
				start_point = target_node;
			} else if (instructions[i].target == 'parent') {
				start_point = target_node.parentNode;
			} else {
				start_point = document;
			}

			// expand if we have a selector
			var node_list;
			var selector = instructions[i].selector;
			if (selector) {
				node_list = start_point.querySelectorAll(selector);
			} else {
				node_list = [start_point];
			}

			// excute actions on each node
			for (var k = 0; k < node_list.length; k++) {
				this.execute_pwa_actions(node_list[k], instructions[i].actions);
			}
		}
	},
	execute_pwa_actions: function (target_node, actions) {
		for (var i = 0; i < actions.length; i++) {
			var action = actions[i];
			if (action.type == 'add_class') {
				target_node.classList.add(action.class);
			} else if (action.type == 'remove_class') {
				target_node.classList.remove(action.class);
			} else if (action.type == 'toggle_class') {
				target_node.classList.toggle(action.class);
			}
		}
	}
};

window.addEventListener('load', function () { pale_white.onload(); });
pale_white.register_hook('form.ajax_trigger', 'submit', function (event) {
	event.preventDefault();
	event.stopPropagation();
	var form = this;
	pale_white.ajax(this.dataset.triggerAction, pale_white.parse_form_input(this), function (data) {
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
pale_white.register_hook('.pwa-clickable', 'click', function (event) {
	event.preventDefault();
	event.stopPropagation();
	pale_white.execute_pwa_command(this, this.dataset.pwaCommand);
});

