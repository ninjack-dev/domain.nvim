# domain.nvim
A (WIP) dead-simple Neovim plugin to operate on line "domains". It is effectively a while-loop but for use with line ranges.
## Usage
Visually select a block, then run `:Domain` with a macro which would work with `:norm[al]`. 

As a simple example, to delete every other line within a block, simply run
```
:'<,'>Domain ddj
```

There are three things to consider when operating on a domain:
- **The Cursor Delta (Sometimes) Defines the End of the Loop** -- The cursor delta--i.e. how many lines the cursor moves during a loop--is tracked on the first loop; if the cursor travels fewer lines than it did on the first loop, it exits, because it has likely reached the end of the buffer.
- **The Domain Cannot Be Empty** -- If the domain does not consist of at least one line, then it will exit with an error. If it **is** one line, you should just consider running your macro as-is.
- **You Can Resize the Domain** - Operations which remove lines from the buffer cause the domain to shrink; without this behavior, lines which were outside of the original line range would end up getting removed, which is generally unintended. This also applies to line additions; adding lines would otherwise cause the end of the selected domain to shift outside. This behavior is known as "domain expansion", and is trivial to work with. However, if at any point the macro adds more lines than it traverses (e.g. `PPj`, where register `@0` contains a string with a newline), a protective measure will trigger, and it will exit with an error.

## Design
When defining a macro which contains line movement, a minor amount of mental math is sometimes needed to determine how many times to run said macro. Generally, this boils down to dividing the size of the block to work on and the line motions used and using the quotient as the count, e.g. running a macro over 11 lines while using `jj` = 11/2 = 5 times needed to run the macro.

domain.nvim simply removes this mental math by allowing a macro--or any operation which can be supplied to `:norm[al]`--to be applied while inside a line range, usually supplied by a visual block; visual blocks are trivial to manipulate, and involve almost no mental effort. The `Domain` function simply watches for the cursor to leave the line range, at which point it exits. 

## Example Usecases
### Building a String with Every Other Line
Take the following Docker Compose file, which requires many secrets which have already been defined, but not added to the secrets list:
```yaml
 1  services:
 2    some-secretive-service:
 3      image: ssl-generation-service:latest
 4      secrets:
 5  secrets:
 6    certbot-cloudflare-config.ini:
 7      file: "secrets/certbot-cloudflare-config.ini"
 8    aws_ssl_access_key_id:
 9      file: "secrets/aws_ssl_access_key_id"
10    aws_ssl_secret_access_key: 
11      file: "secrets/aws_ssl_secret_access_key"
12    aws_email_access_key_id:
13      file: "secrets/aws_email_access_key_id"
14    aws_email_secret_access_key: 
15      file: "secrets/aws_email_secret_access_key"
```
Grabbing the secret names for the purpose of adding them to the `secrets` list for the service is fairly doable in macro form:
```
:let @m = '_yt::let @a .= "- ".@0."\n"^Mjj'
```
or "let the register `m` contain the command 'go to the first non-whitespace character on the line, yank up to the first semi-colon, use `let` to append the characters `- `, the yank register, and a newline to register `a`, and move down two lines" (we must manually append with `let @a .=`, as the register starts out in character mode otherwise). 

Starting on line 6, it can be applied 5 times (for each line containing a secret name) with `5@m`, after which register `a` will contain 
```
- certbot-cloudflare-config.ini
- aws_ssl_access_key_id
- aws_ssl_secret_access_key
- aws_email_access_key_id
- aws_email_secret_access_key
```
Manually counting the number of secrets or visually selecting/reading the number of selected lines/dividing by two is slightly too tedious, and contributes to operational fatigue over the course of a longer operation. Simply visually select all text under `secrets` (the block from 6 to 15) and run
```
:'<,'>Domain @m
```
This use-case was the primary inspiration for this plugin.
## To-Do List for Release
- [ ] Add support for "backwards" macros (macros which start at the bottom of the intended domain)
- [x] Allow variable macro movements by expanding the beginning and end of the buffer with blank lines to preserve the original domain bounds logic (now known as domain expansion (I've never seen JJK))
- Add options:
    - [ ] Always begin from the first row of the domain (default), or to begin from the last row if the visual selection ended on that.
    - [ ] The `:help` page for `:norm[al]` discusses the usage of `:exe` as an alternative to allow for; it may be nice to pass this in as an option. 
