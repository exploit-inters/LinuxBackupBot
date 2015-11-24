# Example server configuration

Full configuration consists of following structure:
```
example/
└── _meta
    ├── config
    ├── excludes
    ├── last.log
    ├── passwd
    └── prev.log
```

All backups will be created within `example` folder.  
`_meta` folder contains all configuration & logs. You're required to create `config`, `excludes` and `passwd` files only. Content of every file is self-explanatory.
