# Fonts

The handwriting of the Papercraft theme (`Themes/Papercraft.lua`), registered with LibSharedMedia as
"Caveat" and "Patrick Hand". If another addon registered a font under the same name first, LibSharedMedia keeps that one.

| File | Font | Copyright | License |
|---|---|---|---|
| `Caveat-Bold.ttf` | [Caveat](https://github.com/googlefonts/caveat), Bold | Copyright 2014 The Caveat Project Authors | SIL Open Font License 1.1, `Caveat-OFL.txt` |
| `PatrickHand-Regular.ttf` | [Patrick Hand](https://fonts.google.com/specimen/Patrick+Hand) | Copyright (c) 2010-2012 Patrick Wagesreiter | SIL Open Font License 1.1, `PatrickHand-OFL.txt` |

Both come from [google/fonts](https://github.com/google/fonts) (`ofl/caveat`, `ofl/patrickhand`). Caveat is published
as a variable font; `Caveat-Bold.ttf` is its weight 700 instance, made with
`python -m fontTools.varLib.instancer "Caveat[wght].ttf" wght=700 --static --update-name-table`, as the game needs a
static font. Neither font declares a Reserved Font Name.
