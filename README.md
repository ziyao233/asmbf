# asmbf

Brainfuck interpreters written in pure assembly.

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

## rv64gc port

asmbf has been ported to rv64gc platforms, see asmbf-rv64.S

Compile it with

```
$ gcc asmbf.S -o asmbf -nostdlib -no-pie -mno-relax asmbf-rv64.S -o asmbf-rv64
$ clang asmbf.S -o asmbf -nostdlib -no-pie -mno-relax asmbf-rv64.S -o asmbf-rv64
```

You could also try it with user mode QEMU, with command like

```
$ qemu-riscv64 asmbf-rv64 HelloWorld.bf
```

## Blog

[Check here](https://blog.ziyao233.xyz/asmbf.html)
