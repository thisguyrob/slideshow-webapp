import { w as push, T as store_get, U as unsubscribe_stores, y as pop } from './exports-B9Xr5DlX.js';
import { p as page } from './stores-DrCfmxJg.js';
import './client-CPBjj8ly.js';

function _page($$payload, $$props) {
  push();
  var $$store_subs;
  store_get($$store_subs ??= {}, "$page", page).params.id;
  {
    $$payload.out += "<!--[-->";
    $$payload.out += `<div class="min-h-screen bg-gray-50 flex justify-center items-center"><div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div></div>`;
  }
  $$payload.out += `<!--]-->`;
  if ($$store_subs) unsubscribe_stores($$store_subs);
  pop();
}

export { _page as default };
//# sourceMappingURL=_page.svelte-CDMIxmhe.js.map
