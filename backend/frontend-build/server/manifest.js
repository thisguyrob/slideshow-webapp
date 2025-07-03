const manifest = (() => {
function __memo(fn) {
	let value;
	return () => value ??= (value = fn());
}

return {
	appDir: "_app",
	appPath: "_app",
	assets: new Set(["favicon.svg"]),
	mimeTypes: {".svg":"image/svg+xml"},
	_: {
		client: {start:"_app/immutable/entry/start.CNa0--Mm.js",app:"_app/immutable/entry/app.kGIXbPK_.js",imports:["_app/immutable/entry/start.CNa0--Mm.js","_app/immutable/chunks/BEMLZ1wU.js","_app/immutable/chunks/gcnQ8rQN.js","_app/immutable/chunks/D902iWF1.js","_app/immutable/entry/app.kGIXbPK_.js","_app/immutable/chunks/D902iWF1.js","_app/immutable/chunks/gcnQ8rQN.js","_app/immutable/chunks/CWj6FrbW.js","_app/immutable/chunks/ZYqiJWqh.js","_app/immutable/chunks/BuPMYCAJ.js"],stylesheets:[],fonts:[],uses_env_dynamic_public:false},
		nodes: [
			__memo(() => import('./chunks/0-Ck0-NCIb.js')),
			__memo(() => import('./chunks/1-C8YwMC7j.js')),
			__memo(() => import('./chunks/2-B8Xh-Ulv.js')),
			__memo(() => import('./chunks/3-5pjSTBUY.js')),
			__memo(() => import('./chunks/4-CKK0piFW.js')),
			__memo(() => import('./chunks/5-kE-cGz29.js')),
			__memo(() => import('./chunks/6-CESc-KYE.js'))
		],
		routes: [
			{
				id: "/",
				pattern: /^\/$/,
				params: [],
				page: { layouts: [0,], errors: [1,], leaf: 2 },
				endpoint: null
			},
			{
				id: "/fwi-emotional/[id]",
				pattern: /^\/fwi-emotional\/([^/]+?)\/?$/,
				params: [{"name":"id","optional":false,"rest":false,"chained":false}],
				page: { layouts: [0,], errors: [1,], leaf: 3 },
				endpoint: null
			},
			{
				id: "/fwi-main/[id]",
				pattern: /^\/fwi-main\/([^/]+?)\/?$/,
				params: [{"name":"id","optional":false,"rest":false,"chained":false}],
				page: { layouts: [0,], errors: [1,], leaf: 4 },
				endpoint: null
			},
			{
				id: "/project/[id]",
				pattern: /^\/project\/([^/]+?)\/?$/,
				params: [{"name":"id","optional":false,"rest":false,"chained":false}],
				page: { layouts: [0,], errors: [1,], leaf: 5 },
				endpoint: null
			},
			{
				id: "/scavenger-hunt/[id]",
				pattern: /^\/scavenger-hunt\/([^/]+?)\/?$/,
				params: [{"name":"id","optional":false,"rest":false,"chained":false}],
				page: { layouts: [0,], errors: [1,], leaf: 6 },
				endpoint: null
			}
		],
		prerendered_routes: new Set([]),
		matchers: async () => {
			
			return {  };
		},
		server_assets: {}
	}
}
})();

const prerendered = new Set([]);

const base = "";

export { base, manifest, prerendered };
//# sourceMappingURL=manifest.js.map
