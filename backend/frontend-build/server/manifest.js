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
		client: {start:"_app/immutable/entry/start.4TEX1rq0.js",app:"_app/immutable/entry/app.UMEeD5Ro.js",imports:["_app/immutable/entry/start.4TEX1rq0.js","_app/immutable/chunks/DeFU6qEV.js","_app/immutable/chunks/CZG4RayU.js","_app/immutable/chunks/CTg2jUt1.js","_app/immutable/entry/app.UMEeD5Ro.js","_app/immutable/chunks/CTg2jUt1.js","_app/immutable/chunks/CZG4RayU.js","_app/immutable/chunks/CWj6FrbW.js","_app/immutable/chunks/dXEtNgE2.js","_app/immutable/chunks/5EVyXMsi.js"],stylesheets:[],fonts:[],uses_env_dynamic_public:false},
		nodes: [
			__memo(() => import('./chunks/0-qbq8TNJX.js')),
			__memo(() => import('./chunks/1-CQyFbCeI.js')),
			__memo(() => import('./chunks/2-vkLd9QWy.js')),
			__memo(() => import('./chunks/3-CfYLjr-5.js')),
			__memo(() => import('./chunks/4-Bblm5Kee.js')),
			__memo(() => import('./chunks/5-DintkJLL.js')),
			__memo(() => import('./chunks/6-CbYu6h_z.js'))
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
