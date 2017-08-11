
pale_white = {
	registered_hooks: [],

	onload: function () {
		this.add_hooks(document.body);
	},
	add_hooks: function (dom) {
		this.registered_hooks.forEach(function (hook) {
			var nodes = dom.querySelectorAll(hook.selector);
			for (var i = 0; i < nodes.length; i++) {
				nodes[i].addEventListener(hook.event, hook.callback);
			}
		});
	},
	register_hook: function (selector, event, callback) {
		this.registered_hooks.push({
			selector: selector,
			event: event,
			callback: callback,
		});
	},
	send_ajax_trigger: function (url, args) {
		var xhr = new XMLHttpRequest();
		xhr.open("POST", url, true);
		xhr.setRequestHeader("X-Requested-With", "pale_white/ajax");
		xhr.addEventListener('readystatechange', function () {
			if (xhr.readyState == 4) {
				pale_white.on_ajax_trigger_response(JSON.parse(xhr.response));
			}
		});
		
		if (args instanceof FormData) {
			// xhr.setRequestHeader("Content-Type", "multipart/form-data");
			xhr.send(args);
						
		} else {
			xhr.setRequestHeader("Content-Type", "application/json");
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
		}
	},
	substitute_dom_content: function (dom_content) {
		Object.keys(dom_content).forEach(function (selector) {
			var nodes = document.querySelectorAll(selector);
			for (var i = 0; i < nodes.length; i++) {
				var node = nodes[i];
				var newdom = document.createElement('div');
				newdom.innerHTML = dom_content[selector];
				newdom = newdom.firstChild;
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
};

window.addEventListener('load', function () { pale_white.onload(); });
pale_white.register_hook('form.ajax_trigger', 'submit', function (event) {
	event.preventDefault();
	pale_white.send_ajax_trigger(this.getAttribute('action'), pale_white.parse_form_input(this));
});

