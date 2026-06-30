'use strict';
'require view';
'require form';
'require uci';

/* DNS provider → required credential keys (for the inline hint) */
var DNS_HINTS = {
	dns_ali: 'Ali_Key="your-access-key"\nAli_Secret="your-access-secret"',
	dns_cf:  'CF_Token="your-cloudflare-api-token"',
	dns_dp:  'DP_Id="your-id"\nDP_Key="your-key"',
	dns_gd:  'GD_Key="your-api-key"\nGD_Secret="your-api-secret"',
	dns_ionos: 'IONOS_PREFIX="your-prefix"\nIONOS_SECRET="your-secret"'
};

return view.extend({
	load: function() {
		return uci.load('https_gateway');
	},

	render: function() {
		var m, s, o;

		m = new form.Map('https_gateway', _('HTTPS Gateway - Settings'),
			_('Global configuration: service control, ACME account, DNS API credentials.'));

		/* ── Service ────────────────────────────────────────────── */
		s = m.section(form.NamedSection, 'global', 'gateway', _('Service'));
		s.anonymous = true;

		o = s.option(form.Flag, 'enabled', _('Enable Gateway'),
			_('When disabled, the proxy service stops and uhttpd reverts to default ports.'));
		o.rmempty = false;

		/* ── ACME / Certificate Issuance ────────────────────────── */
		s = m.section(form.NamedSection, 'global', 'gateway', _('ACME / Certificate Issuance'));
		s.anonymous = true;

		o = s.option(form.Flag, 'use_staging', _('Use Staging Environment'),
			_("Use Let's Encrypt Staging for testing. <strong style=\"color:#c62828\">Certificates issued in staging mode will NOT be trusted by browsers.</strong> Disable before issuing real certificates."));

		o = s.option(form.Value, 'email', _('ACME Email'),
			_("Let's Encrypt account email for certificate expiry notifications."));
		o.datatype = 'email';

		o = s.option(form.ListValue, 'dns_provider', _('DNS Provider'),
			_('DNS API provider for DNS-01 challenge. Determines which credential keys are required below.'));
		o.value('dns_ali', _('Alibaba Cloud DNS (dns_ali)'));
		o.value('dns_cf', _('Cloudflare (dns_cf)'));
		o.value('dns_dp', _('Tencent DNSPod (dns_dp)'));
		o.value('dns_gd', _('GoDaddy (dns_gd)'));
		o.value('dns_ionos', _('IONOS DNS (dns_ionos)'));

		o = s.option(form.DynamicList, 'credentials', _('DNS API Credentials'),
			_('Key=Value pairs for the selected DNS provider. The required keys are shown below after selecting a provider.'));
		o.password = true;

		o = s.option(form.Value, 'dns_wait', _('DNS Propagation Wait (seconds)'),
			_('Time to wait for DNS TXT record propagation. Recommended: 180-300.'));
		o.datatype = 'uinteger';
		o.placeholder = '180';

		/* ── Local DNS ──────────────────────────────────────────── */
		s = m.section(form.NamedSection, 'global', 'gateway', _('Local DNS'));
		s.anonymous = true;

		o = s.option(form.Flag, 'auto_dns', _('Automatic Local DNS'),
			_('Automatically add domain → router IP mappings to dnsmasq so LAN devices resolve to this gateway.'));
		o.default = '1';

		return m.render().then(function(node) {
			/* ── Dynamic credentials hint ──────────────────────── */
			var hintBox = E('pre', {
				'style': 'margin:6px 0 0;padding:8px 12px;background:#f5f5f5;' +
				         'border-left:3px solid #1976d2;font-size:0.85em;' +
				         'white-space:pre-wrap;display:none'
			}, '');

			function updateHint(val) {
				var hint = DNS_HINTS[val];
				if (hint) {
					hintBox.innerText = _('Required keys for selected provider:') + '\n' + hint;
					hintBox.style.display = '';
				} else {
					hintBox.style.display = 'none';
				}
			}

			/* LuCI renders NamedSection containers as #cbi-CONFIG-SECTION-OPTION */
			var credsRow = node.querySelector('[id="cbi-https_gateway-global-credentials"]');
			if (credsRow) {
				credsRow.appendChild(hintBox);
			}

			var providerSel = node.querySelector('[id="cbid.https_gateway.global.dns_provider"]');
			if (providerSel) {
				providerSel.addEventListener('change', function() {
					updateHint(this.value);
				});
				updateHint(providerSel.value);
			}

			return node;
		});
	}
});
