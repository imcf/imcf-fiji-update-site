# Fiji update site 'UniBas-IMCF'

Organize and deploy the contents of the [IMCF's update site for Fiji][1].

The goal is to populate the contents of our update site entirely through this
repository, following the [Automatic Update Site Uploads][2] guide on the
ImageJ wiki.

## `AutoRun` Scripts

Scripts provided in the Fiji's `AutoRun` directory will be automatically
launched when the application has started up. Corresponding files are added to
the update site from the `extra/` subdirectory within this repository:

```text
Fiji.app
└── plugins
    └── Scripts
        └── Plugins
            └── AutoRun
                └── <any .js or .ijm file>
```

[1]: https://imagej.net/list-of-update-sites/
[2]: https://imagej.net/update-sites/automatic-uploads
