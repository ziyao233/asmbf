# asmbf

A brainfuck interpreter written in pure x86-64 AT&T-style assembly.

Super small and easy to understand

# Size

Right 300 lines of code, executable less than 12kB with a lot of padding.

## Assembling

I use C preprocessor to handle some macros. ``gcc`` and ``clang`` both
work for this.

You should ***NOT*** link the standard C library, since I write ``_start``
as entry point on my own.

```
$ gcc asmbf.S -o asmbf -nostdlib -no-pie
$ clang asmbf.S -o asmbf -nostdlib -no-pie
```

## Usage

``
$ asmbf SCRIPT_PATH
``

## Compatibility

Written in assembly, it is only available on x86-64 Linux platforms.

## Error handling

Unfortunately, this interpreter will simply crash if you try to run a
problemly brainfuck script.

## Blog

[Check here](https://blog.ziyao233.xyz/asmbf.html)
