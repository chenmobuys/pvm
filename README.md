# PVM

## Description

PHP version manager for windows.

Use [PS2EXE](https://github.com/MScholtes/PS2EXE) convert ps script to exe.

## Download

[Releases](https://github.com/chenmobuys/pvm/releases)

## Install 

```
cd \path\to\pvm && .\pvm init
```


## Usage

* `pvm help`                 Show help.
* `pvm init`                 Initialize when using for the first time.
* `pvm list`                 List exists versions.
* `pvm installed`            List installed versions.
* `pvm use <version>`        Use specify version.
* `pvm install <version>`    Install specify version.
* `pvm uninstall <version>`  Uninstall specify version.

## Example

### Install specify version

Install 7 latest version.
```
pvm install 7
```

Install 7 latest nts version.
```
pvm install 7-nts
```

Install 7.0 latest version.
```
pvm install 7.0
```

Install 7.0.0 version.
```
pvm install 7.0.0
```
