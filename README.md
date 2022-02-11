I-Blocklist-Builder
===

A simple, yet effective script to combine available blocklists from the [I-Blocklist][0] API.


## Usage

The `I-Blocklist-Builder.sh` script supports creating a combined blocklist in multiple ways.
By default, it combines all freely available blocklists listed on the I-Blocklist API.
If you have an I-Blocklist subscription, you can provide your username and PIN via the `-u` and `-p` options, respectively.
When subscription authentication credentials are supplied, the script will also include all blocklists which require s subscription in addition to the free blocklists.
The script also supports different levels of output verbosity specified, in increasing order, by `-q`, `-e`, `-w`, and `-x`.


### Command Line Arguments

| Option |    Name    | Description |
|:------:|:-----------|:------------|
|  `-u`  | `Username` | Required for including subscription lists |
|  `-p`  | `API PIN`  | Required for including subscription lists |
|  `-q`  | `Quiet`    | Display nothing, no runtime information |
|  `-e`  | `Error`    | Display only unrecoverable runtime errors |
|  `-w`  | `Warns`    | Display runtime warnings allong with errors |
|  `-x`  | `Extra`    | Display extra, diagnostic runtime information |


### Examples

**Blocklist to STDOUT**:
```
$ ./I-Blocklist-Builder.sh -e
```

**Blocklist to directory**, with authentication:
```
$ ./I-Blocklist-Builder.sh -u <USERNAME> -p <PIN> -q ~/.config/transmission/blocklists 
```

**Blocklist to multiple directories**, while displaying extra info:
```
$ ./I-Blocklist-Builder.sh -x ~/.config/deluge/plugins ~/.config/transmission/blocklists 
```

[0]: https://www.iblocklist.com/
