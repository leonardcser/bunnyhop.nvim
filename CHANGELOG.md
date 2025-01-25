# Changelog

## [0.5.1](https://github.com/PLAZMAMA/bunnyhop.nvim/compare/v0.5.0...v0.5.1) (2025-01-25)


### Bug Fixes

* fix buffer is invalid when going to telescope result ([3f794d7](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/3f794d7bcc4220cc4cab2033756038e6fbc2f787))
* fix copilot expired token error ([2dd8556](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/2dd8556a4b8658f67b2ee9f422d05d1a063a3072))
* handle nil file_content ([ba9bb88](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/ba9bb880ba8260713deb0345fa55b06ee9b8f024))

## [0.5.0](https://github.com/PLAZMAMA/bunnyhop.nvim/compare/v0.4.0...v0.5.0) (2025-01-23)


### Features

* add cache functionaly to copilot verification function ([400fb95](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/400fb95a9eac3cc7d69773769dc9850ae1c90ca9))
* remove jumpts and add files to context ([5464f75](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/5464f753b1ed6655596b82b532b383a9a1ec8b84))


### Bug Fixes

* change environment variable fetching of get_github_token ([4419966](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/4419966a48589f06695c84637cd9c78293d9b8c7))
* correct args in notify call and move notify into schedule ([ea14358](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/ea143584627348a736075e45ff143c7ea86571cd))
* fix callback being called twice in authorize_token ([d14c6fd](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/d14c6fd3cdc4d14b0d83dc1d59c1467c1d1f1ad6))
* fix linter errors ([8494e9a](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/8494e9aa02896a3f8b16190783461c57055993d2))
* remove api_key assignment ([569a720](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/569a720035f50879c25126b7e1508f5c91a2c730))
* remove persistant "Authorizing GitHub Copilot token" notification ([fff3f8a](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/fff3f8ad540f11f77181808f1499f33f54fc13e9))
* remove unnecessary github token fetch in complete ([cfb9ef4](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/cfb9ef4ff14f995c1a714963ca1c328a9a184ee6))
* stale/persistent window during rapid prediction ([da851e0](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/da851e042aeac1a76656c3becd064a794ac113a2))

## [0.4.0](https://github.com/PLAZMAMA/bunnyhop.nvim/compare/v0.3.1...v0.4.0) (2025-01-18)


### Features

* add copilot adapter ([8f56a1a](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/8f56a1ad794a0b59dad77c676a3f2574667514a1))
* add process_api_key to copilot adapter ([2da9e12](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/2da9e1266e2f75fd853ea96c2d53bb57202e72a9))
* add rest of currently available copilot models ([256c9d4](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/256c9d463069702feaebfbf59376decbcdf128c8))


### Bug Fixes

* add early return if api_key was successfully found ([d01dd90](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/d01dd90037af7b1e3357c5c6c57b9a99342b8c63))
* fix linter errors and add TODO ([42c2c77](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/42c2c77ed871f72a3ee96f4fb5e931e2a390e578))
* fix linter warnings ([694a395](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/694a395151080e537e5ecfd386d22587abc9319d))

## [0.3.1](https://github.com/PLAZMAMA/bunnyhop.nvim/compare/v0.3.0...v0.3.1) (2025-01-16)


### Bug Fixes

* fix adapters require statement ([5d4d646](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/5d4d646358e154405172f2455863ea650b25411a))
* remove spelling check to the CHANGELOG.md file ([fcf7b63](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/fcf7b63a015493154b9987b9c29851437787c323))

## [0.3.0](https://github.com/PLAZMAMA/bunnyhop.nvim/compare/v0.2.0...v0.3.0) (2025-01-15)


### Features

* update default model and prompt ([d7bbb68](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/d7bbb686a82ca60c1bff6cd2bd92318dabd2feed))


### Bug Fixes

* fix "unused variable" linter error ([b64799d](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/b64799db00e55d1dd336ee39fd86f65b2e0a3219))
* fix get_models function ([5cf438a](https://github.com/PLAZMAMA/bunnyhop.nvim/commit/5cf438a6c34ba5c46a5c12f6297346e37be23c8f))
