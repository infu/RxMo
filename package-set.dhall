let upstream = https://github.com/dfinity/vessel-package-set/releases/download/mo-0.6.20-20220131/package-set.dhall
let Package =
    { name : Text, version : Text, repo : Text, dependencies : List Text }

let additions = [
  { name = "hash"
  , repo = "https://github.com/aviate-labs/hash.mo"
  , version = "v0.1.0"
  , dependencies = [ "base" ]
  },
]

in  upstream # additions
