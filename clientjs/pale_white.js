
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
				pale_white.on_ajax_trigger_response(response);

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
	on_ajax_trigger_response: function (data) {
		console.log("[PaleWhite] got response: ", data);

		if (data.status === 'success') {
			if (data.dom_content !== undefined) {
				pale_white.substitute_dom_content(data.dom_content);
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

				// replace the target with it
				node.parentNode.replaceChild(newdom, node);
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
			data[pair[0]] = pair[1];
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
};

window.addEventListener('load', function () { pale_white.onload(); });
pale_white.register_hook('form.ajax_trigger', 'submit', function (event) {
	event.preventDefault();
	pale_white.ajax(this.dataset.triggerAction, pale_white.parse_form_input(this));
});

