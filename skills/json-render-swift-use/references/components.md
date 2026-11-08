# Standard components (36)

Contents: the list the model sees, props the Swift catalog adds, slots, events, notes per component, what is not supported.

The standard catalog (`Catalog.standard`, product `JSONRenderStandardCatalog`) has the 36 shadcn components of json-render with upstream names and prop names. A spec written for the upstream shadcn catalog renders here without changes. A prop marked `?` is optional; every other prop is required. `className` is accepted and ignored (there is no CSS); style through the theme.

The block below is what `Catalog.prompt()` prints for the components. It is generated; do not edit it. Regenerate with `skills/scripts/refresh-catalog-reference.sh`.

<!-- BEGIN GENERATED: components -->
<!-- Generated from Catalog.prompt() by skills/scripts/refresh-catalog-reference.sh. Do not edit by hand. -->

```text
AVAILABLE COMPONENTS (36):

- Card: { title?: string, description?: string, maxWidth?: "sm" | "md" | "lg" | "full", centered?: boolean, className?: string, variant?: "outlined" | "plain" | "elevated" } - Container card for content sections. Use for forms/content boxes, NOT for page headers. [accepts children; slots: header, footer]
- Stack: { direction?: "horizontal" | "vertical", gap?: "none" | "sm" | "md" | "lg" | "xl", align?: "start" | "center" | "end" | "stretch", justify?: "start" | "center" | "end" | "between" | "around", className?: string, wrap?: boolean } - Flex container for layouts [accepts children]
- Grid: { columns?: number, gap?: "sm" | "md" | "lg" | "xl", className?: string } - Grid layout (1-6 columns) [accepts children]
- Separator: { orientation?: "horizontal" | "vertical" } - Visual separator line
- Tabs: { tabs: Array<{ label: string, value: string }>, defaultValue?: string, value?: string, variant?: "underline" | "segmented" } - Tab navigation. Use { $bindState } on value for active tab binding. [accepts children] [events: change]
- Accordion: { items: Array<{ title: string, content: string }>, type?: "single" | "multiple" } - Collapsible sections. Items as [{title, content}]. Type 'single' (default) or 'multiple'.
- Collapsible: { title: string, defaultOpen?: boolean, open?: boolean } - Collapsible section with trigger. Children render inside. [accepts children]
- Pagination: { totalPages: number, page?: number } - Page navigation. Use { $bindState } on page for current page number. [events: change]
- Dialog: { title: string, description?: string, openPath: string, open?: boolean } - Modal dialog. Set openPath to a boolean state path. Use setState to toggle. [accepts children; slots: footer]
- Drawer: { title: string, description?: string, openPath: string, open?: boolean } - Bottom sheet drawer. Set openPath to a boolean state path. Use setState to toggle. [accepts children; slots: footer]
- Tooltip: { content: string, text: string } - Hover tooltip. Shows content on hover over text.
- Popover: { trigger: string, content: string } - Popover that appears on click of trigger.
- DropdownMenu: { label: string, items: Array<{ label: string, value: string }>, value?: string } - Dropdown menu with trigger button and selectable items. Use { $bindState } on value for selected item binding. [events: select]
- Heading: { text: string, level?: "h1" | "h2" | "h3" | "h4" } - Heading text (h1-h4)
- Text: { text: string, variant?: "body" | "caption" | "muted" | "lead" | "code" } - Paragraph text
- Badge: { text: string, variant?: "default" | "secondary" | "destructive" | "outline" | "good" | "warning" | "critical" } - Status badge
- Alert: { title: string, message?: string, type?: "info" | "success" | "warning" | "error" } - Alert banner
- Skeleton: { width?: string, height?: string, rounded?: boolean, shape?: "line" | "block" | "circle" | "card" | "tableBody" } - Loading placeholder skeleton
- Image: { src?: string, alt: string, width?: number, height?: number, fit?: "contain" | "cover" } - Image component. Renders an img tag when src is provided, otherwise a placeholder. [slots: error, loading]
- Avatar: { src?: string, name: string, size?: "sm" | "md" | "lg" } - User avatar with fallback initials
- Carousel: { items: Array<{ title?: string, description?: string }> } - Horizontally scrollable carousel of cards. [accepts children]
- Table: { columns: Array<string>, rows: Array<Array<string>>, caption?: string, sortable?: boolean } - Data table. columns: header labels. rows: 2D array of cell strings, e.g. [["Alice","admin"],["Bob","user"]]. [accepts children; slots: empty, loading]
- Progress: { value: number, max?: number, label?: string } - Progress bar (value 0-100)
- Spinner: { size?: "sm" | "md" | "lg", label?: string } - Loading spinner indicator
- Button: { label: string, variant?: "primary" | "secondary" | "danger" | "destructive" | "plain", disabled?: boolean, size?: "sm" | "md" | "lg", icon?: string } - Clickable button. Bind on.press for handler. [events: press]
- Link: { label: string, href: string } - Anchor link. Bind on.press for click handler. [events: press]
- Input: { label: string, name: string, type?: "text" | "email" | "password" | "number", placeholder?: string, value?: string, checks?: Array<{ type: string, message: string, args?: Record<string, unknown> }>, validateOn?: "change" | "blur" | "submit" } - Text input field. Use { $bindState } on value for two-way binding. Use checks for validation (e.g. required, email, minLength). validateOn controls timing (default: blur). [events: submit, focus, blur]
- Textarea: { label: string, name: string, placeholder?: string, rows?: number, value?: string, checks?: Array<{ type: string, message: string, args?: Record<string, unknown> }>, validateOn?: "change" | "blur" | "submit" } - Multi-line text input. Use { $bindState } on value for binding. Use checks for validation. validateOn controls timing (default: blur).
- Select: { label: string, name: string, options: Array<string>, placeholder?: string, value?: string, checks?: Array<{ type: string, message: string, args?: Record<string, unknown> }>, validateOn?: "change" | "blur" | "submit" } - Dropdown select input. Use { $bindState } on value for binding. Use checks for validation. validateOn controls timing (default: change). [events: change]
- Checkbox: { label: string, name: string, checked?: boolean, checks?: Array<{ type: string, message: string, args?: Record<string, unknown> }>, validateOn?: "change" | "blur" | "submit" } - Checkbox input. Use { $bindState } on checked for binding. Use checks for validation. validateOn controls timing (default: change). [events: change]
- Radio: { label: string, name: string, options: Array<string>, value?: string, checks?: Array<{ type: string, message: string, args?: Record<string, unknown> }>, validateOn?: "change" | "blur" | "submit" } - Radio button group. Use { $bindState } on value for binding. Use checks for validation. validateOn controls timing (default: change). [events: change]
- Switch: { label: string, name: string, checked?: boolean, checks?: Array<{ type: string, message: string, args?: Record<string, unknown> }>, validateOn?: "change" | "blur" | "submit" } - Toggle switch. Use { $bindState } on checked for binding. Use checks for validation. validateOn controls timing (default: change). [events: change]
- Slider: { label?: string, min?: number, max?: number, step?: number, value?: number } - Range slider input. Use { $bindState } on value for binding. [events: change]
- Toggle: { label: string, pressed?: boolean, variant?: "default" | "outline" } - Toggle button. Use { $bindState } on pressed for state binding. [events: change]
- ToggleGroup: { items: Array<{ label: string, value: string }>, type?: "single" | "multiple", value?: string } - Group of toggle buttons. Type 'single' (default) or 'multiple'. Use { $bindState } on value. [events: change]
- ButtonGroup: { buttons: Array<{ label: string, value: string }>, selected?: string } - Segmented button group. Use { $bindState } on selected for selected value. [events: change]
```

<!-- END GENERATED: components -->

## Props the Swift catalog adds

Optional extras on top of the upstream props. Skip them unless the user asks; upstream specs never use them.

| Component | Extra props |
|---|---|
| Card | `variant?` `outlined` / `plain` / `elevated` |
| Stack | `wrap?` |
| Tabs | `variant?` `underline` / `segmented` |
| Collapsible | `open?` (`$bindState`) |
| Dialog, Drawer | `open?` (`$bindState`), an alternative to `openPath` |
| Badge | `variant?` also `good` / `warning` / `critical` |
| Skeleton | `shape?` |
| Image | `fit?` `contain` / `cover` |
| Table | `sortable?` |
| Button | `variant?` also `destructive` (alias of `danger`) and `plain`; `size?` `sm` / `md` / `lg`; `icon?` (SF Symbol name) |

## Slots

`children` is the default slot. Named slots go in the element field `slots` (see `spec.md`).

| Component | Slots |
|---|---|
| Card | `header`, `footer` |
| Dialog, Drawer | `footer` |
| Image | `error`, `loading` |
| Table | `empty`, `loading` |
| `Stack`, `Grid`, `Tabs`, `Collapsible`, `Carousel` | `default` only (use `children`) |

## Events

Use only these event names in `on`.

| Event | Components |
|---|---|
| `press` | Button, Link |
| `change` | Tabs, Select, Checkbox, Radio, Switch, Slider, Toggle, ToggleGroup, ButtonGroup, Pagination |
| `select` | DropdownMenu |
| `submit`, `focus`, `blur` | Input |

## Binding props

Put `{ "$bindState": "/path" }` on the natural value prop:

| Component | Prop |
|---|---|
| Input, Textarea, Select, Radio, Slider, DropdownMenu, ToggleGroup | `value` |
| Checkbox, Switch | `checked` |
| Toggle | `pressed` |
| ButtonGroup | `selected` |
| Pagination | `page` |
| Tabs | `value` |

Inside `repeat`, use `$bindItem` in the same props. A component that has `checks` must also bind its value, or the check has nothing to read.

## Notes per component

- **Card**: for forms and content boxes, not page headers. `maxWidth` is `sm`, `md`, `lg` or `full`.
- **Stack**: `gap` is a token (`none`, `sm`, `md`, `lg`, `xl`), not a number. Default direction is vertical.
- **Grid**: `columns` is a number from 1 to 6. It adapts to the width.
- **Tabs**: `tabs` is `[{ "label", "value" }]`. The active tab's value is `value` (bind it to state). The element's `children` render below the bar for every tab; there is no per-tab child mapping. To show a panel for one tab, give the panel `visible: { "$state": "/tab", "eq": "<value>" }` (see `examples/card-table.json`). A Tabs that is not bound keeps its own active tab (starting at `defaultValue`, else the first tab).
- **Accordion**: `items` is `[{ "title", "content" }]` with text content. For rich content use `Collapsible` with children.
- **Dialog, Drawer**: `openPath` is a state path that holds a boolean. Open it with `setState` to `true`; Escape and the close control write `false`. Put a Button elsewhere to open it.
- **Table**: literal rows are `rows: [["Alice","admin"]]`, cells are strings, numbers right-align. `columns` are header labels. Past 500 literal rows the table draws 500 and says "Showing 500 of N rows". `rows` may also be `{ "$state": "/path" }` over an array of objects: then each column string is the field name to read. To put controls in rows, put `repeat` on the Table: write `columns` as item field names, give `rows: []` (the catalog schema still requires `rows`), and the Table's children render once per row in a trailing column under that row's scope (`$item`, `$index`). The component also reads `{ "key", "label" }` columns, but `Catalog.validate` reports `invalid_props` for them: use strings. `sortable` adds header buttons that sort the drawn rows.
- **Image**: local files inside the host's allowed folders, `data:` URLs, or an SF Symbol name. An `https` src shows a placeholder with the host name unless the app installs a `JRRemoteImageProvider` (the package never fetches; see `security.md`).
- **Progress**: `value` runs from 0 to `max` (default 100).
- **Skeleton, Spinner**: use for a state the spec already knows is loading. Streaming draws its own skeletons.
- **Input**: `type` is `text`, `email`, `password` or `number`. A `password` value is a secret prop: a host must not save or log it. `validateOn` is `change`, `blur` or `submit` (default `blur`).
- **Select, Radio**: `options` is a string array. `validateOn` default is `change`.
- **Button**: `variant` is `primary`, `secondary`, `danger` (`destructive` is an alias) or `plain`. Use one `primary` per view.
- **Link**: with `on.press`, a press runs those bindings and opens nothing. Without it, an absolute URL (one with a scheme) goes to the host's `openURL`; a relative or `#` link does nothing. The component never opens a URL itself.
- **DropdownMenu**: `items` is `[{ "label", "value" }]`; the choice goes to `value` and the `select` event fires.
- **ToggleGroup**: `type` `single` (default) or `multiple`; `multiple` makes `value` an array.
- **ButtonGroup**: `buttons` is `[{ "label", "value" }]`; `selected` holds the chosen value.
- **Pagination**: `totalPages` and `page` (1-based).

## Validation checks

`checks` on form components is `[{ "type", "message", "args"? }]`. Types: `required`, `email`, `url`, `numeric`, `minLength` (`args.min`), `maxLength` (`args.max`), `pattern` (`args.pattern`), `min`, `max`, `matches` and `equalTo` (`args.other`: `{ "$state": "/path" }`), `lessThan`, `greaterThan` (`args.other`), `requiredIf` (`args.field`). Add `required` and one format check to every input a user must fill.

A `pattern` check is run on blur or submit, never on each keystroke. A pattern the runtime cannot check safely (a regular expression that can take exponential time) is refused with a neutral message ("This pattern cannot be checked"); use a simple pattern.

## Not supported in 0.22.x

- YAML specs. Specs are JSON.
- The Rafu-only components (Stat, KeyValue, Timeline, Markdown, Mermaid, Code, Callout, Checklist, FileLink, CardLink, TerminalStatus, AgentStatus, DiffSummary, IconLibraryIcon). They belong to the Rafu app's catalog, not to this package.
- `$math`, `$concat`, `$truncate` and `$t` directives. `$format`, `$count`, `$join` and `$pluralize` are shipped.
- Merge and diff edit modes. Only patch mode.
- Navigation actions `push` and `pop`.
- HTML, CSS, raw colour props and web views.
