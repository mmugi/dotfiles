# Syntax highlight samples

Files for checking a colorscheme against every standard highlight group (`:h group-name`). Open them in Neovim and move the cursor onto a token; `:Inspect` shows which group colors it.

No single language reaches every group, so the samples are split by highlighter and syntax definition.

| File | Highlighter | Main groups |
|---|---|---|
| `sample.c` | legacy syntax | PreProc family, Type family, Statement family, Constant family, Error |
| `Sample.java` | legacy syntax | Typedef, Exception, SpecialComment |
| `sample.lua` | Tree-sitter | `@variable`, Identifier, Function, Keyword, Special |
| `sample.feature` | legacy syntax (Cucumber) | Tag, Define |
| `sample.log` | legacy syntax | Debug, Underlined |
| `sample.diff` | legacy syntax | Added, Changed, Removed |
| `sample.py` | legacy syntax | Python as written, without balancing the groups |
| `sample.swift` | legacy syntax | Swift as written, without balancing the groups |

## How groups inherit colors

- `→ X`: links to `X` by default, so it takes `X`'s color unless the colorscheme defines it.
- `(own)`: a child by category, but Neovim's default colorscheme gives it its own color. It does not inherit the parent's color; define it or link it explicitly.
- Tree-sitter captures (`@...`) also fall back by dropping the last dotted part: an undefined `@keyword.return` uses `@keyword`.

## Standard groups and where to find them

```
Group                       Example tokens                           Samples
Comment                     /* */ // -- #                            c java lua feature py swift
Constant                    NULL EOF MAX_TRAYS <flavor> nil          c java lua feature swift
├─ String (own)             "bakery.h" "plain" [[matcha]]            c java lua py swift
├─ Character → Constant     'x' 'a'                                  c java
├─ Number → Constant        8 0x9a 150.5                             c java lua log py swift
├─ Boolean → Constant       true false                               java lua swift
└─ Float → Number           1.25 1.5e2 .5f                           c
Identifier                  table keys: price label / self           lua py swift
└─ Function (own)           price_of str / When / Swift = + ==       lua feature py swift
Statement                   return break goto assert def / @@        c java diff py swift
├─ Conditional → Statement  if else switch / Given                   c java feature py
├─ Repeat → Statement       for while do                             c java py
├─ Label → Statement        case default empty: / ::continue::       c lua
├─ Operator (own)           sizeof instanceof / and in / final ??    c java lua py swift
├─ Keyword → Statement      local function if for return             lua
└─ Exception → Statement    throw try catch finally / except raise   java py
PreProc                     #pragma #line #error @Override           c java
├─ Include → PreProc        #include import package                  c java py swift
├─ Define → PreProc         Scenario: / @ / let var func class       feature py swift
├─ Macro → PreProc          #define #undef / Feature:                c feature
└─ PreCondit → PreProc      #if #ifdef #elif #else #endif            c swift
Type                        int char size_t boolean / Then           c java feature diff swift
├─ StorageClass → Type      static extern const public final         c java
├─ Structure → Type         struct union enum / class names KeyError c py
└─ Typedef → Type           this super                               java
Special                     print pcall {} / , = : / f-string {} \t  lua log java py swift
├─ SpecialChar → Special    \n \t %s                                 c java lua
├─ Tag → Special            @smoke @slow                             feature
├─ Delimiter (own)          ( ) , . | (table cells) / : -> [ ]       lua feature swift
├─ SpecialComment → Special first sentence of javadoc / language:    java feature
└─ Debug → Special          DEBUG                                    log
Underlined                  https://... 192.0.2.10                   log
Error                       089 )) ]}                                c
Todo                        TODO FIXME XXX                           c java py swift
Added                       + lines                                  diff
Changed                     ! lines                                  diff
Removed                     - lines                                  diff
Ignore → Normal             (not covered: it hides text)
```

`@variable` is not a standard group but is colored directly in Neovim's default colorscheme, so it needs its own definition. Every plain variable in `sample.lua` uses it.

## Notes on the samples

- Tree-sitter Lua sends `if` `for` `and` to `@keyword.*`, which ends at `Keyword`, not at `Conditional` or `Repeat`. Table braces `{}` are `@constructor` and builtins such as `print` are `@function.builtin`, both linked to `Special`.
- Lua numbers are all `Number`; Tree-sitter Lua does not tell floats apart. Legacy Python does not either.
- Legacy Python links builtins such as `str` and `print` to `Function`, and class names and builtin exceptions to `Structure`. Its escapes and f-string braces go to `Special` directly, not through `SpecialChar`. `sample.py` is written like ordinary code, so `Function` appears far more often than other groups there, mostly from type hints such as `str` and `int`.
- A Python decorator is split in two: `@` is `Define` and the name after it is `Function`.
- Legacy Python links `None`, `True` and `False` to `Function` with `hi! def link`, which replaces any link a colorscheme sets beforehand. A colorscheme cannot recolor them; `g:python_no_builtin_highlight` turns them off together with all builtins.
- Legacy Swift links operators such as `=` `+` `==` to `Function`, and declaration keywords `let` `var` `func` `class` to `Define`. Control keywords such as `if` `for` `return` are `Statement`, not `Conditional` or `Repeat`. Type names in declarations are `Function`, and the module name after `import` is `Title`, a UI group.
- In `sample.swift`, the `return` right after `case .plain:` shows as `Type`. Legacy Swift reads a colon at the end of a line as the start of a type annotation.
- In legacy C, `typedef` is `Structure` (`cTypedef` links there), so `Typedef` comes only from Java.
- The last three lines of `sample.c` are broken on purpose to show `Error`. They sit at the end because an unclosed bracket marks everything below it as an error.
- `sample.log` ends with a modeline because Neovim does not detect the `log` filetype from the `.log` extension.
- C and Java use legacy syntax only because Neovim does not bundle their Tree-sitter parsers. Installing those parsers switches them to Tree-sitter captures, and the groups listed above for them are likely to change.

## How often each group appears in real code

Measured on 2026-10-12 with Neovim 0.12.5 (`--clean`), to see which groups a main color would land on. Unlike the samples above, these files were not written to balance the groups.

- Shell: 16 scripts in this repository (`lib/`, `scripts/`, `install.sh`, `uninstall.sh`), legacy syntax
- Lua: the Neovim config in this repository and a few files from Neovim's runtime, Tree-sitter
- Python: four files from the standard library, legacy syntax

"Tokens" counts runs of the same group; "chars" counts the characters they cover, as a rough measure of screen area. Both are shares of highlighted text only.

| Group | Shell tokens / chars | Lua tokens / chars | Python tokens / chars |
|---|---|---|---|
| Statement family ¹ | 19% / 8% | 12% / 10% | 29% / 9% |
| Function | 1% / 1% | 5% / 7% | 19% / 10% |
| String | 8% / 20% | 8% / 13% | 15% / 45% |
| Comment | 2% / 45% | 2% / 37% | 6% / 27% |
| PreProc | 21% / 13% | — | — |
| Special | 4% / 4% | 6% / 3% | 3% / 1% |
| Number | 4% / 0% | 2% / 0% | 4% / 1% |
| fg groups ² | 42% / 9% | 61% / 29% | 20% / 6% |

¹ Statement, Conditional, Repeat, Keyword and Exception combined.
² Operator, Delimiter, Identifier and `@variable`.

Takeaways:

- The Statement family ranks high in every language but covers little area, since its tokens are short words like `if` and `return`. That makes it a good place for the main color.
- Function is the next candidate, especially for Python.
- String and Comment cover the most area. A main color there would fill the screen.
- Legacy shell syntax links variable expansions (`$foo`, `${foo}`) to `PreProc`, so `PreProc` is the most frequent colored group in shell scripts.
