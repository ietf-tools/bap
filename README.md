# bap ABNF Parser

## Building
```
./configure
./make
```

## Online help
```
bap -h
```

## Example usage
Use the `aex` Perl script to extract ABNF from a RFC or Internet Draft and then pipe this into `bap`:
```
aex xxx.txt | bap -S rule
```
where `rule` is the root rule of the grammar.
