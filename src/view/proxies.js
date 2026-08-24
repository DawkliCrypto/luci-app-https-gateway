'use strict';
'require view';
'require form';
'require uci';
'require rpc';

var callStatus = rpc.declare({ object: 'https-gateway', method: 'status' });

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('https_gateway'),
			callStatus().catch(function() { return {}; })
		]);
	},

	render: function(data) {
		var st = data[1] || {};
		/* Build a flat list of domains/patterns covered by configured certs */
		var certDomains = (st.certificates || []).map(function(c) { return c.domain; });

		function isCovered(domain) {
			if (!domain) return false;
			return certDomains.some(function(cd) {
				if (cd === domain) return true;
				/* wildcard: *.example.com covers sub.example.com */
				if (cd && cd.indexOf('*.') === 0) {
					var base = cd.slice(1); /* .example.com */
					return domain.slice(domain.indexOf('.')) === base;
				}
				return false;
			});
		}

		function certificateBases() {
			var bases = [];
			certDomains.forEach(function(domain) {
				if (!domain) return;
				domain = domain.indexOf('*.') === 0 ? domain.slice(2) : domain;
				if (bases.indexOf(domain) === -1)
					bases.push(domain);
			});
			return bases;
		}

		function splitDomain(domain, bases) {
			var selected = '';
			bases.forEach(function(base) {
				if (domain === base || domain.slice(-(base.length + 1)) === '.' + base) {
					if (!selected || base.length > selected.length)
						selected = base;
				}
			});
			if (selected)
				return { subdomain: domain === selected ? '' : domain.slice(0, -(selected.length + 1)), base: selected };
			var dot = domain.indexOf('.');
			return { subdomain: dot > 0 ? domain.slice(0, dot) : '', base: dot > 0 ? domain.slice(dot + 1) : domain };
		}

		var m, s, o;

		m = new form.Map('https_gateway', _('HTTPS Gateway - Proxy Rules'),
			_('Configure reverse proxy rules. Each rule maps a domain + path to a backend service, with HTTP and WebSocket support.'));

		s = m.section(form.GridSection, 'proxy', _('Proxy Rules'));
		s.anonymous = true;
		s.addremove = true;
		s.addbtntitle = _('Add Proxy Rule');
		s.sortable = true;
		s.nodescriptions = true;
		s.modaltitle = _('Edit Proxy Rule');

		o = s.option(form.Flag, 'enabled', _('Enabled'));
		o.rmempty = false;
		o.default = '1';
		o.editable = true;
		o.width = '1%';

		o = s.option(form.Value, 'name', _('Name'),
			_('A friendly name for this rule, e.g. "NAS WebUI", "Home Assistant".'));
		o.placeholder = 'My Service';
		o.width = '15%';
		o.rmempty = true;
		/* Pre-existing rules (named UCI sections) have no name option;
		   fall back to the section id so the table stays readable. */
		o.textvalue = function(section_id) {
			return this.cfgvalue(section_id) || section_id;
		};

		o = s.option(form.Value, 'domain', _('Domain'),
			_('Enter the subdomain and select a configured certificate domain.') +
			' <a href="' + L.url('admin/services/https-gateway/certificates') + '">' +
			_('Manage Certificates') + '</a>');
		o.rmempty = false;
		o.render = function(section_id) {
			var bases = certificateBases();
			var current = this.cfgvalue(section_id) || '';
			var parts = splitDomain(current, bases);
			if (bases.indexOf(parts.base) === -1)
				bases.unshift(parts.base);
			var prefixId = this.cbid(section_id) + '-subdomain';
			var baseId = this.cbid(section_id) + '-base';
			return E('div', { 'class': 'cbi-value-field' }, [
				E('input', {
					'id': prefixId,
					'class': 'cbi-input-text',
					'type': 'text',
					'placeholder': _('Subdomain, e.g. nas'),
					'value': parts.subdomain,
					'style': 'width:45%;margin-right:0.5em'
				}),
				E('span', {}, '.'),
				E('select', { 'id': baseId, 'class': 'cbi-input-select', 'style': 'width:45%;margin-left:0.5em' },
					bases.map(function(base) {
						return E('option', { 'value': base, 'selected': base === parts.base }, base);
					}))
			]);
		};
		o.formvalue = function(section_id) {
			var prefix = document.getElementById(this.cbid(section_id) + '-subdomain');
			var base = document.getElementById(this.cbid(section_id) + '-base');
			return prefix && base ? (prefix.value ? prefix.value + '.' : '') + base.value : '';
		};
		/* Show an inline indicator in the table when no cert covers the domain */
		o.textvalue = function(section_id) {
			var domain = this.cfgvalue(section_id);
			if (!domain)
				return '';
			if (isCovered(domain))
				return domain;
			return E('span', {}, [
				domain, ' ',
				E('a', {
					'href': L.url('admin/services/https-gateway/certificates'),
					'title': _('No certificate covers this domain. Add one in Certificates.'),
					'style': 'color:#e65100;text-decoration:none;font-weight:bold'
				}, '⚠')
			]);
		};
		o.validate = function(section_id, value) {
			if (!value)
				return _('Domain cannot be empty');
			if (!/^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/.test(value))
				return _('Enter a valid domain (no wildcards), e.g. nas.example.com');
			return true;
		};

		o = s.option(form.Value, 'location', _('Path'),
			_('URL path prefix, e.g. / or /api/. Paths under the same domain must be unique.'));
		o.rmempty = false;
		o.default = '/';
		o.width = '10%';
		o.validate = function(section_id, value) {
			if (!value || !/^\/[a-zA-Z0-9_./-]*$/.test(value))
				return _('Path must start with / and contain only letters, digits, _, ., -, /');
			return true;
		};

		o = s.option(form.Value, 'upstream', _('Upstream'),
			_('Backend service address, e.g. http://192.168.0.100:5000 or http://127.0.0.1:8080'));
		o.rmempty = false;
		o.placeholder = 'http://192.168.0.x:port';
		o.validate = function(section_id, value) {
			if (!value)
				return _('Upstream address cannot be empty');
			if (!/^https?:\/\/[a-zA-Z0-9.:\[\]-]+(\/[^\s]*)?$/.test(value))
				return _('Enter a valid HTTP/HTTPS address');
			return true;
		};

		o = s.option(form.Flag, 'websocket', _('WS'),
			_('Enable Upgrade/Connection headers for WebSocket long-lived connections.'));
		o.default = '0';
		o.editable = true;
		o.width = '1%';

		o = s.option(form.Value, 'max_body_size', _('Max Body Size'),
			_('Maximum client request body, e.g. 50m. Maps to nginx client_max_body_size. Leave empty for the nginx default (1m); 0 disables the limit.'));
		o.placeholder = '50m';
		o.width = '8%';
		o.validate = function(section_id, value) {
			if (!value)
				return true;
			if (!/^[0-9]+[kKmMgG]?$/.test(value))
				return _('Enter a size like 50m, 1g, or 0 (digits with optional k/m/g suffix)');
			return true;
		};

		return m.render();
	}
});
