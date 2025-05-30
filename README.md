# domain.nvim
A (WIP) dead-simple Neovim plugin to operate on line "domains". It adds one command--`Domain`--which operates on a line range with a movement-based macro.

When defining a macro which contains line movement, a minor amount of mental math is sometimes needed to determine how many times to run said macro. Generally, this boils down to dividing the size of the block to work on and the line motions used and using the quotient as the count, e.g. running a macro over 11 lines while using `jj` = 11/2 = 5 times needed to run the macro.

domain.nvim simply removes this mental math by allowing a macro--or any operation which can be supplied to `:norm[al]`--to be applied while inside a line range, usually supplied by a visual block which is trivial to manipulate. It watches for the cursor to leave the line range, at which point it simply exits. 

As a simple example, to delete every other line within a block, simply run
```
:'<,'>Domain ddj
```

There are some minor considerations/protections to put in place to ensure that the macro is--or isn't--properly applied.
- The typical line delta--i.e. how many lines the macro moves the cursor in a single invocation--is tracked on the initial loop; if subsequent line deltas decrease, it exits, as it has likely reached the end of the buffer.
- To protect against infinite loops, if the initial line delta is not at least 1 (and if it is 1, you may want to consider using `:norm`), then it will exit with an error.
- Destructive operations which remove lines from the buffer cause the domain itself to shrink; otherwise, lines which were originally outside of the domain would get removed. This also applies to line additions, as adding lines will cause the end of the selected domain to shift outside.
- Expanding on the above consideration: if at any point the macro adds more lines than it traverses (e.g. `PPj`, where register `@0` contains a string with a newline), a protective measure will trigger, and it will exit with an error.

Some caveats:
- Due to the nature of the checks, macros which are able to vary the cursor delta between invocations are currently unsupported.
- If a macro performs no edits, e.g. it only moves the cursor, then the undo tree will still show a change. This is due to how the change would normally be applied; it copies the line range into a temporary buffer/window to apply the command with `normal`, then copies the edited block back, constituting a "change" in the eyes of the undo tree. If it did not, then at any point where the command fails, the changes would still be applied, which is likely undesirable.

## Example Usecase
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
:let @m = _yt::let @a .= "- ".@0."\n"^mjj
```
or "let the register `m` contain the command 'go to the first non-whitespace character on the line, yank up to the first semi-colon, use `let` to append the characters `- `, the yank register, and a newline to register `a`, and move down two lines". Starting on line 6, it can be applied 5 times (for each line containing a secret name) with `5@m`, after which register `a` will contain 
```
- certbot-cloudflare-config.ini
- aws_ssl_access_key_id
- aws_ssl_secret_access_key
- aws_email_access_key_id
- aws_email_secret_access_key
```
Manually counting the number of secrets, or visually selecting/reading the number of selected lines/dividing by two, is slightly too tedious, and contributes to search fatigue over the course of a longer operation. Simply visually select the block from 6 to 15 and run
```
:'<,'>Domain @m
```
This use-case was the primary inspiration for this plugin.
