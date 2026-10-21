# Frontend checks

## Check the pinned versions first

Read the repo's `package.json` before recommending any API (see `repos.md`). Most Bounce frontends are plain-JavaScript webpack SPAs on React 16/17, and some modern advice is wrong for them:

- **No React 18+ APIs**: no `startTransition`, `useTransition`, `useDeferredValue`, `useSyncExternalStore`, `useId`, `<Activity>`, `useEffectEvent`. No React Compiler, so manual memoisation matters.
- **`setState` doesn't auto-batch outside event handlers.** Two state updates in an axios `.then()`, a `setTimeout` or a promise callback render twice on 16/17. This is a real bug class (intermediate inconsistent renders), easy to miss for anyone used to React 18.
- **React Query v4**: the cache option is `cacheTime`. The v5 name `gcTime` is silently ignored.
- **react-router-dom v5**: `useHistory`, `<Switch>`, `<Redirect>`. Not `useNavigate`/`<Routes>`.
- **No typechecker** (except fieldwork-dashboard). Misspelled props, misspelled response fields and renamed shared exports fail at runtime, so they are real findings here.

## Correctness

- Wrong or missing dependency arrays. Stale closures in callbacks and effects.
- Effects doing what an event handler should do; state that should be a ref or derived during render.
- `key={index}` on lists that reorder, insert or delete; keys from inline objects or `Math.random()`.
- `{count && <X/>}` renders `0`. Use a ternary or `count > 0 &&`.
- Missing null guards on API data, especially fields new on the backend that old documents won't have.
- A component defined inside another component: it remounts its whole subtree every render and loses state.
- **i18n**: new user-facing strings hardcoded instead of going through the repo's i18n. Run `ls` on the repo's locale directory and confirm a new key landed in **every** locale that exists there. A key only in English ships as a raw key or an English fallback.
- Filter, tab or pagination state held in component state when it belongs in the URL. Refresh and the back button lose it.
- Dates and numbers formatted with an assumed locale or timezone.

## Async and data layer

- **Redux + axios repos**: a thunk that changes server state without re-dispatching the fetch that fills the slice leaves the UI stale until remount. It looks like a backend bug. "Invalidate the query" means nothing here; don't say it.
- **React Query repos**: a mutation that doesn't invalidate the query keys its write affects.
- Two in-flight requests for the same state with no abort or sequence guard: the slower response lands last and overwrites the newer one. Typing fast and changing params are the usual triggers.
- A fetch not aborted on unmount, then setting state on an unmounted component.
- A new async path with no loading, error or empty state, so failure renders as a blank panel.
- An optimistic update with no rollback on failure.
- A submit button not disabled while in flight, so a double click creates two records.
- Requests in a waterfall that could run in parallel (`Promise.all`) when they don't depend on each other.

## Memory

- `useEffect` adding a listener, subscription, interval, timer or observer (`ResizeObserver`, `IntersectionObserver`, `MutationObserver`) with no cleanup.
- Timer ids not stored, or not cleared on unmount. Debounce/throttle wrappers recreated every render, or never cancelled.
- Refs used as async staging areas that keep large data after the callback runs. Null them right after use, not only on unmount.
- `useCallback`/`useMemo` closing over whole arrays that belong in a ref.
- Query or custom caches with no expiry or size limit, using the option name this repo's major version honours.
- DOM nodes held in module-level variables that outlive the component.

## Performance (only with a scale argument)

- Unstable props into memoised children: inline objects, arrays, functions, `style={{…}}` literals. Context values rebuilt every render, re-rendering every consumer.
- Expensive sorts, filters or transforms in the render body on lists that can be large; repeated `.find`/`.includes` inside loops (build a `Map`/`Set`).
- Expensive initial state passed as a value instead of `useState(() => …)`.
- Whole-library imports for one function (lodash, antd, moment, date libraries). Barrel imports that defeat tree shaking.
- Thousands of rows rendered with no virtualisation; every tab rendered when one is visible.
- Heavy components or libraries loaded up front that could be `React.lazy` + `Suspense` (supported in 16.6+ for code splitting).

## Security

- `dangerouslySetInnerHTML` with content that isn't sanitised. More broadly: find the parsing, grid, editor or rendering libraries the diff uses and check whether any builds DOM from data instead of going through React's escaping text renderer. Spreadsheet grids and markdown renderers are the usual offenders; check their pinned versions against known advisories.
- URLs reaching `fetch`, `<a href>`, `<iframe src>`, `window.open` or `location.href` with no protocol check (`javascript:`/`data:`). A function that takes a URL and calls `fetch(url)` is an unvalidated sink even if today's callers are safe.
- Tokens or PII in `localStorage`, `sessionStorage` or a global store.
- `eval`, `new Function`, `setTimeout(string)`, `import(variable)`; merging untrusted objects in a way that can reach `__proto__`.
- A CDN `<script>`/`<link>` with no `integrity` hash.
- Stack traces or internal errors shown to users; secrets in client code.

## Accessibility

- Clickable `div`/`span` with no role, keyboard handler or focus; icon-only buttons with no accessible name; images with no `alt`.
- Dialogs that don't move focus in on open, trap it, and restore it on close.
- Form inputs with no associated label; errors not announced.
