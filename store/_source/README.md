# Store assets source

Headless Chrome renders `template.html` (carservice.mn "Midnight + Alizarin" palette, Geist font, brand SVGs from `carcare.mn/public/brand`).

```sh
# render.sh <out.png> <css-width> <css-height> <scale> "<query>"
./render.sh ../appstore_header.png        1920 823  2 "kind=hero&app=customer"
./render.sh ../appstore_search_result.png 1920 1280 2 "kind=hero&app=customer"
./render.sh ../play_feature_graphic.png   1024 500  1 "kind=feature&app=customer"
./render.sh ../feature_graphic.png        1024 500  1 "kind=showcase&app=customer"   # 2026-11 app canvas (hero card, quick actions)
./render.sh ../logo/logo_light.png        1200 300  2 "kind=logo&app=customer&tone=light"
./render.sh ../logo/logo_dark.png         1200 300  2 "kind=logo&app=customer&tone=dark"
./render.sh ../logo/mark.png              512  512  2 "kind=mark"
```
`app=customer` | `app=business`. Logo PNGs were trimmed to content + 12% padding afterwards. Icons (`appstore_icon_1024.png`, `play_icon_512.png`) are the launcher icon source flattened on white (no alpha).

## Play Store screenshots

`screens.html` draws demo (not real) app screens in the 2026-11 light canvas inside a device frame, with a marketing headline. Six screens: home, search, book, track, diag, garage (`s=1..6`).

```sh
i=0; for n in home search book track diag garage; do i=$((i+1))
  PAGE=screens.html ./render.sh ../screenshots/phone/0${i}_$n.png   540 960  2 "device=phone&s=$i"    # 1080x1920
  PAGE=screens.html ./render.sh ../screenshots/tablet7/0${i}_$n.png 720 1280 2 "device=tablet&s=$i"   # 1440x2560
  PAGE=screens.html ./render.sh ../screenshots/tablet10/0${i}_$n.png 900 1600 2 "device=tablet10&s=$i" # 1800x3200, NavigationRail (>=720dp)
  PAGE=screens.html ./render.sh ../screenshots/iphone/0${i}_$n.png  603 1311 2 "device=iphone&s=$i"   # 1206x2622 App Store iPhone 6.3"
  PAGE=screens.html ./render.sh ../screenshots/ipad13/0${i}_$n.png  1032 1376 2 "device=ipad&s=$i"    # 2064x2752 App Store iPad 13"
done
```
Run sequentially (parallel runs share the Chrome profile). On macOS pass `BRAND=file:///…/carservice.mn/public/brand`; `render.sh` finds Chrome on its own.
