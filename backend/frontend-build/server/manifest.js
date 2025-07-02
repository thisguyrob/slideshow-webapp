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
		client: {start:"_app/immutable/entry/start.D0m2wKQt.js",app:"_app/immutable/entry/app.Bkevnq3W.js",imports:["_app/immutable/entry/start.D0m2wKQt.js","_app/immutable/chunks/D7x77NIs.js","_app/immutable/chunks/BVW34SQx.js","_app/immutable/chunks/CNfditUa.js","_app/immutable/entry/app.Bkevnq3W.js","_app/immutable/chunks/CNfditUa.js","_app/immutable/chunks/BVW34SQx.js","_app/immutable/chunks/CWj6FrbW.js","_app/immutable/chunks/GC4dxQQb.js","_app/immutable/chunks/0rDqRz2G.js"],stylesheets:[],fonts:[],uses_env_dynamic_public:false},
		nodes: [
			__memo(() => import('./chunks/0-D8gm-g-X.js')),
			__memo(() => import('./chunks/1-DhuBdxyv.js')),
			__memo(() => import('./chunks/2-BKRaRiQx.js')),
			__memo(() => import('./chunks/3-DRgkERV3.js')),
			__memo(() => import('./chunks/4-BvNKZ3ct.js')),
			__memo(() => import('./chunks/5-DmW6K_Jj.js')),
			__memo(() => import('./chunks/6-DjVujG9L.js'))
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
